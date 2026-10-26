"""Failure-path tests for receipts; no engine or player profile is launched."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("verify", Path(__file__).resolve().parents[1] / "tools/verify.py")
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


class VerificationReceipts(unittest.TestCase):
    def exercise(self, native_error=None, inspect_error=None, mutate=False, compact_error=None):
        with tempfile.TemporaryDirectory(prefix="mush-runner-test-") as folder:
            root = Path(folder)
            engine = root / "engine-fixture"
            engine.write_text("fixture, never executed")
            (root / ".godot").mkdir()
            (root / ".godot/global_script_class_cache.cfg").touch()
            source = root / "source.gd"
            source.write_text("original")

            def native(*args):
                if mutate:
                    source.write_text("unexpected change")
                if native_error:
                    raise native_error
                return {"exit_code": 0, "process_reaped": True}

            with contextlib.ExitStack() as stack:
                stack.enter_context(patch.object(verify, "ROOT", root))
                stack.enter_context(patch.object(verify, "assert_idle"))
                stack.enter_context(patch.object(verify, "reserve"))
                stack.enter_context(patch.object(verify.subprocess, "check_output", return_value="4.7.2.fixture"))
                stack.enter_context(patch.object(verify, "run", side_effect=native))
                stack.enter_context(patch.object(verify, "inspect", side_effect=inspect_error, return_value={"fixture": True}))
                stack.enter_context(patch.object(verify, "compact_reports", side_effect=compact_error, return_value=[]))
                stack.enter_context(patch.object(verify.sys, "argv", ["verify.py", "--engine", str(engine), "--suite", "ground"]))
                stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
                code = verify.main()
            receipts = list((root / "reports").glob("*/result.json"))
            self.assertEqual(len(receipts), 1)
            return code, json.loads(receipts[0].read_text())

    def test_failed_check_still_closes_preservation(self):
        code, receipt = self.exercise(inspect_error=AssertionError("frame budget"))
        self.assertEqual(code, 1)
        self.assertFalse(receipt["passed"])
        self.assertEqual(receipt["source_changes"], [])
        self.assertIn("frame budget", receipt["failure"])

    def test_native_failure_and_mutation_are_both_recorded(self):
        code, receipt = self.exercise(native_error=RuntimeError("native crash"), mutate=True)
        self.assertEqual(code, 1)
        self.assertIn("native crash", receipt["failure"])
        self.assertEqual(receipt["source_changes"], ["source.gd"])
        self.assertIn("preservation_failure", receipt)

    def test_compaction_failure_retains_failed_receipt(self):
        code, receipt = self.exercise(compact_error=OSError("compression unavailable"))
        self.assertEqual(code, 1)
        self.assertFalse(receipt["passed"])
        self.assertIn("compression unavailable", receipt["compaction_failure"])

    def test_success_requires_closed_preservation(self):
        code, receipt = self.exercise()
        self.assertEqual(code, 0)
        self.assertTrue(receipt["passed"])
        self.assertEqual(receipt["source_changes"], [])

    def test_duplicate_home_views_cannot_satisfy_capture_coverage(self):
        labels = [f"{pose}-{mood}" for mood in ("day", "night") for pose in
                  ("home2-close", "home2-wide", "home3-ground-obscured", "home3-elevated-diagnostic")]
        for duplicate in ("pairs", "views"):
            with self.subTest(duplicate=duplicate):
                report = {"schema": "mush-installed-distant-home-placement/1",
                          "passed": True, "failed": 0, "scene_restored": True,
                          "checks": [{"passed": True}], "startup": {"passed": True, "installed": True},
                          "pairs": [{"label": label} for label in labels],
                          "views": [{"label": f"{label}-{state}"} for label in labels
                                    for state in ("original", "installed")]}
                report[duplicate][-1] = report[duplicate][0]
                with patch.object(verify, "read_report", return_value=report):
                    with self.assertRaisesRegex(AssertionError, f"Expected ordered home-placement {duplicate}"):
                        verify.inspect("home-placement", Path("unused"), 120)


class ScenicCaptureCoverage(unittest.TestCase):
    def test_scenic_requires_every_view_and_appearance(self):
        views = [{"view": view, "appearance": mood, "passed": True, "file": f"{view}-{mood}.png"}
                 for mood in verify.SCENIC_APPEARANCES for view in verify.SCENIC_VIEWS]
        report = {"schema": "mush-scenic-capture/1", "passed": True, "look": "baseline",
                  "views": views[:-1], "hud": {"file": "ground-path-day-hud.png"}}
        with patch.object(verify, "read_report", return_value=report):
            with self.assertRaisesRegex(AssertionError, "Expected every scenic view"):
                verify.inspect("scenic", Path("unused"), 120)

    def test_pixel_metrics(self):
        white, black, mid, magenta = b"\xff\xff\xff\xff", b"\x00\x00\x00\xff", b"\x80\x70\x60\xff", b"\xff\x00\xff\xff"
        self.assertEqual(verify.clipped_fraction(white + black + mid + mid), 0.5)
        self.assertEqual(verify.changed_fraction(mid * 4, mid * 3 + white), 0.25)
        self.assertEqual(verify.changed_fraction(mid, b"\x84\x74\x64\xff"), 0.0)
        self.assertEqual(verify.mask_fraction(magenta + mid + mid + mid), 0.25)

    def test_prototype_gates_reject_hidden_canopy_and_large_hud(self):
        good = {"canopy": {"ground-path-day": 0.05, "scenic-vista-day": 0.09},
                "clipped": {"scenic-home-day": 0.01}, "hud": 0.03}
        self.assertEqual(verify.scenic_gate_failures(good), [])
        hidden = dict(good, canopy={"ground-path-day": 0.001, "scenic-vista-day": 0.09})
        self.assertIn("canopy ground-path-day", " ".join(verify.scenic_gate_failures(hidden)))
        clamped = dict(good, canopy={"ground-path-day": 0.05, "scenic-vista-day": 0.4})
        self.assertIn("canopy scenic-vista-day", " ".join(verify.scenic_gate_failures(clamped)))
        loud = dict(good, hud=0.2, clipped={"scenic-home-day": 0.05})
        failures = " ".join(verify.scenic_gate_failures(loud))
        self.assertIn("hud", failures)
        self.assertIn("clipped scenic-home-day", failures)


class RouteTraversalReport(unittest.TestCase):
    def test_one_failed_check_fails_the_suite(self):
        report = {"schema": "mush-route-traversal/1", "passed": True, "images": [], "legs": [],
                  "checks": [{"label": "walk", "passed": True}, {"label": "seam", "passed": False}]}
        with patch.object(verify, "read_report", return_value=report):
            with self.assertRaisesRegex(AssertionError, "seam"):
                verify.inspect("route", Path("unused"), 120)


class BenchmarkDrawProgress(unittest.TestCase):
    @staticmethod
    def progress(counts):
        return {"schema": "mush-benchmark-render-progress/1", "counter": "Engine.get_frames_drawn",
                "before_first_sample": 100, "sample_counts": counts, "valid": True,
                "undrawn_callbacks": 0, "backwards_callbacks": 0}

    def test_advancing_renderer(self):
        result = verify.inspect_render_progress(self.progress([101, 102, 104]), 3)
        self.assertTrue(result["engine_draw_progress_valid"])

    def test_fast_callbacks_cannot_hide_a_frozen_renderer(self):
        # Reject even a report that incorrectly claims validity and zero gaps.
        for counts in ([100, 101, 102], [101, 101, 102], [101, 99, 102]):
            with self.subTest(counts=counts), self.assertRaises(AssertionError):
                verify.inspect_render_progress(self.progress(counts), 3)

    def test_missing_or_incomplete_draw_evidence(self):
        for progress in (None, {}, self.progress([101, 102])):
            with self.subTest(progress=progress), self.assertRaises(AssertionError):
                verify.inspect_render_progress(progress, 3)


if __name__ == "__main__":
    unittest.main()
