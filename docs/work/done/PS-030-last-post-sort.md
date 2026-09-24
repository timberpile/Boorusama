# Show and sort pinned searches by the last matching post

Priority: Normal
Affected feature: Pinned Searches

## Problem

Pinned-search cards show previews and NEW status, but users cannot quickly tell
when each search last matched an uploaded post. Searches can only be viewed in
their manual order, making inactive or recently active searches difficult to
identify.

## Expected behavior

- Each card shows `Last post: <relative time>` for its newest cached matching
  post without adding a separate metadata row.
- Never-checked searches show `Last post: Not checked`; successfully checked
  searches with no matches show `Last post: No posts`.
- A failed refresh retains any cached timestamp and continues to show its error.
- The Pinned Searches page offers Manual order, Last post: newest first, and
  Last post: oldest first.
- Date sorting is a session-scoped, non-destructive view shared by Home and
  folder pages. It resets to Manual order when the app restarts.
- Searches without a timestamp follow dated searches in both date orders.
  Manual order breaks ties.
- Folder rows keep their manual order. Following Feeds are unaffected.

## Acceptance criteria

- [x] Last-post text shares the existing profile-caption line and does not
  increase normal card height.
- [x] Long profile captions truncate before the last-post text.
- [x] Manual, newest-first, and oldest-first ordering behave as specified in
  Home and folders.
- [x] Switching back to Manual order restores the saved organization order.
- [x] Move Up and Move Down are unavailable during date sorting.
- [x] Sorting and rendering use cached state and do not trigger network work.
- [x] Relevant unit and widget tests pass.
- [x] Android UI behavior is validated with Maestro.

## Relevant context

- `docs/pinned_searches.md`
- `lib/core/search/subscriptions/src/pages/pinned_searches_page.dart`
- `lib/core/search/subscriptions/src/providers/search_subscription_selectors.dart`
- `lib/core/search/subscriptions/src/widgets/pinned_search_card.dart`

## Work

Agent: Codex (`/root`)
Branch: `feature/ps-030-last-post-sort`

Baseline: `fvm flutter test` passed 1,295 tests before implementation.

Implemented cached last-post labels, session-scoped manual/newest/oldest views,
stable missing/tie ordering, shared Home/folder selection, and disabled manual
move actions in date views.

## Completion evidence

- `./gen.sh` completed successfully.
- Focused selector and page coverage passed 39 tests, including live relative
  time updates, enlarged-text overflow protection, and cached timestamps beside
  refresh errors.
- `fvm flutter analyze` completed with no issues.
- The final full `fvm flutter test --concurrency=2` run passed all 1,307 tests.
  An earlier parallel run's unrelated bulk-download session failure passed in
  isolation before a clean rerun.
- Maestro on `emulator-5564` confirmed all three sort choices, a fetched
  relative value (`Last post: 12 minutes ago`) on the profile-caption line,
  dated-before-undated ordering, disabled move actions in a date view, and
  restoration of the manually moved order after returning to Manual order.
- Independent review findings for stale relative labels and enlarged-text row
  overflow were reproduced with failing tests and fixed before handoff.
- The final independent follow-up review reported no Critical or Important
  issues and marked the branch ready to merge.
