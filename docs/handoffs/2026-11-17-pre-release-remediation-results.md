# Pre-release review remediation results (2026-11-17)

All six confirmed handoff findings are corrected on their original issue branches.
The cumulative bugfix preview also includes the #122 provider-cycle correction
and #166 public-actor/draft compatibility corrections found by the full gate.
Feature #170 remains on its separate branch. Android acceptance remains pending.

**Verified runtime candidate:** `38f13488c6fc25291e920b93852bfa465b62c1b9` on
`maintenance/pre-release-bugfix-preview-20261117`.
Base develop: `4542aaa44e5002f7d546fb4ec96bf4cb0523cee5`.
Documentation added after that candidate does not change runtime/test inputs.

## Findings and regression evidence

| Finding | Result and failing-before/passing-after evidence |
| --- | --- |
| #166 A: native index corruption | Patch one canonical record through the serialized journal/commit guard. Real Hive restart tests preserve sourceGroup index, tags, coverage, dates, Details, IDs, unrelated records and membership timestamps. Original code changed the native index to memberUnion. |
| #166 B: permanent failed lookup | In-flight deduplication plus one-minute cooldown and 256 completed-outcome bound; keep-alive ends with the lookup. Controlled-clock failure/retry and eviction regressions fail with the original permanent cache and pass now. |
| #166 C: received source mutation | Received/shared Pools use access/policy/source-revision scoped presentation covers. Real-Hive tests cover local/received/shared ownership, public success, replacement, revocation and Forget without changing publisher payloads, digests, read state or organization. Original received mutation failed the mirror guard. |
| #174: lost route page/position | Explicit route pages force pagination; indexed anchors restore one Work once in standard and variable masonry layouts. Tests cover actual SearchPage, query reset, account switch, page controls and sparse/unknown legacy Page counts. Original mode/position and offline source invalidation fail the regressions. Successful refresh replaces fresh envelopes with request/access guards; old non-replacing seeding fails the 3-to-2 Page control. |
| #170: final Topic sort | Sort the final unique projection after filtering/direct subscriptions. Canonical tree/placement order preserves Manual. Real narrow Home/nested-folder tests and two publisher sections fail before the correction; reversed-placement Manual controls also fail with the original candidate order. Feature stays separate. |
| #172: stale diagnostic/operation | Every accepted diagnostic advances generation; validation and backup completions use generation ownership. Regressions cover same-category access errors, identical generic diagnostic objects, stale success/error, selected-folder preservation and failed settings saves. Original and initial identity-only corrections fail their respective regressions. |

The first full run additionally exposed #122's read of its own derived ordering
provider. Independent investigation reproduced the ancestry cycle on the original
issue branch. A shared pure projection now serves the provider and notifier.
Existing add/delete/duplication regressions pass without weaker assertions or
longer timeouts. Plain link/import/lookup fixtures now supply settings and distinct
profile IDs. Native public covers cannot switch to a newly added private profile;
empty-member Pool drafts avoid unnecessary blacklist initialization.

