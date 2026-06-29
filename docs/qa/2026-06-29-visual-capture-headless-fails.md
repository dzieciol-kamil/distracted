# QA Scenario: Visual QA capture fails in headless mode

## Goal

Verify that `visual_qa.tscn` can generate screenshot artifacts for zones, hazards, HUD, and phone UI in an automated run.

## Preconditions

- Godot `4.6.3.stable.official`.
- QA scene: `res://scenes/qa/visual_qa.tscn`.
- Capture script reads the current viewport image in `src/scripts/qa/qa_capture.gd`.

## Steps

1. Run:

   ```bash
   godot --path /Users/kamil/Projects/distracted/src/ --headless --scene res://scenes/qa/visual_qa.tscn --log-file /Users/kamil/Projects/distracted/qa-artifacts/visual-qa-headless.log --quit-after 180 -- --qa-capture 2>&1
   ```

2. Check exit code and `qa-artifacts/visual-qa/*.png`.

## Expected Result

- Command exits with code `0`.
- Fresh PNG files are written:
  - `qa-artifacts/visual-qa/zones.png`
  - `qa-artifacts/visual-qa/hazards.png`
  - `qa-artifacts/visual-qa/ui_hud.png`
  - `qa-artifacts/visual-qa/ui_phone.png`

## Actual Result

- Command exited with code `1`.
- No fresh screenshots were produced.
- Every capture preset failed at the same line:

  ```text
  ERROR: Parameter "t" is null.
     at: texture_2d_get (./servers/rendering/dummy/storage/texture_storage.h:106)
     GDScript backtrace:
       [0] capture_presets (res://scripts/qa/qa_capture.gd:22)
  ERROR: QA capture failed for preset: zones
  ERROR: QA capture failed for preset: hazards
  ERROR: QA capture failed for preset: ui_hud
  ERROR: QA capture failed for preset: ui_phone
  ```

## Root Cause Hypothesis

In headless mode Godot uses the dummy display/rendering path, so `viewport.get_texture().get_image()` has no real texture to read. The failure is in the screenshot mechanism, not in the visual QA scene construction itself.

## Impact

This blocks fully headless visual regression capture. Automated QA needs either a non-headless display backend, a virtual display setup, or a capture path that supports offscreen rendering.

## Runner Fix

Use:

```bash
python3 tools/qa/qa_runner.py --mode visual
```

The runner keeps screenshot capture out of `--headless`, because Godot 4.6 headless uses dummy texture storage. It runs visual capture with the windowed renderer, deletes stale expected PNGs before the run, and fails if fresh `zones.png`, `hazards.png`, `ui_hud.png`, or `ui_phone.png` are missing.

## Evidence

- `qa-artifacts/visual-qa-headless.log`
- `src/scripts/qa/qa_capture.gd:22`

## Priority

High for visual QA automation.
