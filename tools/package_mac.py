#!/usr/bin/env python3
"""Create one experimental Mac app/ZIP from current source, including working changes.

Requires installed Godot 4.7.2 and its Mac template; downloads nothing. Native
shader baking and a 12-check exported smoke use owned, bounded processes. Dummy
audio is not listening evidence. Retained releases and source are never edited.
"""
import sys
sys.dont_write_bytecode = True
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import stat
import subprocess
import time
import traceback

import verify

ROOT = verify.ROOT
PROFILE = Path.home() / "Library/Application Support/MUSH-mac061"
LIMIT = 2 * 1024**3
APP_FILES = {"Contents/Info.plist", "Contents/PkgInfo",
             "Contents/_CodeSignature/CodeResources", "Contents/MacOS/MUSH",
             "Contents/Resources/icon.icns", "Contents/Resources/PrivacyInfo.xcprivacy",
             "Contents/Resources/MUSH.pck"}
ISSUES = re.compile(r"SCRIPT ERROR|ERROR:|WARNING:|Parse Error|leaked|resources? still in use", re.I)


def write(path, value):
    with path.open("x") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")


def metadata(path):
    item = path.lstat()
    assert not path.is_symlink(), path
    return {name: getattr(item, name) for name in
            ("st_dev", "st_ino", "st_mode", "st_size", "st_mtime_ns", "st_ctime_ns", "st_flags")}


def profile_metadata():
    # Read only metadata of prior profiles/apps; never hydrate their payloads.
    result = {}
    for name in ("MUSH-dev", "MUSH-mac055", "MUSH-mac057", "MUSH-mac060"):
        base = PROFILE.parent / name
        result[name] = None if not base.exists() else {
            str(path.relative_to(base)): metadata(path)
            for path in [base, *sorted(base.rglob("*"))]}
    return result


def stage_files(stage):
    return {str(path.relative_to(stage)): {"bytes": path.stat().st_size, "sha256": verify.sha(path)}
            for path in sorted(stage.rglob("*"))
            if path.is_file() and ".godot" not in path.relative_to(stage).parts}


def stream_identity(stream):
    digest = hashlib.sha256()
    count = 0
    for block in iter(lambda: stream.read(1024**2), b""):
        count += len(block)
        digest.update(block)
    return {"bytes": count, "sha256": digest.hexdigest()}


def archive_payload(archive, destination=None):
    import zipfile
    result = {}
    with zipfile.ZipFile(archive) as zipped:
        entries = zipped.infolist()
        assert len(entries) < 64 and len({row.filename for row in entries}) == len(entries)
        assert archive.stat().st_size < 512 * 1024**2
        assert sum(row.file_size for row in entries) < 512 * 1024**2
        for row in entries:
            name = row.filename
            assert str(PurePosixPath(name.rstrip("/"))) == name.rstrip("/")
            assert not name.startswith("/") and ".." not in PurePosixPath(name).parts
            assert not stat.S_ISLNK(row.external_attr >> 16) and not row.flag_bits & 1
            if row.is_dir():
                continue
            if name == "MUSH.command":
                assert row.file_size < 2048
                assert b"MUSH.app/Contents/MacOS/MUSH" in zipped.read(row)
                continue
            assert name.startswith("MUSH.app/") and row.file_size < 512 * 1024**2
            relative = name.removeprefix("MUSH.app/")
            assert relative in APP_FILES
            if destination is not None:
                path = destination / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                with zipped.open(row) as source, path.open("xb") as target:
                    shutil.copyfileobj(source, target, 1024**2)
                path.chmod((row.external_attr >> 16) & 0o777)
            with zipped.open(row) as source:
                result[relative] = stream_identity(source)
    assert set(result) == APP_FILES
    return result


