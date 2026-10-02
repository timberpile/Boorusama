# Persist pinned-search sorting

- Priority: Normal
- Affected feature/branch: Pinned Searches / `feature/persist-pinned-search-sort`
- Agent/session: `/root/implement_24`, `/root/update_24_persist_updates` / assigned worktree
- Problem: The selected pinned-search sort currently resets when its provider or the app is recreated.
- Expected behavior: Persist the selected sort and restore it after provider/app recreation.
- Acceptance criteria:
  - Every final `PinnedSearchSort` value persists and restores.
  - Missing or unknown legacy values safely default to Manual order.
  - The selected sort is restored after provider/container recreation.
  - Persistence uses the existing settings/preferences storage without introducing a second incompatible migration.
- Relevant context: Work is based on reviewed Task 23 head `857b578e3`; preserve the manual Notifier provider and use the existing settings persistence patterns.
- Dependencies: Reviewed Task 23 branch head `857b578e3` is present.

## Progress

- Claimed in `.worktrees/ready-24-persist-sort` on `feature/persist-pinned-search-sort`.
- Added persistence coverage first. The first Flutter attempt exposed missing generated files in this fresh worktree; `./gen.sh` generated the required sources. The next run failed to compile because Settings lacked the new field and the provider selection was not awaitable.
- Added `pinnedSearchSort` to the existing Settings JSON/Hive record, with unknown and missing values normalized to Manual order. The manually declared Notifier restores from Settings and saves each selected enum name.
- The original implementation passed a full `fvm flutter test --no-pub` run (1,494 tests) before Task 23 changed its sort options. This does not validate the rebased result.
- Rebased the two commits onto the reviewed Task 23 head. Focused tests first failed because `updatesFirst` loaded as Manual order; updating Settings and sort parsing made all 10 persistence and sorter tests pass.
- After regeneration, the final focused persistence, sorter, and pinned-search page test run passed 49 tests. Analysis of the four affected Dart files reported no issues. The full suite is pending the parent agent's serialized gate.
- Independent review found that failed saves left an unsaved sort visible and rapid selections wrote concurrently. The sort notifier now reads visible state from saved Settings and serializes selections; rejected and throwing saves return false. RED→GREEN tests cover both failure modes, rapid selections, and a newer choice after a failed save. Focused sort/page tests passed 53 cases, and 58 other tests sharing the adjusted widget harness passed. Changed-file analysis reported no issues, independent re-review approved the fix, and the final serial full suite passed all 1,498 tests.

## Completion evidence

- Settings serialization round-trips all three final sort values; absent and unknown values resolve to Manual order.
- A container recreating the sort provider from the saved Settings JSON restores each of the three sort values.
- The settings store reuses its existing JSON record and requires no separate migration.
