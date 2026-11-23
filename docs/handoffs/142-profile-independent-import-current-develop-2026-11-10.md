# P5 profile-independent import: current-develop qualification — 2026-11-10

Historical qualification of `4695c0794`. Later feedback, owner acceptance,
authorized integration and the final complete gate are recorded in the follow-up
linked below; the earlier acceptance/publication limits are superseded there.

Owner feedback and the newer candidate are recorded in the
[import dialog follow-up](142-import-dialog-feedback-2026-11-10.md). Evidence below
applies to the earlier runtime candidate identified here.

## Candidate and scope

Branch: `feature/142-profile-independent-import-package`.
Runtime/test candidate: `4695c0794c8c51b9c4351b525041a86394a1369a`.
Checked tree: `fce9e7de0ccc70ef1c35b9597b6bfb96863af275`.
Accepted P4/develop parent: `42dbdb6afe6066d54ecfdcb70543031c12ca2585`.
This report and the accompanying documentation changes do not change runtime or
tests. The original prepared P5 delta was replayed onto accepted P4, preserving
its picker, search focus, navigation, recursive duplication and thumbnail fixes.
The only substantive rebase conflict combined P4's source-aware PostGridImage/GIF
renderer with P5's matching-profile availability guard.

P5 imports and retains unavailable Post/Pool/Related records and hierarchy,
keeps optional Bookmark hints separate from required Topic dependencies, and
restores exact local rollback slots through private recovery. Profile changes
recompute availability and immediately revoke stale media actions. Public or
anonymous readers, offline-access expansion and native Group activation remain
P6/P7; they are not part of this candidate.

## Additional native-discovered self-Replace correction

The earlier 3,201-record absent-hint fix remains covered. Native verification
on predecessor `6aca00be7` found an additional case: a freshly generated
Bookmark-only export of a controlled 107-record library showed two added and two
removed membership occurrences. One unaddressable legacy Post was given a fresh
local ID during Replace, changing both of its group memberships. The earlier
opaque-record no-op limitation did not satisfy the self-copy requirement.

Full category Replace now matches unaddressable records only by their complete
transfer payload (excluding file ID) plus group UUID/UTC membership-date incidence.
One-to-one multiset queues retain existing IDs and local-only fields without
inventing an identity or trusting file IDs. Merge, Copy and per-group updates
keep fresh-record semantics. Real payload/source/date changes remain visible.
Preview mapping and actual preparation share the same exact matcher; no counts
are suppressed. Matching is linear in payload/edge size plus deterministic local
opaque-ID and per-record membership sorting, without pairwise library scans.

A real-Hive regression failed before correction. Final focused import/recovery
checks passed 43 tests, including cardinality 2-to-2/2-to-3/3-to-2, reordered and
colliding file IDs, identical portable payloads with different local fields,
real edits, and unchanged Merge/Copy behavior. All 19 self-Replace cases pass.
The actual Android Hive archive and its native-created export also replay to
zero preview rows/created/updated/deleted and preserve all 107 complete stored
records, local IDs and exact groups through actual host Replace.

## Final automated and independent verification

`./scripts/run_regression_tests.sh` on exact `4695c0794` exited zero using six
physical cores: **6,643 application tests**, **1,677 package/CLI tests across all
13 roots**, **both repository shell suites**, and **76 Python tests** passed.
Two existing package test skips remain; no complete root was skipped.
`fvm flutter analyze --no-pub --no-fatal-infos` on the complete affected Dart scope
exited zero: zero errors, zero warnings and 70 informational findings. Changed
Dart files were formatted with FVM. Localization inputs remain identical to the
already initialized P5 worktree; no new generation was required.

Independent actual GPT-6.1 Sol, High effort: **APPROVE SOURCE**, with final exact
candidate, full-run counts/exit, corrected native evidence and restoration
independently reconciled. The earlier predecessor approval and full pass are
historical, superseded by the native finding; final results apply to `4695c0794`.
Failed draft compile/fixture runs are retained as failed or interrupted evidence,
including an interrupted compile runner that handled SIGTERM with exit zero;
that marker is explicitly not a pass. Use only the final logs named below.

## Android evidence and restoration

Only internal normal-main dev-debug builds were made for automated verification;
no user review APK is delivered. Installed APK hashes match their source-build
provenance. The original emulator APK/data/settings were backed up and parked
before either controlled campaign, under an exclusive `emulator-5554` lease.

On predecessor `6aca00be7`, real native file selection/import retained three
unavailable Post/Pool records, shared membership dates, and parent/nested/empty
groups, with reachable controls at 320dp and 2x text. `booru_configs.hive` remained
byte-identical. The new correction changes only category Replace correspondence.

On final `4695c0794`, the same controlled library/export shows **0 added, 0 removed,
0 changed** and **Nothing to import** through the real Android picker and Replace
UI. Maestro asserts those results and verifies the imported hierarchy after a
cold restart. Six record/group/profile Hive files remain byte-identical after
preview/restart. Native Apply is not claimed for a zero-change preview: the UI
correctly offers Done; actual no-op Apply is covered by the captured-data host replay.

Both restoration campaigns passed: all **1,108** original private filesystem
entries match in bytes/types/modes, original APK and all 31 normalized permission
lines match, display/settings/stopped state match. Only task-owned test containers
and staged files were removed, and both leases were released.

A full private export was cancelled after automatic approval review rejected its
credential-bearing scope. The successful self-test used a custom Bookmark-only
package whose manifest was checked to contain no profiles or credentials.

## Manual acceptance still required

Use a recovery copy of the personal library; synthetic-device evidence does not
establish acceptance of the owner's current data or authenticated live services.

1. Export the current Bookmarks and review that same copy with category Replace:
   expect zero genuine changes, including legacy/unaddressable records.
2. Import a copied file without matching profiles: retain records, hierarchy,
   snapshots and membership dates, without creating/removing/binding profiles.
3. Add an existing compatible profile or exercise profile changes: records become
   available without duplicates, while unavailable media is omitted from ordinary
   grids/covers. Test mixed-source and legacy files and restart persistence.

Integration approval remains separate after this acceptance. P6/P7 are still
separate preparation/reference work, not qualified for integration here.

Durable local evidence: `.worktrees/_artifacts/p5-current-develop-20261110/`:
`regression-final.log/.exit`, `regression-final-result.json`, `final-candidate.txt`,
`analysis-opaque.log/.exit`, `opaque-targeted-final.log/.exit`,
`sol-high-source-review.md`, `native/replay.log/.exit`, and `native-final/`.
