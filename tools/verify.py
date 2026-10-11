#!/usr/bin/env python3
"""Run the existing native Godot checks, retaining bounded, ignored receipts.

No third-party Python packages. Never launches against the historical project
or a shipped save profile. Captures are stills; Dummy audio is not listening.
"""
import argparse
import csv
import gzip
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

if sys.flags.optimize:
    raise RuntimeError("Verification requires Python assertions; do not use -O or PYTHONOPTIMIZE")

ROOT = Path(__file__).resolve().parents[1]
RESERVE = 10 * 1024**3
IGNORED = {".git", ".godot", "reports", "builds", "__pycache__"}


def sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_report(path):
    if path.exists():
        return json.loads(path.read_text())
    with gzip.open(str(path) + ".gz", "rt") as stream:
        return json.load(stream)


def compact_reports(output):
    """Compress only this run's large JSON outputs, with full byte readback."""
    receipts = []
    for path in sorted(output.rglob("*.json")):
        if path.stat().st_size < 1024**2:
            continue
        raw = path.read_bytes()
        encoded = gzip.compress(raw, compresslevel=6, mtime=0)
        if len(encoded) >= len(raw):
            continue
        target = path.with_suffix(path.suffix + ".gz")
        with target.open("xb") as stream:
            stream.write(encoded)
        assert gzip.decompress(target.read_bytes()) == raw
        assert path.read_bytes() == raw
        receipts.append({"file": str(path.relative_to(output)), "bytes": len(raw),
                         "gzip_bytes": len(encoded), "sha256": hashlib.sha256(raw).hexdigest()})
        path.unlink()
    return receipts


def source_files():
    files = {}
    for folder, dirs, names in os.walk(ROOT, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in IGNORED)
        for directory in dirs:
            if (Path(folder) / directory).is_symlink():
                raise RuntimeError(f"Unexpected source directory symlink: {Path(folder) / directory}")
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


