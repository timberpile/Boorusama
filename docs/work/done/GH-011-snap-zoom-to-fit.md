# Snap image zoom to viewport width or height

Priority: Normal

Affected feature: Regular post viewer and Image Viewer settings

Issue: [GitHub #11](https://github.com/timberpile/Boorusama/issues/11)

## Problem

Near-fit pinch zoom levels are difficult to land exactly. When a pinch ends,
the regular post viewer should snap a rendered image dimension that is within
5% of its viewport dimension to an exact fit.

## Expected behavior

- Evaluate snapping only when a pinch gesture ends.
- Treat the inclusive 95%-105% range as eligible.
- If width and height both qualify, snap the proportionally closer dimension.
- Preserve aspect ratio, existing zoom limits, and content-aware panning.
- Add an enabled-by-default Image Viewer setting that can disable snapping.
- Do not change the original-image page.
- Cover gesture timing, thresholds, axis selection, and settings behavior.

## Work

- Agent/session: Codex `/root`, 2026-09-21
- Branch: `feature/11-snap-zoom-to-fit`
- Worktree: `/home/timber/code/Boorusama/.worktrees/feature-11-snap-zoom-to-fit`

## Progress

- Claimed from GitHub issue #11.
- Baseline full suite: 1,240 passed and one unrelated bulk-download session
  test failed; the exact failed test passed immediately when rerun alone.
- Added enabled-by-default persisted Image Viewer control and localized copy.
- Added opt-in regular-viewer snapping at pinch end while leaving the
  original-image viewer unchanged.
- Verified inclusive thresholds, closest-axis selection, gesture timing,
  disabled behavior, and settings persistence with focused widget tests.

## Completion evidence

- `fvm flutter test packages/kurumi/test/interactive_viewer_test.dart test/settings/snap_zoom_to_fit_test.dart test/core/widgets/interactive_viewer_extended_test.dart`: 23 passed.
- `fvm flutter test`: 1,245 passed.
- `fvm flutter analyze`: no issues found.
- `fvm flutter build apk --debug --flavor dev`: succeeded.
- Maestro: confirmed the Image Viewer setting defaults on, can be disabled,
  and can be restored on the Android emulator.
