# BM-006: Refresh post viewer after bookmark removal

Priority: Normal
Affected feature: Bookmark controls in the post viewer

## Problem

User reports that removing a bookmark does not update the post viewer UI.
Verify this against current local develop before changing behavior.

## Acceptance criteria

- Reproduce the reported stale state, or document evidence that current behavior is correct.
- If confirmed, removal updates visible bookmark controls without reopening the viewer.
- Preserve existing group membership, deferred removal/cancellation, and viewer navigation semantics.
- Cover the confirmed failure with a focused regression test and validate the scoped change.

## Ownership

- Coordinator/session: /root, 2026-10-06 bookmark-viewer-removal-ui
- Implementer: /root/bookmark_removal (assigned by coordinator)
- Branch: fix/bookmark-viewer-removal-ui
- Worktree: /home/timber/code/Boorusama/.worktrees/bookmark-viewer-removal-ui
- Base: current local develop, 20b2b595c

## Context

Read `docs/bookmark_groups.md`, the unified post/viewer design, and related
POST-001, BM-001, and BM-002 tickets. Follow the development workflow and
engineering guidelines. This request authorizes investigation and a scoped
fix on the dedicated branch; develop integration and publication need separate approval.

## Progress

- Confirmed on unchanged local develop behavior with a mounted named-group
  bookmark button regression: after tapping Remove, the glyph remained filled
  (`Expected: false`, `Actual: true`).
- Root cause: the bookmark-group viewer intentionally queues membership changes
  until closing, but those pending changes were neither published nor included
  in the toolbar's membership presentation.
- Published immutable pending intent and projected it into both bookmark toolbar
  variants. Storage, post-list snapshots, deferred commit, and grid visibility
  notifications retain their existing behavior.
- Added regression coverage for both toolbar variants, immediate icon/tooltip
  changes, second-tap cancellation, multiple group counts, final-group removal,
  unrelated posts, and ungrouped additions.
- Coordinator's independent review found no critical or important issues.

## Verification

- Fresh worktree: `fvm dart pub get` in `packages/boorusama_cli`, then `./gen.sh`,
  both exited 0.
- RED: `fvm flutter test --no-pub
  test/core/bookmarks/bookmark_post_button_layout_test.dart --plain-name
  'deferred group removal updates the button and second tap restores it'`
  exited 1 with the expected stale filled icon assertion before the fix.
  Evidence: `/tmp/bookmark-viewer-removal-ui-20261006-red.log`.
- Focused bookmark/post suite initially passed 545 tests and failed one new
  fixture because its group ID was not a UUID. Corrected the fixture.
- Targeted `fvm flutter analyze --no-pub` of all five touched Dart files exited 0
  with no issues. Evidence:
  `/tmp/bookmark-viewer-removal-ui-20261006-analysis.log`.
- `fvm flutter test --no-pub` completed with 2,602 tests passed and two
  unrelated timing failures (exit 1):
  `progressive_non_admitted_cache_test.dart` / progressive live handoff with
  decoded cache admission disabled; `share_original_copy_test.dart` / copying
  Original prepares the exact image and reports success. Evidence:
  `/tmp/bookmark-viewer-removal-ui-20261006-full.log`.
- Serial isolated rerun using `fvm flutter test --no-pub --concurrency=1` on
  those two files plus both changed regression files passed all 19 tests
  (exit 0). Evidence:
  `/tmp/bookmark-viewer-removal-ui-20261006-isolated.log`.
- All acceptance criteria verified through regression, existing bookmark/post
  coverage, and scoped analysis. The full concurrent-suite failures are retained
  above; no unrelated changes were made.
- `git diff --check` is clean.
- Native Android/Maestro checks were not run; no emulator was used.
- Branch remains isolated for user review; no develop integration or remote
  publication is authorized.

## Approved local delivery (2026-10-06)

- User approved integrating `fix/bookmark-viewer-removal-ui` and removing its
  branch/worktree. Remote publication remains separate.
- Coordinator and independent reviewer verified the scoped change. Repeated
  serial integration check passed all 19 tests, exit 0; evidence:
  `/tmp/bookmark-viewer-removal-ui-20261006-integration.log`.
- The approved branch has exactly one descriptive single-parent commit based
  on current local develop `20b2b595c`. Local integration reuses that verified
  commit by advancing develop, preserving the separate primary checkout state.
