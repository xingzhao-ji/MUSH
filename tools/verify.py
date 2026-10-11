#!/usr/bin/env python3
"""Run the existing native Godot checks, retaining bounded, ignored receipts.

No third-party Python packages. Never launches against the historical project
or a shipped save profile. Captures are stills; Dummy audio is not listening.
"""
import argparse
import csv
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time
import traceback

ROOT = Path(__file__).resolve().parents[1]
RESERVE = 10 * 1024**3
IGNORED = {".git", ".godot", "reports", "builds", "__pycache__"}


def sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def source_files():
    files = {}
    for folder, dirs, names in os.walk(ROOT, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in IGNORED)
        for name in sorted(names):
            path = Path(folder) / name
            if path.is_symlink():
                raise RuntimeError(f"Unexpected source symlink: {path}")
            if name == ".DS_Store" or name.endswith(".pyc"):
                continue
            files[str(path.relative_to(ROOT))] = {"bytes": path.stat().st_size, "sha256": sha(path)}
    return files


def reserve():
    free = shutil.disk_usage(ROOT).free
    if free < RESERVE:
        raise RuntimeError(f"10 GiB retained disk reserve not met: {free} bytes")
    return free


def assert_idle():
    if sys.platform != "darwin":
        return
    processes = subprocess.check_output(["ps", "-axo", "pid=,comm="], text=True)
    found = [row for row in processes.splitlines() if Path(row.strip().split(maxsplit=1)[-1]).name in {"Godot", "MUSH"}]
    if found:
        raise RuntimeError("Close the running game/editor before native checks: " + repr(found))


def run(command, output, label, timeout):
    reserve()
    began = time.monotonic()
    child = None
    failure = None
    try:
        with (output / (label + ".log")).open("xb") as log:
            child = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.DEVNULL,
                                     stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            print(json.dumps({"phase": label, "pid": child.pid, "deadline_s": timeout}), flush=True)
            while child.poll() is None:
                reserve()
                if time.monotonic() - began > timeout:
                    raise TimeoutError(f"{label} exceeded {timeout}s")
                time.sleep(0.25)
    except BaseException:
        failure = traceback.format_exc()
    finally:
        if child is not None and child.poll() is None:
            os.killpg(child.pid, signal.SIGTERM)
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait(timeout=5)
    log = (output / (label + ".log")).read_text(errors="replace")
    errors = [line for line in log.splitlines() if re.match(r"^(SCRIPT ERROR|ERROR):", line)]
    result = {"command": command, "exit_code": child.returncode if child else None,
              "wall_seconds": time.monotonic() - began, "failure": failure, "errors": errors,
              "audio_driver": "Dummy", "process_reaped": child is not None and child.poll() is not None}
    (output / (label + "-process.json")).write_text(json.dumps(result, indent=2) + "\n")
    if failure or result["exit_code"] != 0 or errors:
        raise RuntimeError(f"{label} failed; see {output / (label + '.log')} and process receipt")
    return result


