# Issue #132: preserve Favorites Sync group contents

**Current local result (2026-11-07):** stage 00 passed required automated and synthetic native checks plus independent `gpt-6.1-sol` High review on `19a84ae2517ec741e90df773c658fc1508f1a481`. The preparation record below is historical; see the verified local continuation for current evidence and limits. The issue remains open and integration/publication remain unauthorized.

## Branch and ownership

- Issue: https://github.com/timberpile/Boorusama/issues/132
- Task branch: `feature/132-preserve-favorites-sync-group-contents`.
- Base: `e306ff5338a2255a89731c61bd0672336a933344`.
- Runtime/test candidate before this documentation commit: `b4995fd3248b9431730378772f82329d7e9c6ba2`.
- Prepared during session `architecture-rollout-20261106`; local verification and independent final review are now handed to the local lead. The issue remains open/in-progress because required technical verification is outstanding.
- No PR, merge, develop/master change or release was performed.

Read current AGENTS.md, docs/development_workflow.md and docs/issue_workflow.md before continuing. Reuse an existing isolated worktree if present; never reset or take over an unrelated checkout.

## Implemented source changes

`ServerFavoriteSettingsNotifier` no longer accepts confirmedClears or performs first-binding bookmark removals/rollback. It still validates destination existence, stale settings/accounts, disabled targets and settings persistence; Save never starts a fetch.

The dialog no longer computes candidate clears or displays the destructive confirmation. Its established explicit Save & Fetch actions remain explicit network actions. #133's broader dialog redesign is intentionally excluded. The unused clearing helper binding.dart and obsolete confirmationRequired runtime enum/message dispatch were removed. Existing unused translation keys were left in place to avoid unrelated generated-output churn; they are not reachable from this flow.

The Favorites Sync specification now prohibits destructive target assignment. All source changes are limited to this issue, not the content-architecture runtime refactor.

## Tests prepared

- New `test/core/bookmarks/server_favorites/assignment_preservation_test.dart` covers global, profile, single-editor and all-editor assignment with Post + Pool + Related data, independent memberships/dates, cold reload, no fetch and settings-write failure.
- `settings_provider_test.dart` now expects populated assignment without confirmation and still rejects a missing destination.
- `controller_integration_test.dart` replaces clearing expectations with preservation, concurrent content changes and additive explicit fetch; existing account/target/cancellation/direct-action cases remain.
- `all_profiles_integration_test.dart` retains durable account-change rejection without clear parameters.
- `dialog_test.dart` covers unsaved Close, populated/shared Save without a destructive prompt, and an account change before saving; existing narrow/large-text/picker/fetch tests remain.

## Verification actually performed here

GitHub file contents and generated commit diffs were inspected, including the removed destructive settings path, dialog changes, test expectations, constructor compatibility for Pool/Related fixtures and changed-file scope. This was a source review by the implementer, not an independent model review.

No FVM, Flutter or Dart executable is installed in the preparation runtime. Public Git cloning from the container also failed due DNS; repository reads/writes used the connected GitHub API. Therefore **Dart formatting, analyzer, RED/GREEN execution, Flutter tests, full regression and Android acceptance have not run**. Do not report the prepared tests as passing. This branch is not yet a verified prerequisite or integration-ready.

## Local execution, in order

1. Fetch current refs, confirm this branch still contains only #132 and preserve any concurrent work. Read issue comments and claim the local continuation.
2. Inspect the entire diff from the recorded base. Search for obsolete runtime/callsite references:

   ```bash
   rg -n 'confirmedClears|serverFavoriteGroupsToClear|ServerFavoriteProblem\.confirmationRequired|server_favorites/binding\.dart' lib test
   ```

   No live Dart callsites should remain. Unused translation entries are not a live Dart reference. Restore the incidental equivalent `Key` versus `ValueKey` spelling in the picker test if it adds noise; do not otherwise refactor unrelated tests.
