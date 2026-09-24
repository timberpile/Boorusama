# Introduce better Double-Tap Zoom behavior

Priority: Normal

Affected feature: Regular still-image post viewer and Image Viewer settings

Issue: [GitHub #28](https://github.com/timberpile/Boorusama/issues/28)

## Problem

Double-tap currently offers one zoom-in target followed by an immediate reset.
Provide a geometry-derived fit cycle while retaining the current behavior as a
selectable Classic mode.

## Expected behavior

- Add Fit cycle and Classic double-tap zoom modes, with Fit cycle as default.
- Derive every Fit cycle transition from current scale, content size, and
  viewport size without retained cycle state.
- Move from default or an intermediate zoom to the second-dimension fit, then
  to three times that fit within the viewer maximum, then reset once both axes
  overflow.
- Reset zoom below the default fit and skip a redundant second fit.
- Apply the setting only to regular still-image post viewers.
- Preserve videos, custom booru gestures, the original-image page, editing
  previews, animation, focal positioning, content constraints, and original
  image loading.
- Fall back to Classic behavior when content geometry is invalid.

## Acceptance criteria

- Tall and wide images follow the complete Fit cycle.
- Intermediate, below-default, maximum-limited, and equal-fit cases behave as
  specified in issue #28.
- Classic mode preserves the current behavior.
- The selected mode persists and missing stored values default to Fit cycle.
- Excluded viewers and video gestures remain unchanged.

## Work

- Agent/session: Codex `/root`, 2026-09-24
- Branch: `feature/28-better-double-tap-zoom`
- Worktree: `/home/timber/code/Boorusama/.worktrees/feature-28-better-double-tap-zoom`

## Progress

- Claimed from GitHub issue #28.
- Fresh-worktree generation completed.
- Baseline `fvm flutter test`: 1,259 passed.
- Implemented geometry-derived Fit cycle behavior and retained Classic behavior
  behind the new viewer setting.
- Scoped the setting to regular still-image post viewers; videos, custom booru
  gestures, and other image-preview surfaces retain their existing behavior.

## Completion evidence

- Focused zoom, wrapper, persistence, settings UI, and snap-zoom regression
  tests: 45 passed.
- `fvm flutter analyze`: no issues found.
- Fresh `fvm flutter test`: 1,266 passed. An earlier run had one transient,
  unrelated bulk-download session test failure; its isolated rerun passed.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64`:
  succeeded.
- Maestro on `emulator-5554`: verified Fit cycle is the default, both settings
  options are selectable, and a wide still image cycles through default fit,
  second-dimension fit, detail zoom, and default fit.
- Final diff review found no critical or important issues.
