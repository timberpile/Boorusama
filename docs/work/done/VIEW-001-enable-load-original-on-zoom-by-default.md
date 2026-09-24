# Enable load-original-on-zoom by default

Priority: Normal

Affected feature: Image Viewer settings

## Problem

Loading the original image while zooming defaults to disabled.

## Expected behavior

- New settings enable loading the original image while zooming.
- Existing settings without a stored choice use the enabled default.
- An explicitly disabled choice remains disabled.

## Acceptance criteria

- Default and persistence behavior is covered by focused tests.
- No unrelated viewer behavior changes.

## Work

- Agent/session: Codex `/root`, 2026-09-24
- Branch: `develop` (user-authorized direct commit)

## Completion evidence

- `fvm flutter test test/settings/load_original_on_zoom_test.dart`: 3 passed.
- `fvm flutter test`: 1,287 passed and two unrelated bulk-download session
  tests failed. One passed when rerun alone; the other still exposed its
  existing timing-dependent session-state behavior when isolated.
