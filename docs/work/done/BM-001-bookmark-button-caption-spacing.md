# BM-001: Tighten bookmark button caption spacing

Priority: Normal

Affected feature: Post viewer bookmark action

Agent/session: Codex `/root`

Work branch: `fix/bookmark-button-caption-spacing`

## Problem

The active bookmark-group name starts below the full 48-pixel icon button box,
leaving a large visual gap below the bookmark glyph. A wrapped group name then
adds more toolbar height than its extra line needs.

## Expected behavior

- The caption keeps a two-pixel margin above and below its text.
- A short caption uses minimal vertical space while preserving the 48-pixel tap
  target.
- A two-line caption increases toolbar height only by the additional text line.
- Tapping and long-pressing the visible caption retain their existing actions.

## Acceptance criteria

- Widget tests cover short and wrapping group names and the retained tap target.
- Focused Flutter tests pass.
- The short and long layouts are verified on an Android emulator.

## Relevant context

- `docs/bookmark_groups.md`, Post viewer toolbar layout
- `lib/core/posts/details_parts/src/toolbars/bookmark_post_button.dart`

## Dependencies

None.

## Progress

- Isolated worktree created from `origin/develop`.
- Full baseline suite exposed two unrelated bulk-download session failures;
  both passed when their test file was rerun alone.
- Regression tests first measured a 12-pixel gap between the bookmark glyph and
  caption, then passed with the compact layout.
- A visual follow-up added two logical pixels above and below the caption.

## Completion evidence

- `fvm flutter analyze --no-pub`: no issues.
- Focused bookmark layout, caption interaction, and details-toolbar tests: 5
  passed.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64`:
  succeeded.
- Maestro on `emulator-5554`: the final short and wrapping captions measured 51
  and 62 logical pixels high while retaining the 48-logical-pixel icon tap
  target.
- Final full suite: 1,289 tests passed and the unrelated bulk-download dry-run
  resume test flaked once; its complete 33-test file passed immediately in
  isolation.
- Independent review found no remaining critical or important issues after the
  caption hit-testing regression and exact margin assertions were fixed.
