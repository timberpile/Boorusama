# POST-006: Refresh Danbooru creator preloading while swiping

Priority: High

Affected feature or branch: `feature/bookmark-post-behavior-parity`

Agent/session: Codex `/root`, 2026-09-23

Work branch: `feature/bookmark-post-behavior-parity`

Dependencies: POST-001 unified post model and mixed-booru presentation

## Problem

The mixed viewer reuses the Danbooru creator-preloader state for consecutive
Danbooru posts, but the loader only fetches IDs during `initState`.

## Expected behavior

Changing to another Danbooru post or profile loads its uploader and approver
without stale creator state.

## Acceptance criteria

- Two consecutive Danbooru posts with distinct creator IDs trigger both loads.
- Existing creator caching remains effective.
- Focused mixed-viewer tests pass.

## Completion evidence

- The preloader reloads when its post preloadable changes while retaining the
  existing creator notifier cache.
- A widget regression test confirms distinct uploader and approver IDs are
  requested for consecutive Danbooru posts without refetching an equivalent
  uploader/approver set after a parent rebuild.
- Empty creator requests return before reaching the repository.
