# AI Visual QA Guidelines

## Purpose

This file records owner-approved product rules for AI visual QA. It is not a technical tuning log. Use it to decide what AI can fix directly, what requires approval, and how to explain visual changes in PRs and issues.

## Can Fix Without Asking

- Objects that are visibly too large, too small, rotated the wrong way, floating, clipping, or placed outside a useful camera frame.
- Hazards that appear too late, too early, or in a position where the player cannot read them fairly.
- Movement speeds that make a hazard unreadable as a visual threat.
- UI or phone graphics that are hard to read or obviously block the intended play view.
- Collision shapes that no longer match the visual object after an accepted visual change.

## Requires Owner Approval

- Changes to the character of a biome or the overall art direction.
- Changes to the main progression structure.
- Changes that make the game easier or harder as a design decision rather than fixing readability.
- Removing a visual idea entirely instead of correcting its scale, timing, or presentation.
- Any change where AI cannot tell whether the current result is a bug or intentional style.

## Rejected Patterns

- None yet.

## Product Preferences

- Buildings can build atmosphere, but they must not pull attention away from the road.
- Hazards must be recognizable before the player reaches them.
- The phone should interfere with play, but the situation must still feel fair.
- Visual difficulty should come from clear hazards and distraction pressure, not from messy staging.
- PRs and issues must explain what the player sees and why the proposed change helps.

## Decision Examples

- Issue #22 approved: AI can use QA Scene plus gameplay smoke to find and fix small visual/readability issues, then report the result in PR and wait for owner OK before merge.
