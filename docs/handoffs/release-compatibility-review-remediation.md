# Release compatibility — review and remaining remediation

Date: 2026-11-20. Continue `maintenance/release-compatibility-policy`.
Reviewed HEAD: `989dd246faf93ddfbcb5d4769a440266276e05a2`.
Reviewed runtime: `c8cfc5ad0c11bed1d0a3402dc3fa7b78e5a8cb72`.
Comparison base: `d9203ae62dcbc5ff81e0bd70702607fb24070787`.
Published producer: `v4.6.1-timberpile.3`,
`422aeae087c1108e655d85d1a3dac25120456cd6`.

**Verdict: changes requested before integration.** The consolidated schemas,
explicit journal operations, ownership initialization and final-format validation
are coherent in the inspected code. The remaining blocking case is recovery of
an interrupted import from the released installation, not another schema bump.
This review inspected the branch delta, relevant production consumers, fixture
drivers, new upgrade tests, audit tooling and the verification report. It did not
execute Dart/Flutter, recapture released fixtures, verify all binary checksums,
run the full repository suite or operate Android. The runtime finding below is
source-backed and still needs its failing-before/passing-after Flutter test.

## R1 — P1: released rollback can be blocked by migration before restoration

### Evidence and reachable state

In the **published** `lib/core/backups/sources/bookmark_import_service.dart`,
`_rollback()` removes extra imported Post rows before it restores memberships of
pre-existing Groups. The published Hive repository's `removeBookmarks()` only
deletes Post rows; it does not detach Group memberships. Thus a process death
inside that rollback can leave an existing Group pointing at a just-deleted
imported row, while the outer import transaction still has its valid original
rollback snapshot and journal.

Use these exact producer paths at the published SHA above; this is not a
request to support an obsolete development-only Bookmark format.

In the candidate:

- `lib/core/backups/export_import/import/import_recovery_gate.dart` constructs
  `PackageTransactionSource` wrappers and runs `ImportRecoveryService`.
- `import_transaction.dart::rollback()` verifies the rollback payload hash, then
  calls `source.restore(path)`.
- `import_flow_notifier.dart::PackageTransactionSource.restore()` reaches
  `_applyBookmarks()`. That method awaits the normal Bookmark repositories,
  including the organization repository, **before** applying the old snapshot.
- `lib/core/bookmarks/src/services/bookmark_storage_migration.dart::_prepare()`
  rejects the dirty released Group with `Legacy Group references an absent Post`.
  The normal organization factory cannot finish, so the valid preimage is never
  restored. Retrying the recovery gate repeats the same ordering problem.

The new test `released rollback restores rows deleted before the upgrade`
opens a **fresh candidate repository** before calling `restore()`. It proves
v4/v5 payload restoration with missing old IDs, not recovery from this partially
written released installation.

### Required reproduction

Extend the released-writer harness or a focused old-checkout fault driver:

1. Start with an existing Group A and saved Post a. Capture the actual released
   transaction's private rollback payload and journal.
2. Import a new Post b into the existing Group A; force a later operation to fail.
3. Stop the released rollback after its extra Post b has been deleted but before
   A's original memberships have been restored. Preserve the closed raw Hive
   files and pending outer import journal. Do not repair them in the fixture.
4. Boot the candidate through `ImportRecoveryService`/the production provider
   boundary on that directory. First show that migration prevents recovery.
5. After the fix, assert the pre-import content, profile hints and Group graph,
   successful recovery completion, one final organization activation, and two
   cold reopens. Keep the original files until recovery is durably committed.

A small hand-seeded malformed-state test is useful for diagnosis, but retain
old-writer provenance for the release-upgrade regression.

### Fix direction and constraints

Order **verified released import recovery before normal hierarchy activation**,
or add a narrowly scoped recovery bootstrap that stages the validated private
preimage without requiring the inconsistent live organization to pass normal
migration first. Use the existing transaction coordinator, journal verification
and durability boundaries. Do not route ordinary external imports through that
privileged path. Do not weaken the missing-member check, synthesize empty groups,
clear the import journal on failure, reset the database, or trust external local
IDs. Preserve allocator monotonicity and the current mirror ownership rules.

Cover both a valid pending old transaction and the same malformed store without
an authentic pending recovery: the latter must remain rejected with files
preserved. Also cover corrupt rollback hashes, interruption during recovery,
repeated recovery, and an already-final healthy candidate repository. If the
actual production initialization order disproves this scenario, supply that
counterexample test and the exact source path rather than applying a speculative
workaround.

