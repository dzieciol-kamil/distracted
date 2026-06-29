import tempfile
import time
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import qa_runner


class QaRunnerTest(unittest.TestCase):
    def test_visual_command_uses_windowed_rendering_and_absolute_log(self):
        root = Path("/repo")
        command = qa_runner.build_command(root, "visual", "godot", "2026-06-29T10-30-00")

        self.assertNotIn("--headless", command.args)
        self.assertIn("--windowed", command.args)
        self.assertIn("--scene", command.args)
        self.assertIn("res://scenes/qa/visual_qa.tscn", command.args)
        self.assertEqual(
            str(root / "qa-artifacts" / "2026-06-29T10-30-00" / "visual-qa.log"),
            command.args[command.args.index("--log-file") + 1],
        )
        self.assertIn("--qa-artifact-dir", command.args)
        self.assertEqual(
            "res://../qa-artifacts/2026-06-29T10-30-00/visual-qa",
            command.args[command.args.index("--qa-artifact-dir") + 1],
        )

    def test_validation_command_is_headless_and_uses_absolute_log(self):
        root = Path("/repo")
        command = qa_runner.build_command(root, "validate", "godot", "2026-06-29T10-30-00")

        self.assertIn("--headless", command.args)
        self.assertEqual(
            str(root / "qa-artifacts" / "2026-06-29T10-30-00" / "godot-validation.log"),
            command.args[command.args.index("--log-file") + 1],
        )

    def test_smoke_command_writes_to_timestamped_artifact_dir(self):
        root = Path("/repo")
        command = qa_runner.build_command(root, "smoke", "godot", "2026-06-29T10-30-00")

        self.assertEqual(root / "qa-artifacts" / "2026-06-29T10-30-00" / "gameplay-smoke", command.artifact_path)
        self.assertIn("--qa-artifact-dir", command.args)
        self.assertEqual(
            "res://../qa-artifacts/2026-06-29T10-30-00/gameplay-smoke",
            command.args[command.args.index("--qa-artifact-dir") + 1],
        )

    def test_known_macos_ca_error_is_not_significant(self):
        log = """Godot Engine v4.6.3
ERROR: Condition "ret != noErr" is true. Returning: ""
   at: get_system_ca_certificates (platform/macos/os_macos.mm:1028)
"""

        self.assertEqual([], qa_runner.significant_error_lines(log))

    def test_capture_error_is_significant(self):
        log = """ERROR: QA capture failed for preset: zones
   at: push_error (core/variant/variant_utility.cpp:1024)
"""

        self.assertEqual(
            ["ERROR: QA capture failed for preset: zones"],
            qa_runner.significant_error_lines(log),
        )

    def test_stale_or_missing_artifacts_fail_freshness_check(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            artifact_dir = Path(temp_dir)
            old_file = artifact_dir / "zones.png"
            old_file.write_bytes(b"old")
            start_time = time.time() + 5.0

            missing_or_stale = qa_runner.missing_or_stale_artifacts(
                artifact_dir,
                ["zones.png", "hazards.png"],
                start_time,
            )

        self.assertEqual(["zones.png", "hazards.png"], missing_or_stale)

    def test_prepare_artifact_dir_does_not_delete_previous_files(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            artifact_dir = Path(temp_dir) / "qa-artifacts" / "2026-06-29T10-30-00" / "visual-qa"
            artifact_dir.mkdir(parents=True)
            existing_file = artifact_dir / "zones.png"
            existing_file.write_bytes(b"keep")
            command = qa_runner.QaCommand(
                mode="visual",
                args=[],
                log_path=artifact_dir.parent / "visual-qa.log",
                artifact_path=artifact_dir,
                expected_artifacts=("zones.png",),
            )

            qa_runner.prepare_artifact_dir(command)

            self.assertEqual(b"keep", existing_file.read_bytes())


if __name__ == "__main__":
    unittest.main()
