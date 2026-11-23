# Issue #89 final local review

Reviewed input `57fd8790771f623f07da4b38a8dd232a23407215` against develop `422aeae087c1108e655d85d1a3dac25120456cd6`, the full implementation/tests, shared shell inset contract and additional engine destinations. The original Profiles test also searched for Flutter legacy ListTile instead of the actual Material UI type; corrected it.

The expanded audit reproduced additional defects, then fixed them through existing padding/SafeArea consumers:

- Donation's fixed Column overflowed by 64–968px in a 320x480 layout at text scales 1/2 and bottom insets 24/104. A scrollable SliverFillRemaining preserves centering when it fits and allows all actions to be reached otherwise.
- The final Artist search row ended at y630 with a navigation-safe boundary of y536. Its existing SliverPadding now consumes the inherited bottom inset.
- Explore's fixed navigation footer left the last action at y564 instead of at/before y536. It now uses the shell-provided inset while retaining its ordinary 20px visual spacing.
- Shared pool grids ended at y638 and user-detail content at y640. Pool grid padding now consumes the inherited bottom inset; the existing user-detail SafeArea now protects the bottom. Pool tests cover both an unconsumed inset and an outer SafeArea, requiring exactly one consumption.

No shell bar height was invented, no animated content-height policy was introduced, and stable content padding remains separate from #106's live popup obstruction. The original Profiles and Settings inset fixes remain.

Final verification on this commit's source/tests:

- FVM formatting of all changed Dart files: passed.
- `fvm flutter analyze --no-pub --no-fatal-infos` on all 12 affected Dart files, including new tests: no issues.
- Fourteen new layout regressions pass, including real Artist search, shared Explore/pool/user components, enlarged text, changing keyboard/system/navigation insets, and exact-once pool clearance.
- `fvm flutter test --no-pub --concurrency=6 --reporter expanded test/core/navigation test/core/settings test/core/posts/pools test/boorus test/pixiv_explore_test.dart`: 533 passed, no skipped/failed cases. An earlier command included nonexistent test/boorus/danbooru and failed discovery; the corrected complete scopes above passed. Earlier layout reproductions failed on actual geometry and are retained in the delivery logs.
- `git diff --check`: passed.

Remaining acceptance: exhaustive production engine/destination matrix with populated services, FAB geometry, real shell hide/show/viewer transitions and Android reordering. Host geometry tests cover concrete newly reproduced gaps but do not claim the full live/device matrix. #101 and #106 remain independent dependencies to reconcile only during approved integration. The final combined candidate still needs complete local regression. No integration, PR, issue closure or deletion is authorized.

## Accepted integration — 2026-10-29

The user accepted `bug/89-profile-navigation-insets` at `25b2d90b09362f6a3f1f2c8e84deb246c13394a4` and authorized merging. This supersedes the earlier pending-acceptance/no-authorization statements. Its complete patch is integrated by `6b2571a4c`, with the final combined runtime/test candidate checked at `f1357395e8d7c25b5de91e990531752a73c58ca9`. All 5,535 application tests, 1,608 package/CLI tests, both shell suites and 72 Python tests passed; two existing go_router skips remain. See [combined integration evidence](approved-issues-integration-2026-10-29.md) for the resumed package run, analyzer details, corrections, logs and device limits. The containing documentation commit records this accepted final state. Publication verification, issue closure and exact-tip branch cleanup follow under the user's approval.