## R2 — P2 verification follow-up: full released-package transaction

`test/core/backups/released_auxiliary_upgrade_test.dart` verifies raw repository
cold opens, stages the nine-domain package, directly applies Following/Feed
imports, and initializes SQLite against staged database paths. Together with
`released_bookmark_upgrade_test.dart`, this is useful coverage, but it is not
an end-to-end application of all nine sources through the package transaction,
profile dependency planning, rollback and destination durability boundaries.
The reported separate nine-domain snapshot comparison does not replace that
entry-point test. This is a coverage gap, **not a second demonstrated data-loss
bug**.

Add one headless production `ImportFlowNotifier`/`ImportTransaction` scenario
using the checked-in released `.bsexport`: import into an isolated destination,
verify all selected domains and profile relationships in destination repositories,
then cold-open twice. Add a fault after an earlier source has committed and check
rollback of the whole selected transaction. Assert real records and relationships,
not only source counts. Reuse the existing fixtures; do not invent another metadata
framework or require network credentials. Where normalization intentionally remaps
file-local IDs, assert the mapping and relationships explicitly.

## Trivial issues fixed by this review — retain these changes

### T1: source audit accepted a reader unable to read its current writer

`scripts/audit_schema_versions.py::audit_contracts()` formerly accepted any
reader subset of `released readers union current writer` that retained the old
readers. Writer 6 with readers only 4/5 therefore passed. Readers now must match
the required union. The actual Bookmark shared-symbol locator already provided
additional protection; this fixes the general numeric-reader contract rather
than claiming current Bookmark v6 imports were broken.

`test_schema_reader_roundtrip.py` adds six tests, including a real temporary-Git
CLI failure case. Two failed on the exact original helper and all six pass after
the change. No schema ceiling or current contract version was changed.

### T2: capture script silently skipped unfinished output

`scripts/fixtures/capture_released_bookmarks.sh` formerly skipped any tag when
`bookmarks.json` existed, even an empty file without closed Hive storage. Six
empty files made the command return success without running a writer. It now
preflights all six output locations and refuses existing captures before switching
tags or writing anything. Use a new output directory after failure; old artifacts
are preserved for diagnosis. This does not invalidate already captured fixtures
or establish that any checked-in fixture was incomplete.

`test_released_fixture_capture.py` adds two admission tests using only temporary
Git repositories, with no Flutter or device. Both failed before and pass after.
The fixture README also creates the artifacts parent before `realpath` and
explains fresh-output behavior. Release validation runs both new test files.

## Review verification and local completion

The source copies used for the tests were verified against Git blob IDs before
editing: audit `9a68dc805d7db381e9353da5fadc0f030f9e6e37`, capture script
`3ea20f2254af25e6f3ee2487e9e7cb0b690be711`. Eight new Python tests passed after the
fixes, plus Python compilation, capture-shell syntax and scoped diff checks.
These are tooling results only; the original full-suite numbers remain the
implementation agent's reported results, not independently rerun results.

Continue in this order:

1. Fetch the branch, preserve concurrent work, and read current AGENTS/workflow.
   Do not repeat or revert the already committed tooling fixes.
2. Reproduce and resolve R1; add the R2 entry-point coverage. Keep the agreed
   versions: Bookmark export 6, organization 2, repository/journal 1, MiteMite
   protocol 1 with Bookmark 6 and Following 2, Listed payload 1. No new bump is
   necessary for these pre-release corrections.
3. Run all Python tooling tests (including the two new files), schema audit with
   inventory, the released-fixture and affected import/recovery/journal suites,
   then the complete regression runner on the final runtime candidate. Analyze
   and format changed Dart. Record exact tested SHA, commands, failures/skips and
   fixture provenance. Do not reuse the prior runtime pass after a runtime fix.
4. Keep the existing native acceptance items explicit: signed real-release APK
   upgrade, first/cold launch, App Lock/secure storage, SAF/backup recovery, and
   notification permission/tap delivery. Use only an authorized disposable test
   installation and the required device lease. Missing device access is pending
   evidence, not a passing test or permission to alter the owner's installation.
5. Commit and push the task branch and update the verification report with the
   actual new evidence. Preserve historical results with their original SHAs.

**No merge into develop/master, PR, issue closure, release, force-push, data reset
or branch/worktree removal is authorized.**
