# Keep newest-post refresh bounded per search

Priority: High
Affected feature: Pinned searches
Reported on branch: `fix/rule34-pinned-search-tracking`

## Problem

Fetching newest posts per search takes much longer when more posts have been
added since the previous check. The user expects O(1) work per search with
respect to the number of newly added posts.

The current `ChronologicalSearchScanner.scanForNewPosts` fetches successive
pages until the old checkpoint's overlap boundary or exhaustion. It collects
new-post candidates for exact unread counting. Work therefore grows with the
number of posts scanned; network pagination is part of the cost, not merely
calculating a count in memory. Baseline fetching already uses one page.

## Expected behavior

Refreshing latest posts and previews has a bounded request and processing
budget per search, independent of the number of new matching posts. Exact
new-post counts are not required and must not force a full scan. Refresh All
still scales with the number of searches. O(1) describes bounded client work,
not a guarantee about server or network latency.

## Confirmed indicator scope

Replace numeric new-post counts with a simple NEW indicator in the MVP unless
an exact-count mechanism can be verified to use O(1) client work and requests
per search with respect to the number of new posts. NEW is the default; do not
retain exhaustive pagination to calculate a count. A server-provided count may
qualify only if its semantics match newly uploaded matching posts and its
availability is verified for the integration. Do not assume a total-result count
or a difference between totals measures new uploads correctly.

NEW means at least one matching post was uploaded after the relevant checkpoint;
old posts whose metadata changes must not trigger it. The first successful
snapshot establishes a baseline without NEW. Opening a pinned search clears
its known NEW state. Preserve these semantics with a bounded fetch; document
any engine-specific capability limitations rather than silently claiming
complete chronological coverage.

## Acceptance criteria

- [ ] Latest-post refresh has a fixed per-search request and result budget when
  there are few or many posts uploaded since the previous check.
- [ ] No exact-count requirement triggers scanning every new matching post.
- [ ] Numeric new-post counts are replaced with NEW unless a verified exact
  count mechanism satisfies the bounded-work requirement for that integration.
- [ ] Baseline refresh does not set NEW; newly uploaded matching posts do;
  metadata changes to old posts do not. Opening a pin clears known NEW state.
- [ ] Search-item and navigation indicators are reconciled with the change;
  they do not present stale numeric unread counts as exact new-post totals.
- [ ] Failed refreshes preserve usable cached previews.
- [ ] Updated tests and subsystem documentation reflect the revised scope;
  a bounded fetch is not presented as a completed exhaustive scan.

## Relevant context

- `lib/core/search/subscriptions/src/refresh/chronological_search_scanner.dart`
- `lib/core/search/subscriptions/src/services/search_refresh_service.dart`
- `lib/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart`
- [Subsystem documentation](../../pinned_searches.md)
- Existing count/checkpoint requirements in the approved design and plan must
  be reconciled with this newer user request.

## Completion evidence

Record verification here when resolved.