3. Use the pinned FVM environment, resolve existing generated outputs only as needed, and format changed Dart files. Run affected analysis. Inspect fixture constructors and the actual repository interfaces rather than trusting this handoff.
4. Run all server_favorites tests plus bookmark library/provider consumers:

   ```bash
   test_workers="$(python3 scripts/physical_core_count.py)"
   fvm flutter test --no-pub "--concurrency=$test_workers" test/core/bookmarks/server_favorites
   fvm flutter test --no-pub "--concurrency=$test_workers" test/core/bookmarks
   ```

   Fix failures on this same branch. If useful, demonstrate the new populated-assignment regression fails against the old settings code in a disposable isolated comparison; do not overwrite the working branch or invent a previous RED run.
5. Verify Save with populated mixed target, target changes, default/per-profile inheritance, settings-write failure, no network on ordinary Save, explicit additive fetch, and direct unfavorite removing only the assigned membership. Existing dates and records must match before/after target assignment exactly.
6. On a leased Android emulator, check populated target Save and no destructive prompt at narrow width/large text. Do not mutate the user's actual server favorites or real library for a regression test.
7. Run `./scripts/run_regression_tests.sh` on the final integration candidate when required by current AGENTS.md. Record commands/results/limits and commit any corrections with `Refs #132`.
8. Obtain a fresh **independent Sol High** final review (Astra High if scope unexpectedly expands to storage/recovery). The reviewer must inspect the entire issue diff and relevant tests, not just this handoff. Implementer self-review is not sufficient. Remediate, retest and re-review the revised candidate.
9. Update this handoff with the actual tested/reviewed SHA and results, then supply that SHA as the first runtime base for the content-architecture sequence. Do not close #132 or merge/push develop without explicit integration authorization.

The cross-machine rollout instructions live on `maintenance/content-architecture-design` at `docs/handoffs/content-architecture-local-agent.md`. Read that branch through its separate worktree or git show; do not mix planning history into this runtime task.

## Verified local continuation (2026-11-07)

### Source and authorization

- Issue: https://github.com/timberpile/Boorusama/issues/132
- Branch: `feature/132-preserve-favorites-sync-group-contents`.
- Requirements: `maintenance/content-architecture-design` at `fdb68f657284e1f76701c83683aa0228484d09c8`, especially stage 00, approved contract and review protocol.
- Issue delta base: `e306ff5338a2255a89731c61bd0672336a933344`.
- Prepared source/test candidate: `b4995fd3248b9431730378772f82329d7e9c6ba2`; prepared handoff: `2d468355406b92448d52f1b2a4914d058c6d5a1b`.
- Final runtime/test candidate: `19a84ae2517ec741e90df773c658fc1508f1a481`, tree `9d58d8e4b2f5800edbf7f146aef324bedb12024d`.
- No inherited unverified architecture runtime, new migration, #133 redesign, PR, push, merge, issue closure or release is included.

### Implemented and remediated behavior

Target assignment through global, per-profile, single-editor and all-editor APIs changes settings only. First binding and reassignment preserve existing Post, Pool and Related records, shared memberships and dates. Ordinary Save never starts a Favorites request. Explicit fetch remains additive; confirmed direct favorite/unfavorite projection still changes only its captured assigned group. Missing destinations and stale accounts/settings remain guarded. The destructive confirmation, clearing helper/arguments, clearing rollback and obsolete runtime error dispatch are removed. Unused translation keys remain unreachable and unchanged.

Local verification found missing configuration/origin-helper imports in the prepared preservation test. These were corrected; changed Dart files were formatted and an incidental Key/ValueKey change restored. The test harness now stores collection data in Hive and can dispose all providers, close all three Hive files and reopen them. Preservation compares persisted baselines before assignment and after restart; this respects existing Hive millisecond precision for Post save dates without weakening exact membership-date comparisons. Failed settings writes preserve the old assignment and saved content after reopening.

### Automated verification actually performed

Pinned FVM: Flutter 3.47.2 / Dart 3.13.2. Physical-core detector returned 6. Fresh-worktree dependencies were resolved with FVM; missing generated output was produced with `./gen.sh` after CLI setup. No dependency upgrade or tracked generated-output change occurred.

Commands and results on the final candidate:

