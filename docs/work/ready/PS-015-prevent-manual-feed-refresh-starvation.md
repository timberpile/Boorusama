# Prevent failing sources from monopolizing manual feed refresh

Priority: Normal
Affected feature: Following-feed refresh scheduling
Review severity: P2

## Problem and reproduction

`refreshFeed` sorts sources by successful checkpoint and attempts only the
first ten. Failures retain their old or null checkpoint, so the same failing
sources can consume every manual run and indefinitely exclude later sources.

1. Create a feed with at least eleven sources and disable automatic refresh
   to isolate manual behavior.
2. Make the first ten sources in refresh priority fail persistently.
3. Invoke manual feed refresh repeatedly.
4. The same ten sources are retried; later sources are never attempted.

Automatic refresh is not a reliable escape from this condition because it can
be disabled or unavailable on the current network or app lifecycle state.

## Expected behavior

Repeated bounded manual runs make progress across the feed despite individual
source failures, while preserving cached results and independent source status.

## Acceptance criteria

- [ ] Repeated manual runs eventually attempt every eligible source in a feed
  larger than one run's budget, even when earlier sources keep failing.
- [ ] Failed never-baselined and previously checked sources cannot monopolize
  subsequent runs.
- [ ] The per-run limit and shared concurrency gate remain enforced.
- [ ] Failures retain cached posts and successful checkpoints; partial freshness
  and errors remain visible.
- [ ] Deterministic regression coverage demonstrates progress without relying
  on automatic refresh or wall-clock delays.

## Context and review evidence

Reviewed `16b2e4b0f` and follow-ups through `2e5f4ead9` on 2026-09-19.
A temporary regression test created eleven persistently failing sources and
invoked manual refresh three times. It recorded thirty attempts but only ten
distinct queries, leaving the eleventh unattempted.

- [Manual feed refresh](../../../lib/core/search/subscriptions/src/providers/search_subscriptions_notifier.dart)
- [Refresh priority](../../../lib/core/search/subscriptions/src/types/search_refresh.dart)
- [Large-feed requirements](../done/PS-010-large-feed-incremental-refresh.md)
- [Subsystem documentation](../../pinned_searches.md)

## Dependencies

None. Follow the [development workflow](../../development_workflow.md) when
implementing. This ticket records the finding; no fix has been applied.