Per-issue detail: [#166](2026-11-17-166-review-remediation.md),
[#174](2026-11-17-174-review-remediation.md),
[#172](2026-11-17-172-review-remediation.md),
[#122](2026-11-17-122-review-remediation.md),
[#170 feature report](https://github.com/timberpile/Boorusama/blob/49dd651d3087cbf87eac449d0e60740965123f52/docs/handoffs/2026-11-17-170-review-remediation.md).

## Source publication and replay inventory

| Issue | Original branch HEAD |
| --- | --- |
| #166 | `bug/166-pool-bookmark-covers` — `38363a2c1f0f38339ea74859a6678179a366acd8` |
| #174 | `bug/174-pixiv-work-grouping` — `bc8434c60d50b62ddbd7a3ece9097297f593cbf8` |
| #170 | `feature/170-following-topics-added-sort` — `49dd651d3087cbf87eac449d0e60740965123f52` |
| #172 | `bug/172-backup-folder-recovery` — `8e010d48c081df3a9f1e86acce52041a8fec8f56` |
| #122 | `bug/122-profile-reordering` — `0f5c1c9ec76d99707c474a3f0181b0cec2772b95` |

All source heads were pushed and checked against origin. Feature #170's runtime
correction is `0649e7c7123cfcf1caa81f60b9e130d8f16bebab`; its later commit only
clarifies the report.

| Source correction | Preview replay |
| --- | --- |
| #166: `428dc0ca136b437158a0bfebd1ec50e019207810` | `0f146f19b82a5f3748ac8808ae011d34f630b39f` |
| #174: `bc8434c60d50b62ddbd7a3ece9097297f593cbf8` | `9a8c0703303cec086cb4177eda4177a8fe7d27a9` |
| #172: `8e010d48c081df3a9f1e86acce52041a8fec8f56` | `0a78e83e504462ec474294390bb2766b047866fd` |
| #166: `58d15e9f88f21ebbe0eca43927116e3b61f9f339` | `1c59aa2afe72ee5fcccf3cee106def803b4d7780` |
| #166: `38363a2c1f0f38339ea74859a6678179a366acd8` | `647b5447722fc76f72dc3dd75bc8c48091b439ff` |
| #122: `0f5c1c9ec76d99707c474a3f0181b0cec2772b95` | `38f13488c6fc25291e920b93852bfa465b62c1b9` |

All **19** stable source/replay patch IDs match, including the original 13 pairs
and six remediation/follow-up pairs. The preview retains all ten bugfix issues:
#121, #122, #131, #146, #147, #166, #169, #172, #174 and #175. The stationary
#122 handle follow-up remains included. Features #171/#168/#170/#134 and the
waiting #173 branch remain excluded. No new issue was added to the preview.

## Verification on the final candidate

`./scripts/run_regression_tests.sh` completed with **exit 0**, using the detected
six physical cores. It ran the application, every package/CLI test suite and
repository tooling. Results are separate from the earlier failed run:

| Suite | Passed | Skipped |
| --- | ---: | ---: |
| application | 7,678 | 0 |
| booru_clients | 240 | 0 |
| boorusama_cli | 254 | 0 |
| cache_manager | 68 | 0 |
| coreutils | 191 | 0 |
| dtext | 59 | 0 |
| extended_image | 47 | 0 |
| filename_generator | 31 | 0 |
| flutter_sqlite3_migration | 45 | 0 |
| foundation | 65 | 0 |
| go_router | 436 | 2 |
| i18n_cli | 32 | 0 |
| kurumi | 227 | 0 |
| retriable | 16 | 0 |
| **Flutter/Dart total** | **9,389** | **2** |

Both `.github/scripts/test-pull-request-policy.sh` and
`.github/scripts/test-android-release-scripts.sh` passed. Repository Python tests:
**76 passed**, exit 0. The two existing go_router skips are explicitly declared
`skip: true` with upstream bug TODOs:

- `routing config works with shell route` in `routing_config_test.dart:142`.
- `Obsolete branches in StatefulShellRoute are cleaned up after route configuration change`
  in `go_router_test.dart:4743`.

Changed-scope `fvm dart format --output=none --set-exit-if-changed`: **34 files,
zero changes**. `fvm dart analyze` on those files: **zero errors, zero warnings,
86 informational findings**. `git diff --check` passed. No changed generator input
required `gen.sh`.

Issue-branch checks also passed (separate overlapping runs, not additive totals):
#166 initial scope 93, public/native scope 45, final public fixture 14, draft scope 25
and Summary/Details controls 7; #174 Work/grid/cache 128; #170 Following Topics 791
and final Manual controls 3; #172 recovery/diagnostic/operation 31; #122 complete
profile/link/import/lookup/drag consumer scope 265. Exact commands are in the
per-issue reports.

### Native gates and APK provenance

- `fvm flutter build apk --debug --flavor prod`: **exit 0**, production debug APK built.
- Java17 `./android/gradlew -p android --init-script <artifact>/force_fresh_native.gradle :app:compileProdDebugKotlin :app:testProdDebugUnitTest --no-build-cache --max-workers=2 --console=plain`: **exit 0**.
- Production Kotlin compile and JVM test tasks executed fresh, without up-to-date
  or build-cache reuse. XML: **57 tests / 10 suites, zero failures/errors/skips**.
- Five production probe-helper tests verify success, unavailable/failed opening,
  failed creation, failed cleanup and write-failure stream closure. Existing
  documents are never selected for modification; cleanup targets the created probe.

The local init script used:

```groovy
gradle.projectsEvaluated {
    rootProject.allprojects {
        tasks.configureEach { task ->
            if (task.name == 'compileProdDebugKotlin' || task instanceof org.gradle.api.tasks.testing.Test) {
                task.outputs.upToDateWhen { false }
                task.outputs.cacheIf { false }
            }
        }
    }
}
```

APK: `boorusama-38f13488c-prod-debug.apk`, **401,943,891 bytes**.
SHA-256: `6d1815f9edd15e675409bded9ee77835b0b6dd98d27be925e39ef5fa433f8cf2`.

It was built from the verified runtime candidate, copied to durable artifacts and
not installed. Build logs include existing AGP/Kotlin support warnings and the
known libavif build-hook warning. Successful Flutter checks also print existing
native-finalizer diagnostics; these are not Android acceptance evidence.

### Earlier failed gate and environment setup

The first full run on `0a78e83e504462ec474294390bb2766b047866fd` ended with
**7,606 passed / 67 failed**, exit 1; packages/tooling were not reached. Ten
cover-related failures and 56 profile-cycle/consumer-fixture failures were
corrected on their owning #166/#122 branches. One migration setup failure
required `fvm dart pub get` in `packages/boorusama_cli`. The separate local
`packages/go_router` test context was initialized with `fvm flutter pub get` so
its tests resolve local source. No tracked dependency/resolution inputs changed.
The final full pass above supersedes this failed gate.

## Independent review and acceptance limits

Independent read-only review identified the generic #172 error-identity race,
#174 fresh-envelope and sparse-Page cases, #170 canonical Manual order and #122
provider cycle. Their corrections were re-reviewed. The final replay review on
`38f13488c` found **no remaining confirmed issue** and verified that #169 retained
refresh and #175 navigation/autohide behavior remain intact. Review did not
substitute for executed verification.

Not performed: emulator/device/Maestro tests, APK installation, live
Pixiv/Danbooru/MiteMite requests, real SAF-provider or cloud-backup acceptance,
release builds/signing/publication, workload benchmarks or final Android QA.
Native compilation and host tests do not establish real-provider behavior or
device responsiveness. Ambiguous/missing originating profile identity still
fails closed; cover remediation does not invent a legacy profile binding.

Owner Android priorities remain stationary handle holds and drag, received Pool
cover/source access, Pixiv route/refresh/back navigation and writable/read-only/
revoked SAF providers with concurrent selection/backup. #170 date/filter/Manual
acceptance belongs to its separate feature branch.

No develop integration, issue mutation/closure, PR creation, branch deletion or
worktree deletion was performed. Remote develop remains at the stated base; the
primary detached checkout and unrelated worktrees were preserved.

Durable evidence: `.worktrees/_artifacts/pre-release-remediation-20261117/`
contains all red/green logs, `preview-final-regression-results.json`,
`preview-patch-inventory.json`, `preview-native-results.json`, native XML,
`preview-apk-provenance.json` and the debug APK.
