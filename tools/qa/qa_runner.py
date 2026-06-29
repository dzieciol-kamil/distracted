#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
PROJECT_DIR = "src"
ARTIFACT_DIR = "qa-artifacts"

MODES = ("validate", "visual", "smoke")
VISUAL_ARTIFACTS = ("zones.png", "hazards.png", "ui_hud.png", "ui_phone.png")
SMOKE_ARTIFACTS = ("01_game_loaded.png", "02_after_short_walk.png", "03_phone_overlay.png")


@dataclass(frozen=True)
class QaCommand:
    mode: str
    args: list[str]
    log_path: Path
    artifact_path: Path | None = None
    expected_artifacts: tuple[str, ...] = ()


def build_command(root: Path, mode: str, godot: str, run_id: str) -> QaCommand:
    root = root.resolve()
    project_path = root / PROJECT_DIR
    artifact_root = root / ARTIFACT_DIR / run_id

    if mode == "validate":
        log_path = artifact_root / "godot-validation.log"
        return QaCommand(
            mode=mode,
            log_path=log_path,
            args=[
                godot,
                "--path",
                str(project_path),
                "--headless",
                "--audio-driver",
                "Dummy",
                "--log-file",
                str(log_path),
                "--quit",
            ],
        )

    if mode == "visual":
        log_path = artifact_root / "visual-qa.log"
        artifact_path = artifact_root / "visual-qa"
        artifact_arg = f"res://../{ARTIFACT_DIR}/{run_id}/visual-qa"
        return QaCommand(
            mode=mode,
            log_path=log_path,
            artifact_path=artifact_path,
            expected_artifacts=VISUAL_ARTIFACTS,
            args=[
                godot,
                "--path",
                str(project_path),
                "--windowed",
                "--audio-driver",
                "Dummy",
                "--disable-vsync",
                "--fixed-fps",
                "60",
                "--scene",
                "res://scenes/qa/visual_qa.tscn",
                "--log-file",
                str(log_path),
                "--quit-after",
                "180",
                "--",
                "--qa-capture",
                "--qa-artifact-dir",
                artifact_arg,
            ],
        )

    if mode == "smoke":
        log_path = artifact_root / "gameplay-smoke.log"
        artifact_path = artifact_root / "gameplay-smoke"
        artifact_arg = f"res://../{ARTIFACT_DIR}/{run_id}/gameplay-smoke"
        return QaCommand(
            mode=mode,
            log_path=log_path,
            artifact_path=artifact_path,
            expected_artifacts=SMOKE_ARTIFACTS,
            args=[
                godot,
                "--path",
                str(project_path),
                "--windowed",
                "--audio-driver",
                "Dummy",
                "--disable-vsync",
                "--fixed-fps",
                "60",
                "--log-file",
                str(log_path),
                "--quit-after",
                "300",
                "--",
                "--qa-gameplay-smoke",
                "--qa-artifact-dir",
                artifact_arg,
            ],
        )

    raise ValueError(f"Unknown QA mode: {mode}")


def significant_error_lines(log_text: str) -> list[str]:
    lines = log_text.splitlines()
    errors: list[str] = []

    for index, line in enumerate(lines):
        if not line.startswith("ERROR:"):
            continue

        context = "\n".join(lines[index : index + 3])
        if (
            'ERROR: Condition "ret != noErr" is true. Returning: ""' in context
            and "get_system_ca_certificates" in context
        ):
            continue

        errors.append(line)

    return errors


def missing_or_stale_artifacts(artifact_dir: Path, expected: list[str] | tuple[str, ...], start_time: float) -> list[str]:
    missing_or_stale: list[str] = []
    for filename in expected:
        path = artifact_dir / filename
        if not path.exists() or path.stat().st_size <= 0 or path.stat().st_mtime < start_time:
            missing_or_stale.append(filename)
    return missing_or_stale


def prepare_artifact_dir(command: QaCommand) -> None:
    if command.artifact_path is None:
        return
    command.artifact_path.mkdir(parents=True, exist_ok=True)


def validate_log(command: QaCommand) -> list[str]:
    if not command.log_path.exists():
        return [f"Missing log file: {command.log_path}"]
    return significant_error_lines(command.log_path.read_text(encoding="utf-8", errors="replace"))


def run_command(command: QaCommand, timeout_seconds: int) -> int:
    command.log_path.parent.mkdir(parents=True, exist_ok=True)
    prepare_artifact_dir(command)

    start_time = time.time()
    print(f"QA {command.mode}: start", flush=True)
    print(" ".join(command.args), flush=True)

    try:
        completed = subprocess.run(command.args, cwd=REPO_ROOT, timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        print(f"QA {command.mode}: timed out after {timeout_seconds}s", file=sys.stderr)
        return 124

    failures = validate_log(command)
    if command.artifact_path is not None:
        failures.extend(
            f"Missing or stale artifact: {filename}"
            for filename in missing_or_stale_artifacts(
                command.artifact_path,
                command.expected_artifacts,
                start_time,
            )
        )

    if completed.returncode != 0:
        failures.append(f"Godot exited with code {completed.returncode}")

    if failures:
        print(f"QA {command.mode}: failed", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1

    print(f"QA {command.mode}: ok")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run Distracted Godot QA checks.")
    parser.add_argument("--mode", choices=("all", *MODES), default="all")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--timeout", type=int, default=90)
    parser.add_argument("--run-id", default=None, help="Artifact run directory name. Defaults to a local timestamp.")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    modes = MODES if args.mode == "all" else (args.mode,)
    run_id = args.run_id or datetime.now().strftime("%Y-%m-%dT%H-%M-%S")
    commands = [build_command(REPO_ROOT, mode, args.godot, run_id) for mode in modes]

    if args.dry_run:
        for command in commands:
            print(" ".join(command.args))
        return 0

    for command in commands:
        exit_code = run_command(command, args.timeout)
        if exit_code != 0:
            return exit_code
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
