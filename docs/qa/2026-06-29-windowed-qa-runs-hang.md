# QA Scenario: Windowed QA commands do not finish in CLI run

## Goal

Verify that windowed QA commands complete and return a useful pass/fail signal.

## Preconditions

- Godot `4.6.3.stable.official`.
- macOS CLI execution.
- Workspace log files passed with `--log-file`.

## Steps

1. Run visual QA capture:

   ```bash
   godot --path /Users/kamil/Projects/distracted/src/ --scene res://scenes/qa/visual_qa.tscn --log-file /Users/kamil/Projects/distracted/qa-artifacts/visual-qa.log --quit-after 180 -- --qa-capture 2>&1
   ```

2. Run gameplay smoke:

   ```bash
   godot --path /Users/kamil/Projects/distracted/src/ --log-file /Users/kamil/Projects/distracted/qa-artifacts/gameplay-smoke.log --quit-after 300 -- --qa-gameplay-smoke 2>&1
   ```

3. Wait for expected QA logs and process exit.

## Expected Result

- Visual QA prints `QA capture saved: ...` for all presets and exits.
- Gameplay smoke prints:
  - `QA gameplay smoke: start`
  - capture steps
  - `QA gameplay smoke: complete`
- Both commands exit without manual intervention.

## Actual Result

- Both windowed commands stayed running after 60 seconds.
- The only visible output was macOS service noise:

  ```text
  Failure on line 688 in function id scheduleApplicationNotification(...)
  Error received in message reply handler: Connection invalid
  Connection Invalid error for service com.apple.hiservices-xpcservice.
  ```

- The hung processes had to be terminated manually.
- The PNG files under `qa-artifacts/visual-qa/` and `qa-artifacts/gameplay-smoke/` were older than this test run, so they cannot be treated as fresh evidence from these commands.

## Impact

The documented QA commands are not reliable as unattended CLI checks in this environment. This makes the QA loop ambiguous: a run can hang without a game-level failure message.

## Runner Fix

Use:

```bash
python3 tools/qa/qa_runner.py --mode visual
python3 tools/qa/qa_runner.py --mode smoke
```

The hang reproduced only in the sandboxed macOS display context. Outside the sandbox, both runner modes completed and generated fresh artifacts. The runner adds a process timeout, absolute logs, stale artifact cleanup, and post-run freshness checks so a failed windowed start no longer looks like a usable QA result.

## Evidence

- Windowed visual QA process started at 2026-06-29 08:56 Europe/Warsaw and was killed.
- Windowed gameplay smoke process started at 2026-06-29 08:57 Europe/Warsaw and was killed.
- Artifact mtimes remained older than the test run.

## Priority

High for QA workflow reliability.
