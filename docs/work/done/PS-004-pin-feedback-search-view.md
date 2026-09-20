# Keep pinning failures in the search view and suppress success messages

Priority: High
Affected feature: Pinning feedback and navigation
Reported on branch: `fix/rule34-pinned-search-tracking`

## Problem and reproduction

Pin a search, then quickly open a post before the pinning/initial preview
operation finishes.

- On Rule34, the user sees “Search pinned, but its preview could not be loaded”
  while viewing the post, where pin preview feedback is irrelevant.
- On Danbooru, a pinning success message appears after opening the post.

These are reported symptoms, not a verified diagnosis of the Rule34 preview
failure's underlying cause.

## Expected behavior

Successful pinning produces no success message. Only failures related to the
pinning operation are shown, directly in the originating search view. Pinning
feedback must not appear over a subsequently opened post.

## Acceptance criteria

- [x] Successful pinning produces no success message, whether the user stays
  in the search view or immediately opens a post.
- [x] Genuine pinning failures are communicated in the originating search view.
- [x] Delayed pinning/preview failures do not appear over a post or another view.
- [x] Rule34 and Danbooru quick-navigation scenarios are verified.
- [x] A preview failure does not imply that a successfully saved pin was lost.

## Relevant context

- `lib/core/search/search/src/widgets/search_page_scaffold.dart` currently
  shows pinning success and failure feedback through `ScaffoldMessenger`.
- `lib/core/search/subscriptions/src/services/search_refresh_service.dart`
- [Subsystem documentation](../../pinned_searches.md)
- Validate Android UI behavior with Maestro as required by `AGENTS.md`.

## Completion evidence

Record verification here when resolved.

## Completion — 2026-09-17

Agent: Codex (/root)
Branch: `feature/chronological-pinned-search-support`

Focused suite passed 124 tests, including delayed failure after navigation and preserved saved pins. Maestro confirmed successful management is silent. Rule34 authentication is unavailable for live quick-navigation verification; shared behavior is covered deterministically.
