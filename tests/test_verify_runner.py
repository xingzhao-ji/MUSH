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


if __name__ == "__main__":
    unittest.main()