- `fvm dart format --output=none --set-exit-if-changed <all 10 changed Dart files>`: pass, zero changes.
- `fvm flutter test --no-pub --concurrency=6 test/core/bookmarks/server_favorites`: 113 passed.
- `fvm flutter test --no-pub --concurrency=6 test/core/bookmarks`: 709 passed.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/bookmarks/src/server_favorites test/core/bookmarks/server_favorites`: exit 0; zero errors, zero warnings, 35 informational findings. This is affected-scope analysis, not a clean whole-repository analyzer claim.
- `./scripts/run_regression_tests.sh`: exit 0; 6,167 application tests and 1,661 package/CLI tests passed. Both shell policy/release-script suites and all 76 Python tooling tests passed.
- `git diff --check`: pass; task worktree clean after committing.

Every discovered package test root ran: booru_clients (238), boorusama_cli (254), cache_manager (59), coreutils (191), dtext (59), extended_image (47), filename_generator (31), flutter_sqlite3_migration (45), foundation (65), go_router (436), i18n_cli (32), kurumi (188), retriable (16). go_router retains two explicit pre-existing skips: `routing config works with shell route` and `Obsolete branches in StatefulShellRoute are cleaned up after route configuration change`. No suite was skipped.

Full output retains locale fallbacks, existing hit-test warnings and Dart VM finalizer diagnostics; the runner completed with exit 0. No benchmark or old-code RED run is claimed. The first prepared-test execution failed compilation for missing imports; those failed logs are retained separately rather than represented as a behavioral RED pass.

### Android evidence and limits

An exclusively leased `emulator-5554` ran the actual Favorites Sync dialog/settings/library through an isolated synthetic fixture, with real Hive persistence, one Post shared by two groups, one shared Pool and one Related family. The fixture constrains content to 320dp and 2x text. It uses a counted synthetic Favorites source and a new dev package, not the user's real library/accounts.

Maestro passed first populated target assignment, ordinary Save closing without destructive confirmation, preservation against the saved snapshot/date baseline, and zero Favorites requests. A real process stop/relaunch retained the chosen target and identical library. Reassigning to the other populated group and another stop/relaunch passed the same assertions. Picker choices and footer actions remained reachable. Existing widget coverage also exercised constrained/large-text/keyboard picker cases. The fixture was stopped and its exclusive device lease released.

Build command: `fvm flutter build apk --debug --flavor dev --target .dart_tool/content_architecture_qa/main.dart --target-platform android-x64`. Build and streamed install passed. APK SHA256: `6fe78d249fcf41135d6ddaa175dcd61d365b91b28c59a35f4dbab084ebf9827f`. Fixture source SHA256: `4b71611de223332dc1fd6a68e804c2fb5396ec61654b0902664ce4d7f18ec49f`. This establishes current-source native evidence for the exercised dialog/settings/library; it is not a production-bootstrap, release-build, live-service or device-latency claim. No remote favorite mutation was performed.

Durable local evidence: `.worktrees/_artifacts/content-architecture/132/` in the primary workspace. It includes per-command logs and `verification-results.json`, `native-main.dart`, `native-evidence.json` with actual Maestro flows/results/hierarchies, safe synthetic screenshot `native-after-restart.png`, build/install logs and hashes. These are local ignored artifacts, not published shared files.

### Independent final review

**APPROVE** from a fresh independent `gpt-6.1-sol` reviewer at **High** effort on `19a84ae2517ec741e90df773c658fc1508f1a481`. The reviewer did not author implementation, tests or fixes; it inspected the complete issue delta, live issue/comments, relevant consumers, exact-candidate logs, native flows/hierarchies/screenshot and matching fixture/APK hashes. No blocking correctness, data-loss, isolation or access-control findings and no runtime change requests were identified. The sole documentation condition was to update this historical handoff with the actual local continuation, fulfilled here. No runtime remediation/re-review cycle was needed after this approval. Full independent report: local artifact `sol-high-final-review.md`.

### Next-stage and integration limits

Stage 00 is locally complete and may supply the next dependent local stage. The verified runtime base is `19a84ae2517ec741e90df773c658fc1508f1a481`; the eventual handoff-only commit can be inherited without rerunning unchanged runtime tests. Record that exact dependency base in #154's handoff. All implementation issues remain open until authorized shared publication; current develop integration and publication remain unauthorized. A later combined develop candidate requires its own full verification if its runtime combination differs.
