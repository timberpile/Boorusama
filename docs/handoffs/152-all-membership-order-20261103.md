# Issue #152 follow-up: Membership-derived All ordering and backup v9

Branch: `feature/152-bookmark-group-added-dates`, continuing the separately
committed responsiveness fix `4f489ddbe`. Both changes are included in local
`maintenance/ui-combined-test-20261103`. No push, PR, develop integration or
issue closure. The user accepted the remaining UI changes and explicitly chose
the semantics below during combined-branch review.

## Confirmed behavior

- All Bookmarks / Newest uses each item's latest current group membership date.
- All Bookmarks / Oldest uses its earliest current membership date. A different
  membership may therefore determine the two directions for the same item.
- Group views use that group's own date. Posts, Pools, Series, Collections and
  Related use the same policy. Previews match the full selectors.
- Removal excludes the deleted membership; Undo restores its original date;
  re-add supplies a new date. Duplication/repeats/metadata refresh retain dates.
- Dates are resolved once before sorting. The comparator does not scan groups
  repeatedly. Date-only membership changes refresh All; renaming does not. The
  existing viewer refresh gate still defers hidden-grid refreshes until Back.

This supersedes the initial #152 requirement that All retain the global creation
date. Earlier handoffs/checklist statements describing that policy are historical.

## Backup format

The user also explicitly chose to omit the old global bookmark date from new
backups. The writer now emits **version 9**, with dates only on memberships for
Posts and collection references. Post upload timestamps inside snapshots and
metadata freshness (`updatedAt`/`observedAt`) retain their independent meanings.

Readers accept **versions 4–9**. Legacy 4–8 global dates supply missing membership
dates when imported/re-exported. No migration-time timestamps are invented.
Legacy ungrouped Posts receive the same dated Default membership used by library
repair. V9 requires a date for every membership and rejects missing/invalid or
unassociated dates before import writes. Identity, source/profile references,
folder placement, microseconds and file-local ID remapping remain preserved.

For compatibility with existing local models/storage, v9 parsing projects the
earliest membership into their legacy `createdAt` property. That projection is
not written back into v9 backups and is not a sort source for dated memberships.
This change does not remove legacy local Hive fields. Import preview comparison
ignores that obsolete global property while still comparing actual membership
dates, avoiding false updates on an unchanged v9 round trip.

## Verification

- All-order focused selection/preview/refresh/membership suite: 145 passed.
- Complete Bookmark and backup scoped directories: 1,258 passed before adding the
  standalone v9 matrix. The new v9 matrix then passed 12 tests: output fields,
  directional round trips, no-op import preview, legacy-date injection, missing
  dates, orphan rejection/default export repair, and legacy 4/5/6/7/8 migration.
- The new All regressions failed against the old global-date policy before the
  fix. An obsolete All refresh expectation was updated to the confirmed policy.
  Legacy codec fixtures now explicitly build historical wire rows instead of
  mislabelling the current writer's output as an old version.
- Final direct All/v9/membership tests after review: 37 passed. FVM formatting
  and diff review passed. Final scoped analysis returned 0 errors, 0 warnings,
  31 infos (nonfatal-infos exit 0). Full combined results are recorded after
  completion; prior full passes predate this follow-up. No new combined APK or
  device test is claimed.

The first combined rerun exposed three viewer navigation fixtures still seeding
new membership time for every saved Post, plus Pool legacy dates without matching
membership dates. The fixture now explicitly seeds its historical membership
sequence; the existing viewport/neighbor assertions were retained. The complete
affected `test/application/pool_bookmark_flow_test.dart` passed 58 tests before
the fresh complete combined rerun. The interrupted failing run is not a pass.

A final boundary review also reproduced stale prepared-draft dates on the first
Default membership for Pool/Related. Unsaved draft memberships are now cleared
before assigning the actual write's date; existing stored memberships are kept.
Both new regressions failed before the fix; the final provider/All/membership/v9
run passed 88 tests afterward. The preceding combined attempt was stopped before
completion and is retained as interrupted evidence, not a pass.

Manual follow-up: recheck Related add/remove responsiveness on the user's device,
then the two All date directions and one v9 backup round trip. The exact changed
context-menu inventory was explained separately; no additional menu migration
was included in this follow-up.

Durable logs: `.worktrees/_artifacts/related-bookmark-responsiveness/`.

## Final combined verification

Checked combined candidate: `e1e04d8c0e7100136b82b682ea159a4edb5f0b0d`.
Includes source implementation commits `4f489ddbe` (snapshot reuse), `0c957c6a5`
(All membership semantics / v9), `eac45595e` (chronological fixtures) and
`c4e395c07` (first Default membership at save time). Subsequent edits are handoff
records only; runtime/tests/dependencies/generated runtime output are unchanged.

- FVM formatting of all changed Dart paths passed with no changes.
- Combined affected-scope analysis: 0 errors, 0 warnings, 122 infos; exit 0 with
  nonfatal infos.
- `./scripts/run_regression_tests.sh`, detected physical concurrency 6: **6,161 app
  tests + 1,661 package/CLI tests across 13 complete suites  + both shell suites
   + 76 Python tests; REGRESSION_EXIT=0**. Complete Kurumi package 188 passed.
  Two pre-existing go_router skips; none added.
- Earlier fixture-failing/interrupted combined attempts are retained separately,
  not counted as passes. The final result is one complete uninterrupted pass.
  Existing native-hook/finalizer/locale/hit-target diagnostics remain distinguishable
  from the explicit final pass.
- Source #152 targeted checks and the complete combined run are distinct; a new
  standalone develop integration candidate still needs its own complete gate.
- No new device operation, APK build/install, data reset, push, PR or develop
  merge. Device frame behavior and the user-facing v9 round trip remain manual.

Durable full provenance/log: `.worktrees/_artifacts/related-bookmark-responsiveness/combined-verification.log`.
