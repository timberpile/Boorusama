# Silently recover incomplete bookmark data when opening a post

Priority: Normal
Affected feature: Bookmark post viewer; AnimeBoxes imports

## Problem

Opening Danbooru or Realbooru bookmarks imported from AnimeBoxes immediately shows “Some saved site-specific data could not be read”. Pressing Retry successfully loads the missing data, and later openings remain correct. Imported snapshots may lack the engine-specific metadata needed for native presentation.

## Expected behavior and acceptance criteria

- When opening a bookmark with missing or unreadable site-specific data and a resolvable profile, automatically attempt the existing Retry recovery path once before showing an error.
- Keep the available post presentation visible during the attempt. Do not add a progress bar, spinner, or dedicated loading state for this recovery, and do not flash the initial error before the attempt finishes.
- If recovery succeeds, update the displayed post and persist the recovered snapshot using the existing path, preserving bookmark identity and group membership. Subsequent openings use the recovered data.
- If recovery fails, show the appropriate error and retain manual Retry. Do not trigger an automatic retry loop on rebuilds.
- Complete snapshots open without an extra fetch. Cover successful and failed recovery, persistence/reopening, and no duplicate requests in focused regression tests; verify the reported opening flow.

## Scope and context

Approved by the user on 2026-10-05. Keep this a small extension of the existing recovery path at post opening. Do not eagerly hydrate bookmark groups or fetch after import. Missing-profile import requirements are a separate workitem to be clarified.

Relevant code: `lib/core/bookmarks/src/pages/bookmark_details_page.dart` and `lib/core/posts/details/src/widgets/mixed_post_details_page.dart`. Relevant documentation: [unified post design](../../superpowers/specs/2026-09-22-unified-post-model-and-viewer-design.md) and [AnimeBoxes migration](../../migrations/animeboxes.md).

Follow [development workflow](../../development_workflow.md) and [engineering guidelines](../../engineering_guidelines.md). This ticket is unclaimed; implementation must be delegated in its own branch/worktree.

## Claim

Claimed 2026-10-05 by coordinator `/root`; implementer `/root/post008_recovery`; branch `fix/post-008-silent-bookmark-recovery`; dedicated worktree `/home/timber/code/Boorusama/.worktrees/post-008-silent-bookmark-recovery`. Implementation queued for the next available slot; review pending.

## Coordinated review status (2026-10-05)

Implementation: `2518d6ffd`. Independent review approved; 11 focused tests pass, including durable snapshot persistence. Coordinator imported/opened/reopened a public safe Danbooru bookmark on emulator-5558 without manual Retry or saved-metadata error.

Combined verification is isolated in `.worktrees/nine-release-fixes-review` on `review/nine-release-fixes`. The final combined serial Flutter suite passed all 2,206 tests (exit 0); the unchanged current CLI implementation passed all 239 tests. The final Dev APK built successfully. Analysis of 29 changed Dart files found no errors or warnings; two unchanged baseline const-style informational lints remain. Development integration, publication, and cleanup have not been performed. Keep this ticket in progress pending final combined checks and its remaining acceptance evidence.

## User approval and delivery (2026-10-05)

User verified the silent retry behaves as expected and explicitly approved local develop integration. All 11 bookmark viewer regressions passed again on develop, including persisted repair, single automatic attempt, manual Retry after failure, and closing during recovery. Ticket completed; remote publication is not authorized.
