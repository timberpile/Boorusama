# Issue #152 follow-up: Related bookmark responsiveness

Continues `0a3749010e7a` on `feature/152-bookmark-group-added-dates`.
User reported a roughly 100–200 ms UI stall while adding/removing Related bookmarks
on the combined UI test branch. That duration is user-reported, not a device
measurement performed here. Local delivery only; no push, PR, develop merge or
issue closure. The fix is also included in the combined local UI test branch.

## Confirmed mechanism and fix

Related membership writes repeatedly call `getGroup`/`getGroups`, including Pool
membership validation and publication. Every call decoded unchanged Hive groups,
including parsing every per-membership ISO timestamp. A controlled real-Hive host
experiment with 20,000 members measured five warm group reads at 173–239 ms with
dates versus 8–17 ms for legacy groups without dates. This is synchronous CPU work
on the UI isolate's storage path, not an awaited network delay.

Hive group records are now immutable, with defensive copies of membership/date
collections. The repository weakly associates one immutable domain snapshot with
each Hive row object. Unchanged reads reuse it; writes/external replacement/reopen
supply new row objects and decode current values. Weak keys allow replaced/deleted
rows to be collected. No persisted field/type/backup format change, artificial
delay, microsecond truncation or write deferral is introduced.

The same five-read experiment after the fix measured 0.05–0.24 ms for dated rows.
These are host microbenchmarks of this read segment, not end-to-end action or
Android frame timing. The actual device stall needs user rechecking.

An initial gallery-rebuild hypothesis/prototype did not resolve the strict
rebuild assertion and was discarded. No speculative gallery change or failing
assertion remains on #139 or the combined branch. The confirmed decoding
bottleneck is the implemented correction.

## Verification

- Five new structural/behavior regressions: unchanged snapshot reuse, affected
  writes with immutable prior snapshots, external replacement/deletion/recreation,
  Hive reopen and microsecond preservation, defensive immutable storage inputs.
- Before the fix, four of five new tests failed. After the fix, **72 focused tests
  passed** (new 5, membership dates 18, provider 49).
- `benchmark/related_bookmark_group_reads_test.dart` passed before/after, serially;
  three warmups and 10 samples per variant. Prints measurements without a strict
  wall-clock assertion. Opt-in benchmark is excluded from the normal full suite.
- FVM formatting and diff check passed. Final scoped analysis returned exit 0: 0 errors, 0 warnings, 3 existing infos.
  Full combined-run results are added after completion; earlier full passes
  predate this fix.
- No device operation, APK build/install or reset performed in this follow-up.

Durable commands/logs: `.worktrees/_artifacts/related-bookmark-responsiveness/`.
The prior #152 handoff's broad behavior/backup coverage remains applicable, while
performance evidence above supersedes repeated per-read parsing.

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
