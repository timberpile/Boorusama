# Release compatibility preparation — local continuation

Date: 2026-11-18. Branch: `maintenance/release-compatibility-policy`.
Base: `a9ce9de09e4a9d8c994c24804d7c65ef8cefe270`.
Public fixture baseline: `v4.6.1-timberpile.3` /
`422aeae087c1108e655d85d1a3dac25120456cd6` (verify live release before capture).

## Prepared on this branch

- [Source audit](../release_compatibility_audit_2026-11-18.md): registered persistent
  domains, actual tagged Bookmark writers, shipped/unreleased distinctions and
  the existing upgrade test's limits.
- [Policy](../release_compatibility.md): evidence-based compatibility obligations;
  no production migration just for an unreleased intermediate; no public-data
  reset/retirement without an explicit decision. AGENTS and implementation/release
  skills now reference it.
- [Local upgrade procedure](../testing/released_upgrade_verification.md): genuine
  old-writer fixtures, production upgrade/import, cold reopen, native acceptance,
  provenance and record-level assertions.
- `scripts/compare_upgrade_snapshots.py`: strict, bounded, read-only comparison of
  complete expected/first-start/cold-reopen logical state. It is **not** a fixture
  generator or a migration runner. No actual released fixture is included.
- `.github/scripts/verify-android-upgrade.sh`: unchanged installer/version checks,
  with an explicit installation-only label. No release workflow was dispatched.

No application storage code, public decoder, protocol payload, release version,
existing user data or #166 feature behavior is changed. No compatibility branch
has been deleted. No PR or release is created. Develop/master are not modified by
this work.

## Verification actually performed remotely

Only a source-backed isolated tooling copy was available, not a complete runnable
Flutter checkout. Python 3.13 executed:

```bash
python3 -m unittest discover -s scripts/tests -p test_compare_upgrade_snapshots.py -v
python3 -m unittest discover -s scripts/tests -p test_installer_smoke_scope.py -v
bash -n .github/scripts/verify-android-upgrade.sh
```

28 comparison tests and one smoke-label test pass (29 total). Initial tests failed
before implementation: missing comparison helper; smoke success output omitted
the data-verification disclaimer. Tests cover missing/extra records, equal counts
with wrong IDs, ordering, JSON type differences, missing domains, duplicate keys,
non-finite numbers, invalid encoding, bounded input/depth/output, first-start vs
cold-reopen failure and CLI exit codes. The shell test uses fake `adb` and
`apkanalyzer`; **no Android command reaches a device**. The tests' generated
snapshots are explicitly synthetic, not released-data fixture evidence.

Not run: Flutter/Dart tests, existing full repository tooling suite, APK build,
actual Hive/SQLite migrations, real released exports, native upgrade or device
acceptance. FVM/Flutter/Dart/ADB were absent; direct git network access failed DNS.
Source reads/writes used GitHub. There is **no full-suite or release-ready claim**.
Before integration run the full repository suite in the actual task worktree.

## Continue in this order

1. Fetch origin and inspect this branch plus current develop. Preserve concurrent
   work; use an isolated worktree. Read AGENTS, the policy and upgrade procedure.
2. Capture **real** v4 and v5 exports through the released writers (v4 examples:
   `v4.5.0-timberpile.3/.4`; v5: `.5` and `v4.6.1-timberpile.1/.2/.3`). Capture
   populated latest-release local storage separately. Document the old writer
   commit, synthetic fixture driver/command and raw hashes. Do not generate a
   candidate payload and relabel its schema as old.
3. Add production repository/import tests for that data and a cold restart. Keep
   the fault-injected journal tests. Cover all nine exported domains, plus native
   security/permission state separately where affected. Establish independently
   reviewed expected logical state before running the candidate migration.
4. Use the helper to compare full observations as an additional check, not a
   replacement for domain-specific assertions/provenance. Persist no real user
   dumps, credentials, session cookies, device keys or signing material in Git.
5. Only after those checks pass, evaluate a direct released-layout → final
   Bookmark hierarchy conversion. `_openLegacy()` currently creates v2 during
   the released upgrade; blindly deleting v2 breaks a required path. Preserve
   crash/restart, source snapshots, monotonic IDs, relationships and empty folders.
6. Remove obsolete unreleased v6–v9/transitional-v10/old Pool storage support only
   where dependency and fixture evidence proves it unnecessary. Keep public
   v4/v5 readers, shipped Following wire names and the SQLite migration chain.
   Do not turn “unreleased” into permission to erase owner test data.
7. Run targeted tests during changes and `./scripts/run_regression_tests.sh` on
   the final candidate. Native upgrades require the existing device authorization
   and lease. Record missing acceptance separately; do not substitute installer
   smoke results. Commit and push only this task branch.

## Remaining decisions, without blocking preparation

No arbitrary time-based or N-release support sunset has been chosen. Current
public support remains intact. A future retirement of an actually published
format, a destructive reset of retained owner QA data, or the first public
MiteMite mixed-version policy needs an explicit owner decision. Evidence may make
those choices unnecessary; do not invent a permanent migration layer meanwhile.

**No merge into develop/master, PR, issue closure, release or branch/worktree
cleanup is authorized by this handoff.** Report source/candidate SHAs, tests and
remaining limits before requesting any integration action.
