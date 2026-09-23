# Fix confirmed emulator regressions

Priority: Normal

Affected feature: Search error presentation and theme preview

Agent/session: Codex `/root`, 2026-09-23

Work branch: `fix/qa-confirmed-regressions`

Dependencies: None

## Problem

The four-emulator regression pass found two reproducible app defects:

- An offline post-grid request exposes the full Dio, Cronet, and request URL
  diagnostic below the localized connection message.
- Opening the theme color preview emits Flutter's `ListTile background color or
  ink splashes may be invisible` framework assertion.

## Expected behavior

- Connection failures show only the localized, actionable error and Retry UI.
- The theme color preview preserves its current appearance and opens without a
  framework assertion.

## Acceptance criteria

- A regression test proves raw transport diagnostics are not included in the
  user-facing connection message.
- A widget regression test opens the theme preview sheet without framework
  exceptions.
- Focused tests, the full Flutter test suite, analysis, and diff checks pass.
- Both original symptoms are rechecked on `emulator-5562` with Maestro.

## Context

- Tested baseline: `9fb3e9b7d9c5aa99ea25fe8e4fe6508e5d0eedf3`.
- The failed Danbooru media item is excluded: a neighboring video played and the
  item-specific failure could not be reproduced on the root device's available
  profile.

## Progress

- Reproduced the offline diagnostic twice on `emulator-5562`.
- Reproduced the theme assertion by opening Appearance > Colors on
  `emulator-5562` and matched it to the colored `ThemePreviewerSheet` container.
- The unchanged worktree baseline passes all 1,370 tests.
- Added focused regression coverage for both defects and confirmed both tests
  failed for their intended reason before the production fixes.
- Replaced the theme preview's opaque decorated container with the sheet's
  `Material`, preserving its color and rounded top edge.
- Removed raw transport details from the user-facing cannot-reach-server text.

## Completion evidence

- Focused regression tests: 2 passed.
- Full Flutter suite: 1,372 passed.
- Flutter analysis completed with only the branch's existing info diagnostics
  (234); no errors or warnings.
- `emulator-5562`: Appearance > Colors opens without the `ListTile` assertion.
- `emulator-5562`: airplane-mode refresh shows only the localized connection
  message and Retry; reconnecting and retrying restores the 60-post grid.
- Device state restored and rechecked on a normal build: Colors Default, Grid
  size Medium, Image quality Automatic, airplane mode off, app stopped.