def inspect(suite, output, duration):
    if suite == "import":
        return {"import_passed": True}
    if suite == "acceptance":
        report = json.loads((output / "acceptance.json").read_text())
        cases = report["tests"]
        checks = [c for case in cases for c in case["assertions"]]
        assert len(cases) == 15 and len(checks) >= 295
        assert all(c["pass"] is True for c in checks)
        assert report["automated_failed_scenarios"] == 0 and report["build_unchanged_during_verification"]
        return {"scenarios": len(cases), "assertions": len(checks), "all_passed": True,
                "manual_acceptance": False}
    if suite == "benchmark":
        report = json.loads((output / "worst-1.json").read_text())
        with (output / "worst-1.csv").open(newline="") as stream:
            rows = list(csv.DictReader(stream))
        assert rows and len(rows) == report["frames"]
        assert all(len(row) == 19 and None not in row for row in rows)
        values = [{k: float(v) for k, v in row.items()} for row in rows]
        assert all(math.isfinite(value) for row in values for value in row.values())
        assert all(row["frame_ms"] > 0 for row in values)
        assert all(b["time_s"] > a["time_s"] for a, b in zip(values, values[1:]))
        assert values[-1]["time_s"] >= duration
        frames = sorted(row["frame_ms"] for row in values)
        percentile = lambda p: frames[math.ceil(p * len(frames)) - 1]
        p95, p99 = percentile(.95), percentile(.99)
        assert abs(p95 - report["frame_p95_ms"]) < .00002
        assert abs(p99 - report["frame_p99_ms"]) < .00002
        assert report["scenario"] == "worst" and report["capture_s"] == duration
        assert report["route_stalls"] == 0
        assert p95 <= report["limit_p95_ms"] and p99 <= report["limit_p99_ms"]
        return {"frames": len(frames), "frame_p95_ms": p95, "frame_p99_ms": p99,
                "route_stalls": 0, "thresholds_passed": True,
                "gpu_timing_available": report["gpu_timing_available"],
                "physical_device_tested": False, "display_presentation_measured": False}
    if suite == "capture":
        report = json.loads((output / "camera.json").read_text())
        assert report["passed"] and len(report["views"]) == 4
        spec = importlib.util.spec_from_file_location("mush_png", ROOT / "tools/check_png.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        decoded = []
        for view in report["views"]:
            assert view["passed"] and Path(view["file"]).name == view["file"]
            item = module.decode(output / view["file"])
            assert item["dimensions"] == [960, 960] and item["all_crcs_checked"]
            assert item["png_sha256"] == view["png_sha256"] and item["rgba_sha256"] == view["rgba_sha256"]
            decoded.append(item)
        return {"full_png_decodes": decoded, "motion_verified": False, "art_approved": False}
    report = json.loads((output / "native/ground-material-sync.json").read_text())
    assert report["passed"] is True
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", default=shutil.which("godot"))
    parser.add_argument("--suite", choices=("import", "acceptance", "benchmark", "capture", "ground"), required=True)
    parser.add_argument("--duration", type=int, default=120)
    args = parser.parse_args()
    if not args.engine or not Path(args.engine).is_file():
        parser.error("Pass --engine PATH to Godot 4.7.2")
    if not 120 <= args.duration <= 600:
        parser.error("Benchmark duration must be 120–600 seconds")
    assert_idle()
    reserve()
    engine = str(Path(args.engine).resolve())
    version = subprocess.check_output([engine, "--version"], text=True, timeout=15).strip()
    if not version.startswith("4.7.2."):
        raise RuntimeError(f"Requalify engine upgrades first; observed {version}")
    stamp = time.strftime("%Y%m%d-%H%M%S") + "-" + str(os.getpid())
    output = ROOT / "reports" / (args.suite + "-" + stamp)
    output.mkdir(parents=True, exist_ok=False)
    before = source_files()
    # New native .uid files are generated during import; import is its own step.
    if args.suite != "import" and not (ROOT / ".godot/global_script_class_cache.cfg").exists():
        raise RuntimeError("Run --suite import first")
    command = [engine, "--path", str(ROOT), "--audio-driver", "Dummy"]
    if sys.platform == "darwin":
        command += ["--rendering-driver", "metal", "--rendering-method", "forward_plus"]
    if args.suite == "import":
        command += ["--headless", "--editor", "--import", "--quit"]
    elif args.suite == "ground":
        command += ["--script", "res://tests/ground_material_sync.gd", "--", "--report-dir=" + str(output / "native")]
    else:
        flag = {"acceptance": "--verify", "benchmark": "--benchmark", "capture": "--capture"}[args.suite]
        command += ["--", flag, "--report-dir", str(output)]
        if args.suite == "benchmark":
            command += ["--scenario", "worst", "--warmup", "5", "--duration", str(args.duration)]
    result = {"suite": args.suite, "engine": version, "engine_sha256": sha(Path(engine)),
              "passed": False, "physical_device_tested": False, "live_audio_verified": False}
    try:
        result["process"] = run(command, output, args.suite, 600 if args.suite == "acceptance" else args.duration + 120 if args.suite == "benchmark" else 180)
        result["checks"] = inspect(args.suite, output, args.duration)
        after = source_files()
        changed = [name for name in before if after.get(name) != before[name]]
        added = sorted(set(after) - set(before))
        result["source_changes"] = changed
        result["generated_source_files"] = added
        assert not changed, changed
        assert not added or args.suite == "import" and all(name.endswith(".uid") for name in added), added
        result["passed"] = True
    except BaseException:
        result["failure"] = traceback.format_exc()
    result["source_files_before"] = before
    result["available_bytes_after"] = shutil.disk_usage(ROOT).free
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"passed": result["passed"], "suite": args.suite, "output": str(output),
                      "checks": result.get("checks"), "failure": result.get("failure")}), flush=True)
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    sys.dont_write_bytecode = True
    raise SystemExit(main())
