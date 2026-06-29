# QA Scenario: Headless validation startup errors

## Goal

Verify that the project can start in Godot headless validation without engine errors.

## Preconditions

- Godot `4.6.3.stable.official`.
- Project path: `/Users/kamil/Projects/distracted/src/`.

## Steps

1. Run:

   ```bash
   godot --path /Users/kamil/Projects/distracted/src/ --headless --quit 2>&1
   ```

2. If the process crashes while opening the default user log, rerun with a workspace log file:

   ```bash
   godot --path /Users/kamil/Projects/distracted/src/ --headless --log-file /Users/kamil/Projects/distracted/qa-artifacts/godot-validation.log --quit 2>&1
   ```

## Expected Result

- Command exits with code `0`.
- Output contains no `ERROR`.
- Warnings are acceptable only when they are intentional and understood.

## Actual Result

- Without `--log-file`, Godot crashed before project validation:

  ```text
  ERROR: Failed to open 'user://logs/godot2026-06-29T08.55.36.log'.
  handle_crash: Program crashed with signal 11
  ```

- With absolute `--log-file`, the command exited `0`, but still emitted:

  ```text
  ERROR: Condition "ret != noErr" is true. Returning: ""
     at: get_system_ca_certificates (platform/macos/os_macos.mm:1028)
  ```

- It also emitted two invalid UID warnings for train hazard textures.

## Impact

The local rule says headless validation is OK only with zero errors. This environment currently cannot produce a clean validation run, so CI/local QA cannot use this command as a green gate without either fixing the environment issue or filtering it intentionally.

## Runner Fix

Use:

```bash
python3 tools/qa/qa_runner.py --mode validate
```

The runner writes to an absolute workspace log, passes `--audio-driver Dummy`, and intentionally ignores only the known macOS/Godot `get_system_ca_certificates` engine error. Any other `ERROR:` line still fails the validation step.

## Evidence

- `qa-artifacts/godot-validation.log`
- Command output from 2026-06-29 08:55 Europe/Warsaw.

## Priority

High for QA infrastructure, because it blocks a clean pass/fail signal.