def inspect(suite, output, duration, expected_vsync=1):
    if suite == "import":
        return {"import_passed": True}
    if suite == "acceptance":
        report = read_report(output / "acceptance.json")
        cases = report["tests"]
        checks = [c for case in cases for c in case["assertions"]]
        assert len(cases) == 15 and len(checks) >= 295
        assert all(c["pass"] is True for c in checks)
        assert report["automated_failed_scenarios"] == 0 and report["build_unchanged_during_verification"]
        return {"scenarios": len(cases), "assertions": len(checks), "all_passed": True,
                "manual_acceptance": False}
    if suite == "benchmark":
        report = read_report(output / "worst-1.json")
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
        assert report["traversal_measurement_valid"] is True and report["route_loops_completed"] > 0
        assert report["resolution_valid"] is True and report["render_resolution"] == [1920, 1080]
        assert report["vsync"] == expected_vsync
        assert report["limit_p95_ms"] == 16.7 and report["limit_p99_ms"] == 33.3
        assert p95 <= 16.7 and p99 <= 33.3
        return {"frames": len(frames), "frame_p95_ms": p95, "frame_p99_ms": p99,
                "route_stalls": 0, "thresholds_passed": True,
                "route_loops_completed": report["route_loops_completed"],
                "render_resolution": report["render_resolution"],
                "vsync": report["vsync"],
                "gpu_timing_available": report["gpu_timing_available"],
                "physical_device_tested": False, "display_presentation_measured": False}
    if suite in ("paving", "paving-front"):
        report = read_report(output / "native/paving-surface.json")
        front = suite == "paving-front"
        fixture = ROOT / "tests" / ("paving_front_surface.gd" if front else "paving_surface.gd")
        assert report["selected_batch"] == (1 if front else 0)
        assert report["triplanar"] is front
        assert report["fixture_sha256"] == sha(fixture)
        assert report["passed"] is True and report["failed"] == 0 and report["assertions"] > 0
        assert all(row["passed"] for row in report["checks"])
        for key in ("geometry_unchanged", "collision_unchanged", "material_rollback_exact", "source_material_unchanged"):
            assert report[key] is True, key
        labels = ["close-day", "close-night", "wide-day", "close-rain"]
        assert [pair["label"] for pair in report["pairs"]] == labels
        assert all(pair["passed"] and pair["context_held"] for pair in report["pairs"])
        assert [view["label"] for view in report["views"]] == [label + "-" + suffix for label in labels for suffix in ("before", "after")]
        spec = importlib.util.spec_from_file_location("mush_png", ROOT / "tools/check_png.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        decoded = []
        for view in report["views"]:
            assert view["passed"] and view["file"] == view["label"] + ".png"
            item = module.decode(output / "native" / view["file"])
            assert item["dimensions"] == [960, 960] and item["all_crcs_checked"]
            assert item["png_sha256"] == view["png_sha256"] and item["rgba_sha256"] == view["rgba_sha256"]
            decoded.append(item)
        return {"assertions": report["assertions"], "full_png_decodes": decoded,
                "motion_verified": False, "art_approved": False, "performance_measured": False}
    if suite == "outer-tree":
        report = read_report(output / "native/contacts.json")
        assert report["schema"] == "mush-outer-tree-contact/1"
        assert report["passed"] and report["failed"] == 0
        assert report["checks"] and all(row["passed"] for row in report["checks"])
        camera = report["camera_diagnostic"]
        assert camera["diagnostic_integrity"] and camera["original_bodies_restored"]
        assert camera["rows"] and camera["blocked_head_and_body_frames"] == 0
        assert camera["overlapping_lens_frames"] == 0
        contacts = report["contacts"]
        assert contacts["passed"] and len(contacts["cases"]) == 4
        assert all(row["passed"] for row in contacts["checks"])
        assert sum(case[phase]["ticks"] for case in contacts["cases"]
                   for phase in ["approach", "slide", "retreat"]) == 684
        outer = report["outer_contacts"]
        assert outer["passed"] and all(row["passed"] for row in outer["checks"])
        assert all(outer[key] for key in ("endpoint_restored", "controller_settings_exact",
                                         "collision_bindings_exact", "native_cylinder_geometry_exact"))
        assert sum(outer["case"][phase]["ticks"] for phase in ["approach", "slide", "retreat"]) == 171
        assert camera["faded_or_behind_frames"] == 0
        return {"checks": len(report["checks"]), "contact_checks": len(contacts["checks"]),
                "camera_frames": len(camera["rows"]), "blocked_bone_frames": 0,
                "camera_overlaps": 0, "movement_ticks": 855, "outer_contact_checks": len(outer["checks"]),
                "pixel_visibility_verified": False, "motion_acceptance": False}
    if suite == "forest-layers":
        report = read_report(output / "native/forest-layers.json")
        assert report["passed"] and all(row["passed"] for row in report["checks"])
        assert len(report["camera"]) == 36 and all(row["passed"] for row in report["camera"])
        contacts = report["clearance"]["contacts"]
        assert contacts["passed"] and len(contacts["cases"]) == 4
        assert report["clearance"]["root_queries"] == 30 and report["clearance"]["leaf_penetrations"] == 0
        assert report["inventories"]["trial"]["instances"] == 450 and report["inventories"]["trial"]["draw_nodes"] == 55
        spec = importlib.util.spec_from_file_location("mush_png", ROOT / "tools/check_png.py")
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        assert {v["file"] for v in report["views"]} == {label + "-" + suffix + ".png" for label in ("home-day", "side-day", "reverse-day", "home-night", "home-rain") for suffix in ("before", "after")}
        decoded = []
        for view in report["views"]:
            item = module.decode(output / "native" / view["file"])
            assert view["passed"] and item["dimensions"] == [1280, 720] and item["png_sha256"] == view["sha256"]
            decoded.append(item)
        return {"assertions": len(report["checks"]), "full_png_decodes": decoded,
                "camera_poses": 36, "trunk_contact_cases": 4, "contact_assertions": len(contacts["checks"]),
                "motion_verified": False, "art_approved": False, "performance_measured": False}
    if suite == "forest-build":
        report = read_report(output / "native/backdrop-build.json")
        assert report["passed"] and report["seam_vertices"] == 202
        assert report["water_prefix_channels"] == [True] * 13 and len(report["files"]) == 3
        for row in report["files"]:
            assert row["pinned_native_exact"] and row["geometry"]["passed"]
            assert row["sha256"] == sha(output / "native" / row["file"])
        return {"native_build_roundtrip_and_water_prefix": True, "meshes": 3}
    if suite == "forest":
        report = read_report(output / "native/forest.json")
        assert report["passed"] and len(report["checks"]) == 19 and all(c["passed"] for c in report["checks"])
        assert len(report["camera"]) == 24 and all(c["passed"] and c["sphere_hits"] == 0 and c["sphere_radius"] >= .1399 for c in report["camera"])
        assert report["native"]["seams"] == 202 and report["native"]["missing"] == 0
        spec = importlib.util.spec_from_file_location("mush_png", ROOT / "tools/check_png.py")
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        assert {v["file"] for v in report["views"]} == {label + "-" + suffix + ".png" for label in ("home-day", "side-day", "reverse-day", "home-night", "home-rain") for suffix in ("before", "after")}
        decoded = []
        for view in report["views"]:
            item = module.decode(output / "native" / view["file"])
            assert view["passed"] and item["dimensions"] == [1280, 720] and item["png_sha256"] == view["sha256"]
            decoded.append(item)
        return {"assertions": len(report["checks"]), "full_png_decodes": decoded,
                "camera_poses": 24, "motion_verified": False, "performance_measured": False}
    if suite == "flower-build":
        report = read_report(output / "native/flower.json")
        assert report["passed"] and report["triangles"] == 94 and report["root_corners"] == 6
        assert report["sha256"] == sha(output / "native/flower.res") and report["pinned_native_exact"]
        assert report["channels"] == read_report(ROOT / "baked/ground-flower-proof.json")["channels"]
        return {"native_build_and_pinned_roundtrip": True, "artifact_bytes": report["bytes"]}
    if suite == "flower":
        report = read_report(output / "native/flower-capture.json")
        assert report["passed"] and len(report["checks"]) == 23 and all(c["passed"] for c in report["checks"])
        assert report["candidate_wind_admission_verified"] and report["candidate_sha256"] == sha(ROOT / "baked/ground-flower.res")
        assert report["fixture_sha256"] == sha(ROOT / "tests/ground_flower.gd")
        assert len(report["inventory"]) == 119 and sum(r["instances"] for r in report["inventory"]) == 1430
        spec = importlib.util.spec_from_file_location("mush_png", ROOT / "tools/check_png.py")
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        decoded = []
        assert len(report["views"]) == 8
        assert {view["file"] for view in report["views"]} == {label + "-" + suffix + ".png" for label in ("close-day", "wide-day", "close-night", "close-rain") for suffix in ("before", "after")}
        for view in report["views"]:
            item = module.decode(output / "native" / view["file"])
            assert view["passed"] and item["dimensions"] == [960, 960] and item["png_sha256"] == view["sha256"]
            decoded.append(item)
        return {"assertions": len(report["checks"]), "full_png_decodes": decoded, "motion_verified": False, "performance_measured": False}
    if suite == "gap-step":
        report = read_report(output / "native/paving-gap-step.json")
        assert report["schema"] == "mush-paving-gap-step/1"
        assert report["passed"] is True and report["failed"] == 0
        assert len(report["routes"]) == 4 and all(row["passed"] for row in report["routes"])
        assert report["checks"] and all(row["passed"] for row in report["checks"])
        assert report["movement_passed"] and report["owner_exact"] and report["restored"]
        assert report["callbacks_exact"] and not report["fatal"]
        assert report["support_fixtures"]["passed"] and len(report["support_fixtures"]["cases"]) == 10
        trace = output / "native/paving-traversal-ticks.csv"
        assert sha(trace) == report["trace_sha256"]
        with trace.open(newline="") as stream:
            rows = list(csv.DictReader(stream))
        assert len(rows) == report["callbacks"] and 0 < len(rows) <= 9200
        assert all(None not in row and None not in row.values() for row in rows)
        return {"routes": 4, "assertions": report["assertions"], "movement_passed": True,
                "recorded_ticks": len(rows), "native_geometry_held_exact": True,
                "original_roof_contact_gate_waived": False, "manual_controls_verified": False}
    if suite == "traversal":
        report = read_report(output / "native/paving-traversal.json")
        assert report["schema"] == "mush-paving-traversal/1"
        assert len(report["routes"]) == 58
        assert report["passed"] is True and report["failed"] == 0
        assert report["assertions"] > 0 and all(row["passed"] for row in report["checks"])
        assert report["movement_passed"] is True and report["contact_coverage_passed"] is True
        with (output / "native/paving-traversal-ticks.csv").open(newline="") as stream:
            rows = list(csv.DictReader(stream))
        assert 0 < len(rows) <= 9200 and all(None not in row for row in rows)
        return {"routes": len(report["routes"]), "assertions": report["assertions"],
                "movement_passed": True, "contact_coverage_passed": True,
                "coverage": report["coverage"], "recorded_ticks": len(rows),
                "manual_controls_verified": False, "art_approved": False}
    if suite == "shape-build":
        report = read_report(output / "native/paving-shape.json")
        assert report["schema"] == "mush-paving-shape-candidate/2"
        assert report["passed"] is True and report["checks"]
        assert all(row["passed"] for row in report["checks"])
        return {"authoring_checks": len(report["checks"]),
                "resource_sha256": sha(output / "native/paving-shape.res"),
                "traversal_verified": False, "art_approved": False}
    if suite == "shape-capture":
        report = read_report(output / "native/paving-shape-comparison.json")
        assert report["passed"] is True and report["failed"] == 0
        assert report["assertions"] > 0 and all(row["passed"] for row in report["checks"])
        assert len(report["pairs"]) == 4 and all(pair["passed"] for pair in report["pairs"])
        assert len(report["views"]) == 8
        spec = importlib.util.spec_from_file_location("mush_png", ROOT / "tools/check_png.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        decoded = []
        for view in report["views"]:
            assert view["passed"] and Path(view["file"]).name == view["file"]
            item = module.decode(output / "native" / view["file"])
            assert item["dimensions"] == [960, 960] and item["all_crcs_checked"]
            assert item["png_sha256"] == view["png_sha256"] and item["rgba_sha256"] == view["rgba_sha256"]
            decoded.append(item)
        return {"assertions": report["assertions"], "full_png_decodes": decoded,
                "motion_verified": False, "art_approved": False, "traversal_verified": False}
    if suite == "capture":
        report = read_report(output / "camera.json")
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
    filename = "environment-contract.json" if suite == "environment" else "native/ground-material-sync.json"
    report = read_report(output / filename)
    assert report["passed"] is True and report["assertions"] > 0 and report["failed"] == 0
    assert all(row["passed"] for row in report["checks"])
    return {"assertions": report["assertions"], "all_passed": True,
            "native_parameter_comparisons": report.get("native_parameter_comparisons")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", default=shutil.which("godot"))
    parser.add_argument("--suite", choices=("import", "acceptance", "benchmark", "capture", "ground", "environment", "paving", "paving-front", "traversal", "gap-step", "shape-build", "shape-capture", "flower", "flower-build", "forest", "forest-build", "forest-layers", "outer-tree"), required=True)
    parser.add_argument("--candidate", type=Path, help="Isolated shape-capture/traversal resource beneath reports/")
    parser.add_argument("--duration", type=int, default=120)
    parser.add_argument("--uncapped", action="store_true", help="Benchmark-only throughput diagnostic; disable VSync, preserve real elapsed time")
    args = parser.parse_args()
    if not args.engine or not Path(args.engine).is_file():
        parser.error("Pass --engine PATH to Godot 4.7.2")
    if not 120 <= args.duration <= 600:
        parser.error("Benchmark duration must be 120–600 seconds")
    if args.uncapped and args.suite != "benchmark":
        parser.error("--uncapped is a benchmark-only diagnostic")
    if args.candidate:
        args.candidate = args.candidate.resolve()
        if args.suite not in ("shape-capture", "traversal") or not args.candidate.is_file() or not args.candidate.is_relative_to(ROOT / "reports"):
            parser.error("--candidate requires shape-capture/traversal and an existing resource beneath reports/")
    elif args.suite == "shape-capture":
        parser.error("shape-capture requires --candidate")
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
    if args.uncapped:
        command += ["--disable-vsync", "--max-fps", "0"]
    if args.suite == "benchmark":
        # Match the prior qualified benchmark's initial native window extent.
        command += ["--windowed", "--resolution", "1920x1080"]
    if args.suite == "import":
        command += ["--headless", "--editor", "--import", "--quit"]
    elif args.suite == "ground":
        command += ["--script", "res://tests/ground_material_sync.gd", "--", "--report-dir=" + str(output / "native")]
    elif args.suite == "outer-tree":
        command += ["--fixed-fps", "30", "--script", "res://tests/outer_tree_camera.gd",
                    "--", "--benchmark", "--report-dir=" + str(output / "native")]
    elif args.suite == "forest-layers":
        command += ["--script", "res://tests/forest_layers.gd", "--", "--report-dir=" + str(output / "native")]
    elif args.suite in ("forest", "forest-build"):
        fixture = "forest_backdrop_build.gd" if args.suite == "forest-build" else "forest_backdrop.gd"
        if args.suite == "forest-build": command += ["--headless"]
        command += ["--script", "res://tests/" + fixture, "--", "--report-dir=" + str(output / "native")]
    elif args.suite in ("flower", "flower-build"):
        fixture = "flower_build.gd" if args.suite == "flower-build" else "ground_flower.gd"
        if args.suite == "flower-build": command += ["--headless"]
        command += ["--script", "res://tests/" + fixture, "--", "--report-dir=" + str(output / "native")]
    elif args.suite in ("paving", "paving-front"):
        fixture = "paving_front_surface.gd" if args.suite == "paving-front" else "paving_surface.gd"
        command += ["--script", "res://tests/" + fixture, "--", "--report-dir=" + str(output / "native")]
    elif args.suite == "traversal":
        command += ["--script", "res://tests/paving_traversal.gd", "--", "--report-dir=" + str(output / "native")]
        if args.candidate:
            command += ["--candidate=" + str(args.candidate)]
    elif args.suite == "gap-step":
        command += ["--script", "res://tests/paving_gap_step.gd", "--", "--report-dir=" + str(output / "native")]
    elif args.suite == "shape-build":
        command += ["--headless", "--script", "res://tests/paving_shape_build.gd", "--", "--report-dir=" + str(output / "native")]
    elif args.suite == "shape-capture":
        command += ["--script", "res://tests/paving_shape_compare.gd", "--", "--report-dir=" + str(output / "native"), "--candidate=" + str(args.candidate)]
    elif args.suite == "environment":
        command += ["--script", "res://tests/environment_controller_contract.gd", "--", "--report-dir=" + str(output)]
    else:
        flag = {"acceptance": "--verify", "benchmark": "--benchmark", "capture": "--capture"}[args.suite]
        command += ["--", flag, "--report-dir", str(output)]
        if args.suite == "benchmark":
            command += ["--scenario", "worst", "--warmup", "5", "--duration", str(args.duration)]
    result = {"suite": args.suite, "engine": version, "engine_sha256": sha(Path(engine)),
              "timing_mode": "uncapped_throughput_diagnostic" if args.uncapped else "default_vsync",
              "passed": False, "physical_device_tested": False, "live_audio_verified": False}
    try:
        result["process"] = run(command, output, args.suite, 600 if args.suite == "acceptance" else 300 if args.suite == "traversal" else args.duration + 120 if args.suite == "benchmark" else 180)
        result["checks"] = inspect(args.suite, output, args.duration, 0 if args.uncapped else 1)
        result["passed"] = True
    except BaseException:
        result["failure"] = traceback.format_exc()
    # A failed native check must still close the preservation audit.
    try:
        after = source_files()
        changed = [name for name in before if after.get(name) != before[name]]
        added = sorted(set(after) - set(before))
        result["source_changes"] = changed
        result["generated_source_files"] = added
        assert not changed, changed
        assert not added or args.suite == "import" and all(name.endswith(".uid") for name in added), added
    except BaseException:
        result["passed"] = False
        result["preservation_failure"] = traceback.format_exc()
    result["source_files_before"] = before
    try:
        result["compacted_reports"] = compact_reports(output)
    except BaseException:
        result["passed"] = False
        result["compaction_failure"] = traceback.format_exc()
    result["available_bytes_after"] = shutil.disk_usage(ROOT).free
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"passed": result["passed"], "suite": args.suite, "output": str(output),
                      "checks": result.get("checks"), "failure": result.get("failure")}), flush=True)
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    sys.dont_write_bytecode = True
    raise SystemExit(main())
