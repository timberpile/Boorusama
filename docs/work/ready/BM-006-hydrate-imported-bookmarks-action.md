# Manually hydrate imported bookmarks with native post data

Priority: Normal  
Affected feature: Bookmarks, imported legacy post snapshots, and settings maintenance actions

## Problem and goal

Imported bookmarks, especially those originating from older or external formats such as Anime Boxes, can contain only the shared post data and `LegacyPostData` without the site-specific `BooruPostData`.

When such a bookmark is opened, the existing bookmark recovery path fetches the complete upstream post and replaces the stored snapshot. After that, the bookmark behaves like a natively created bookmark. However, the initial recovery can cause visible layout changes, glitches, or brief stuttering while the viewer switches from the generic fallback presentation to the native site-specific presentation.

Normal users do not need an automatic migration of their complete bookmark library. Instead, provide a deliberately hidden maintenance action that can hydrate all incomplete bookmark snapshots in one explicit batch operation.

## Agreed design and acceptance criteria

- Add a deeply nested advanced maintenance area under `Settings → Data & Storage`. Bookmark hydration should not appear as a prominent normal setting.
- The action must remain accessible in release builds and therefore must not live exclusively inside the current Developer Options, which are only exposed in development environments.
- Provide an action such as `Hydrate bookmark metadata` that processes only bookmarks whose stored post does not yet contain native site-specific payload data. In particular, bookmarks backed by `LegacyPostData` are hydration candidates.
- Bookmarks that already contain complete native post snapshots must not be fetched again.
- Before starting, show how many hydration candidates were found. If none are present, do not start a network operation.
- Before a large batch starts, confirm that the operation can perform network requests against the respective booru sites.
- Resolve the corresponding profile for each candidate through the existing `PostOrigin` / `PostOriginResolver` logic. The batch must not arbitrarily select another profile for the same engine.
- Reuse or extract the existing bookmark recovery logic rather than creating a separate hydration implementation:
  1. fetch the complete post through `originAwarePostRepoProvider(config).getPost(postId)`,
  2. resolve a compatible post-data codec,
  3. upgrade the stored bookmark snapshot while preserving the local bookmark ID and all group memberships.
- A missing or ambiguous profile, missing post ID, unavailable repository or codec, removed upstream post, or individual request failure must not abort the complete batch. Count the affected bookmark as skipped or failed and continue with the remaining candidates.
- Respect existing site-specific rate limiting and request infrastructure. Do not launch thousands of requests through an unbounded `Future.wait()`; concurrency must remain small and controlled.
- If a site requires interactive verification or a CAPTCHA, the maintenance operation must not attempt to bypass it. The affected request may fail or be skipped while processing of unrelated bookmarks continues.
- Show visible progress while the operation is running, including at least `processed / total` and counts for successful, skipped, and failed bookmarks.
- The running operation must be cancellable. Successfully upgraded bookmarks remain persisted when the user cancels.
- Persist each successful snapshot upgrade as processing continues so that cancellation or an app restart loses as little completed work as possible.
- Do not reload or republish the complete `BookmarkLibraryState` after every individual bookmark. The batch path should write successful upgrades directly to the repository and refresh visible library state in batches or once after completion.
- Running the operation again must naturally resume remaining work: bookmarks that were already hydrated are skipped because they now contain native payload data.
- Keep the existing automatic single-bookmark recovery path when an incomplete bookmark is opened. The new maintenance operation is an optional manual optimization and must not become a prerequisite for correct bookmark behavior.
- After completion, show a compact result summary such as `Updated 1832 · Skipped 7 · Failed 3`.
- Localize all user-visible strings.
- Tests must cover at least:
  - candidate detection,
  - already complete snapshots,
  - successful hydration,
  - missing or ambiguous profile resolution,
  - removed upstream posts,
  - individual request failures,
  - resuming after a partially successful previous run,
  - cancellation,
  - preservation of bookmark IDs and group memberships.
- Add coverage proving that the batch does not reload the complete bookmark library after every successful individual upgrade.

## Context and dependencies

The existing single-bookmark recovery path currently lives in the bookmark details flow and uses:

1. `PostOriginResolver` for profile resolution,
2. `originAwarePostRepoProvider(config).getPost(...)` to load the complete post,
3. `BookmarkLibraryNotifier.upgradeBookmarkSnapshot(...)`,
4. `BookmarkLibraryService.upgradeBookmarkSnapshot(...)` for persistent snapshot replacement.

Batch hydration should use the same rules and must not introduce a competing second mechanism for bookmark snapshot upgrades.

`BookmarkLibraryNotifier.upgradeBookmarkSnapshot()` currently republishes the updated library state after a single upgrade. For a batch containing several thousand bookmarks, this method should not be called unchanged inside the inner processing loop. Introduce a batch-oriented service/notifier path that performs substantially fewer full library reloads.

Relevant documentation and code:

- [Repository task queue](../README.md)
- [Post architecture](../../post_architecture.md)
- [Bookmark group behavior](../../bookmark_groups.md)
- [Bookmark details recovery](../../../lib/core/bookmarks/src/pages/bookmark_details_page.dart)
- [Bookmark provider](../../../lib/core/bookmarks/src/providers/bookmark_provider.dart)
- [Bookmark library service](../../../lib/core/bookmarks/src/services/bookmark_library_service.dart)
- [Data & Storage settings](../../../lib/core/settings/src/pages/data_and_storage_page.dart)

Dependencies: None.

Preserve the existing bookmark, snapshot, profile-resolution, request, and rate-limit behavior.

Before implementation, follow the [development workflow](../../development_workflow.md) and [engineering guidelines](../../engineering_guidelines.md). This ticket is unclaimed; implementation requires its own branch/worktree and assigned implementer according to the repository queue rules.

## Decision

2026-10-06: The user chose a manual maintenance action instead of automatic background hydration for imported bookmarks. The action should be placed deep in Settings and explicitly hydrate all remaining incomplete bookmark snapshots. The primary use case is a one-time update of several thousand imported bookmarks. Normal viewer behavior and the existing on-demand bookmark recovery remain unchanged.