def main():
    if sys.flags.optimize:
        raise RuntimeError("Do not disable assertions with -O or PYTHONOPTIMIZE")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", required=True, type=Path)
    args = parser.parse_args()
    output = ROOT / "builds" / ("mac-" + time.strftime("%Y%m%d-%H%M%S") + "-" + str(os.getpid()))
    output.mkdir(parents=True, exist_ok=False)
    stage, app, archive = output / "stage", output / "MUSH.app", output / "MUSH.zip"
    result = {"schema": "mush-portable-mac-package/1", "passed": False, "selected": False,
              "output": str(output), "user_directory": PROFILE.name,
              "allocation_limit_bytes": LIMIT, "disk_reserve_bytes": verify.RESERVE,
              "live_audio_verified": False, "manual_controls_verified": False,
              "art_approved": False, "performance_accepted": False}
    source_before = prior_before = None
    original_reserve = verify.reserve
    peak = 0

    def reserve():
        nonlocal peak
        free = original_reserve()
        allocated = sum(path.stat().st_blocks * 512 for base in (output, PROFILE)
                        if base.exists() for path in base.rglob("*") if path.is_file())
        peak = max(peak, allocated)
        if allocated > LIMIT:
            raise RuntimeError("Owned candidate allocation exceeded 2 GiB")
        return free

    def run(command, label, timeout):
        receipt = verify.run([str(item) for item in command], output, label, timeout)
        issues = [line for line in (output / (label + ".log")).read_text(errors="replace").splitlines()
                  if ISSUES.search(line)]
        result.setdefault("processes", {})[label] = receipt
        assert not issues, {"phase": label, "issues": issues}
        return receipt

    try:
        assert sys.platform == "darwin", "Mac packaging requires macOS"
        assert not PROFILE.exists() and not PROFILE.is_symlink(), "Candidate mac061 profile must be absent"
        verify.assert_idle()
        assert original_reserve() >= verify.RESERVE + LIMIT, "Retain 10 GiB beyond the 2 GiB candidate ceiling"
        verify.reserve = reserve
        engine = args.engine.expanduser().resolve(strict=True)
        assert engine.is_file()
        version = subprocess.check_output([str(engine), "--version"], text=True, timeout=15).strip()
        assert version.startswith("4.7.2.stable."), version
        template = Path.home() / "Library/Application Support/Godot/export_templates/4.7.2.stable/macos.zip"
        assert template.is_file(), "Install the matching macOS template separately; this helper never downloads"
        inputs = {str(path): {"metadata": metadata(path), "sha256": verify.sha(path)} for path in (engine, template)}
        source_before = verify.source_files()
        prior_before = profile_metadata()
        assert sum(row["bytes"] for row in source_before.values()) < 256 * 1024**2, "Requalify a larger source package"
        project = (ROOT / "project.godot").read_text()
        preset = (ROOT / "export_presets.cfg").read_text()
        assert 'config/use_custom_user_dir=true' in project
        assert 'custom_template/debug=""' in preset and 'shader_baker/enabled=true' in preset
        assert 'reports/*' in preset and 'tests/capture_current.gd' not in preset
        build_version = re.search(r'^config/version="([^"]+)"$', project, re.M).group(1)
        assert 'application/version="' + build_version + '"' in preset
        stage.mkdir()
        for name in source_before:
            reserve()
            destination = stage / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, destination)
        assert stage_files(stage) == source_before
        staged_project, count = re.subn(r'^config/custom_user_dir_name="[^"]*"$',
                                      'config/custom_user_dir_name="' + PROFILE.name + '"', project, flags=re.M)
        assert count == 1
        (stage / "project.godot").write_text(staged_project)
        staged_preset, count = re.subn(r'^application/bundle_identifier="[^"]*"$',
                                     'application/bundle_identifier="local.mush.clearing.mac061"', preset, flags=re.M)
        assert count == 1
        (stage / "export_presets.cfg").write_text(staged_preset)
        expected = stage_files(stage)
        changed = {"project.godot", "export_presets.cfg"}
        assert {key: row for key, row in expected.items() if key not in changed} == {
            key: row for key, row in source_before.items() if key not in changed}
        write(output / "source-before.json", source_before)
        write(output / "prior-profile-metadata-before.json", prior_before)
        run([engine, "--path", stage, "--audio-driver", "Dummy", "--headless", "--editor", "--import", "--quit"], "import", 180)
        run([engine, "--path", stage, "--audio-driver", "Dummy", "--export-debug", "macOS MUSH", archive], "export", 300)
        actual_stage = stage_files(stage)
        assert all(actual_stage.get(name) == row for name, row in expected.items())
        generated = sorted(set(actual_stage) - set(expected))
        assert all(name.endswith(".uid") for name in generated), generated
        assert not app.exists()
        app.mkdir()
        files = archive_payload(archive, app)
        unpacked = {str(path.relative_to(app)): {"bytes": path.stat().st_size, "sha256": verify.sha(path)}
                    for path in app.rglob("*") if path.is_file()}
        assert unpacked == files == archive_payload(archive)
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        assert info["CFBundleExecutable"] == "MUSH"
        assert info["CFBundleIdentifier"] == "local.mush.clearing.mac061"
        assert info["CFBundleVersion"] == info["CFBundleShortVersionString"] == build_version
        assert info["LSMinimumSystemVersionByArchitecture"] == {"arm64": "14.00", "x86_64": "11.00"}
        architectures = subprocess.check_output(["/usr/bin/lipo", "-archs", str(app / "Contents/MacOS/MUSH")], text=True, timeout=30).split()
        assert set(architectures) == {"arm64", "x86_64"}
        subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)], check=True, capture_output=True, timeout=60)
        signature = subprocess.run(["/usr/bin/codesign", "-d", "--verbose=4", str(app)], check=True, capture_output=True, text=True, timeout=30)
        assert "Signature=adhoc" in (signature.stdout + signature.stderr).splitlines()
        ordinary = PROFILE / "profile"
        ordinary_before = None if not ordinary.exists() else {
            str(path.relative_to(ordinary)): {"metadata": metadata(path), "sha256": verify.sha(path)}
            for path in ordinary.rglob("*") if path.is_file()}
        # Native macOS bundles resolve Contents/Resources/MUSH.pck themselves.
        # Official templates disable --main-pack path overrides.
        run([app / "Contents/MacOS/MUSH",
             "--audio-driver", "Dummy", "--rendering-driver", "metal", "--rendering-method", "forward_plus",
             "--", "--smoke", "--exercise-effects", "--report-dir", output / "smoke"], "smoke", 120)
        smoke = json.loads((output / "smoke/smoke.json").read_text())
        assert smoke["passed"] is True and smoke["exported"] is True and smoke["driver"] == "metal"
        assert len(smoke["checks"]) == 12 and all(value is True for value in smoke["checks"].values())
        assert PROFILE.is_dir(), "Expected isolated candidate profile was not created"
        ordinary_after = None if not ordinary.exists() else {
            str(path.relative_to(ordinary)): {"metadata": metadata(path), "sha256": verify.sha(path)}
            for path in ordinary.rglob("*") if path.is_file()}
        assert ordinary_after == ordinary_before, "Smoke changed the ordinary candidate save slot"
        assert archive_payload(archive) == files
        assert all(verify.sha(app / name) == row["sha256"] for name, row in files.items())
        assert all(metadata(Path(name)) == row["metadata"] for name, row in inputs.items())
        result.update({"version": build_version, "engine": version, "inputs": inputs,
                       "source_files": source_before, "files": files, "zip": {"path": str(archive), "sha256": verify.sha(archive), "bytes": archive.stat().st_size},
                       "app": str(app), "architectures": sorted(architectures), "signature_strict_adhoc": True,
                       "smoke": smoke, "ordinary_candidate_save_exact": True,
                       "staged_config_overrides": {name: {"before": source_before[name], "after": expected[name]} for name in sorted(changed)},
                       "generated_stage_uids": generated, "stage_cleanup": False})
        result["passed"] = True
    except BaseException:
        result["failure"] = traceback.format_exc()
    finally:
        verify.reserve = original_reserve
        try:
            source_after = verify.source_files()
            result["source_payloads_exact"] = source_before is not None and source_after == source_before
            result["prior_profiles_and_apps_metadata_exact"] = prior_before is not None and profile_metadata() == prior_before
            verify.assert_idle()
            assert result["source_payloads_exact"] and result["prior_profiles_and_apps_metadata_exact"]
            reserve()
            if result["passed"]:
                assert stage.parent == output and stage.name == "stage" and not stage.is_symlink()
                assert stage_files(stage) == actual_stage
                shutil.rmtree(stage)
                result["stage_cleanup"] = True
        except BaseException:
            result["passed"] = False
            result["preservation_failure"] = traceback.format_exc()
        result["peak_sampled_owned_allocated_bytes"] = peak
        result["available_bytes_after"] = shutil.disk_usage(ROOT).free
        result["partial_outputs_retained_on_failure"] = not result["passed"]
        write(output / "receipt.json", result)
    print(json.dumps({"passed": result["passed"], "output": str(output), "app": result.get("app"), "failure": result.get("failure"), "preservation_failure": result.get("preservation_failure")}))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
