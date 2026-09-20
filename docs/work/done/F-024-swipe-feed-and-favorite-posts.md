# Swipe through feed and favorite posts

Priority: High
Affected feature: Following Feeds and Gelbooru V2 favorites / `feature/17-following-feeds`
Agent/session: Codex `/root`, 2026-09-20
Work branch: `feature/17-following-feeds`

## Problem

Feed thumbnails and HTML-backed Gelbooru V2 favorites open the single-post
route. It fetches one full post, builds a one-item viewer, and displays
"Single post mode, swiping is disabled". Both grids already have an ordered
post list, so browsing stops unnecessarily after each post.

## Expected behavior

Opening either grid preserves its post order and selected position. Users can
swipe to adjacent posts. Full engine-specific post data loads on demand, and
reaching the end of the loaded list continues its existing pagination. Missing
posts show an error without preventing navigation to other posts.

## Acceptance criteria

- [x] Feed posts can be swiped in feed order without prefetching every detail.
- [x] HTML-backed Gelbooru V2 favorites can be swiped in favorites order.
- [x] The single-post warning is absent from those collection viewers.
- [x] More posts can be loaded while browsing near the end.
- [x] Focused tests and Android Maestro verify swiping.

## Context

Both entry points currently call `goToSinglePostDetailsPage`. Cached feed
posts have thumbnail and identity data, but native details must be fetched by
the owning engine. Preserve the existing single-post route for contexts that
really contain only one post.

## Dependencies

None. Follow [development workflow](../../development_workflow.md).

## Completion evidence

- 2026-09-20: Feed and HTML favorites now pass their grid controllers to the
  same lazy details route. The route keeps their ordered IDs, fetches native
  post details only for visited pages, and requests another grid page near
  the end. The Gelbooru V2 thumbnail-only builder accepts already fetched
  native posts from this route.
- Four pager widget tests cover selected position, adjacent swipes, more-page
  loading, recovery after a failed page, and bounded building for 1,000 IDs.
  Related feed and viewer tests passed (17 total); full `fvm flutter test
  --no-pub` passed 1,172 tests. `fvm dart analyze` found no issues.
- Maestro on Android opened a cached post in Shigatake test and swiped to a
  visibly different adjacent post. The warning icon was absent. The emulator
  lacks an authenticated Gelbooru V2 HTML favorites profile, so that specific
  entry point was verified by its call path and the shared pager tests.
