# Preserve distinct same-named feeds during backup restore

Priority: High
Affected feature: Following-feed backup and restore
Review severity: P1

## Problem and reproduction

Feed creation permits multiple feeds with the same name in one profile, but
restore treats a matching case-insensitive name as an existing feed regardless
of its ID or source queries. A valid backup therefore loses distinct feeds.

1. Create two feeds named `Animals` in one profile, with sources `cat` and
   `dog` respectively.
2. Export the pinned-search backup and restore it into an empty matching profile.
3. Only the first feed and its sources are restored; the second is counted as
   already existing.

## Expected behavior

Restore preserves distinct feed definitions even when their display names
match. Reimporting the same definitions remains idempotent.

## Acceptance criteria

- [x] A backup round trip preserves both same-named feeds, their IDs, and their
  respective source queries, including names differing only in case.
- [x] Repeated import does not duplicate either feed or its hidden sources.
- [x] Existing profile mapping and cross-profile ID collision handling remain
  correct, without overwriting unrelated local feeds.
- [x] Observable regression coverage includes the same-name round trip and
  repeated import.

## Context and review evidence

Reviewed `16b2e4b0f` and follow-ups through `2e5f4ead9` on 2026-09-19.
A temporary regression test expected two restored feeds and observed one.
The existing 242 related tests passed without covering this case.

- [Import deduplication](../../../lib/core/backups/sources/pinned_search_import_service.dart)
- [Feed creation](../../../lib/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart)
- [Subsystem documentation](../../pinned_searches.md)

## Dependencies

None. Follow the [development workflow](../../development_workflow.md) when
implementing. Resolved on `feature/17-following-feeds` on 2026-09-20. Import
matches feed IDs and handles cross-profile ID collisions without dropping a
definition. The 24 import-service tests, including same-name and repeated
import coverage, passed.
