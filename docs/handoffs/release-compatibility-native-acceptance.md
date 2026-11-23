# Release compatibility — follow-up review and local acceptance

Date: 2026-11-22. Continue `maintenance/release-compatibility-policy`.
Reviewed HEAD: `87bc3fbdd64f1bc478fce35553fcbc2277e8126c`.
Latest runtime change: `1c0ef70854639e6988711ac2a38f27b4737bee58`.
Branch integration base: `d9203ae62dcbc5ff81e0bd70702607fb24070787`.
Develop observed during review: `b81cffd3253a8ac873b293493fb4c3ad9d4619d6`.
Released fixture baseline: `v4.6.1-timberpile.3`,
`422aeae087c1108e655d85d1a3dac25120456cd6`.

## Review disposition

**No additional confirmed runtime defect was found in this follow-up review.**
No speculative production changes or new schema versions are requested.
This document supersedes the outstanding-work status of
[the earlier review](release-compatibility-review-remediation.md), whose findings
and before-fix descriptions remain historical evidence.

R1 is addressed in the inspected implementation. Startup recovery now surrounds
the external effects that could otherwise open Bookmark storage first. A verified
published v4/v5 rollback can use the narrowly scoped Hive recovery path before
normal hierarchy activation. The path retains the existing identity matcher and
allocator, stages the recovered Group graph, durably writes records, validates
the staged state and activates it. Normal migration still rejects missing members;
ordinary imports do not receive the startup recovery callback. The added test
uses the released writer's interrupted transaction through the production
recovery provider. Negative/hash checks and interruptions during staging and
outer recovery completion are covered, followed by cold reopens.

R2 is addressed by the new production `ImportFlowNotifier` tests in
`released_auxiliary_upgrade_test.dart`. They apply all nine package sources with
profile dependency planning into destination repositories, check relationships
and cold reopen twice. A second case faults at the transaction commit after all
nine source writes, then checks rollback of the seeded destination. The absent
local legacy-feed export descriptor now falls back to the registered JSON
import decoder's version and retains collection planning for that feed source.

The review also checked the new factory/repository entry points, serialized
recovery and activation ordering, allocation bounds, final-generation retry,
fixture driver, and preservation of the earlier schema-audit/capture fixes.
The agreed final contracts remain: Bookmark wire 6, organization 2, new repository
and operation-tagged journal 1, MiteMite protocol 1 with Bookmark 6 and Following 2,
and Listed payload 1 without changing the published common Post schema 2.

## Evidence and limits

The [implementation verification report](../testing/schema_version_consolidation_results.md#review-remediation-on-2026-11-22)
records the following for runtime `1c0ef7085`: 58 focused tests; 29 schema checks;
87 inventory paths; 25 fixture checksums; a complete pass of 8,011 application,
1,730 package/CLI and 148 Python tests plus both shell suites; two existing
`go_router` skips; changed-file analysis with no errors or warnings.

Those are the implementation agent's recorded execution results. This follow-up
was a source review and did **not** independently repeat Flutter, fixture
recapture/checksums, full regression or native execution. The subsequent
`87bc3fb` commit only adds verification documentation. This handoff likewise
changes no runtime or test code and does not invalidate that exact-runtime pass.
It is not evidence of a signed Android upgrade or of a combined candidate with
newer develop changes.

## Remaining local acceptance

1. Fetch current refs and inspect the existing task worktree without discarding
   unrelated work. Read AGENTS, the release compatibility policy and
   [released-upgrade verification](../testing/released_upgrade_verification.md).
   Do not repeat the completed R1/R2 implementation or remove the negative tests.
2. On an **authorized disposable Android installation**, obey the device lease
   procedure. Verify the genuine released APK's identity/signature and use a
   compatible signed candidate with an appropriate versionCode. Seed synthetic
   data with the released app, then upgrade in place without clearing its data.
   Do not modify the owner's installation, publish a release, or commit signing
   keys, credentials, device dumps or secret-bearing logs.
3. Compare first launch and two cold launches: Posts, Group IDs/hierarchy/empty
   folders, overlapping memberships, profile/source bindings, manual ordering,
   timestamps, explicit settings, Following/feed state, tags, downloads/sidecars
   and search history. Check that migration activates one final generation and
   that a later ordinary Bookmark write persists. Where feasible, exercise the
   interrupted-import fixture through real startup as well as the existing host
   recovery test. Keep failure evidence; never use a reset as a passing result.
4. Qualify App Lock and secure-storage preservation, retained SAF directory grants,
   backup operation and recovery after a permission failure, and Android
   notification permission/channel handling plus destination-correct warm/cold
   taps, including taps deferred by App Lock. Host tests do not substitute for
   these native boundaries. Record unavailable checks as pending, not passed.
5. Before any later integration, reconcile newer develop changes **on this task
   branch only**, preserving all review fixes and normal fast-forward publication.
   At review time develop had one newer commit beyond this branch's integration
   base. A changed runtime/combined candidate needs the schema audit, affected
   recovery/import tests, analysis/format checks and the complete regression
   runner again. A documentation-only update on the identical runtime does not
   require repeating an already recorded complete pass.
6. If native or combined-candidate testing exposes a concrete defect, reproduce
   and fix it on this branch, add an appropriate regression and repeat affected
   checks. Append exact candidate/build identity, commands, device coverage,
   results and remaining limits to the existing verification report. Commit and
   push this branch; preserve previous results under their original SHAs.

Useful host commands after a runtime/integration change:

```bash
python3 scripts/audit_schema_versions.py \
  --baseline v4.6.1-timberpile.3 --candidate HEAD --inventory --json
(cd test/fixtures/released_upgrade && sha256sum -c SHA256SUMS)
./scripts/run_regression_tests.sh
git diff --check
```

Refresh actual release evidence before using a different baseline; do not adjust
version ceilings merely to make the audit pass. Existing public readers and
recovery/trust guards remain protected.

**No merge into develop/master, PR, issue closure, release, force-push, data reset
or branch/worktree deletion is authorized.** Native acceptance and final combined
verification remain distinct from the completed source review.
