# Accepted update fixes integration — 2026-10-29

The user accepted bug/109-mobile-update-indicator and bug/110-update-notes-utf8 and said they can be merged. Under AGENTS.md this authorizes verified publication to origin/develop, issue closure and completed branch/worktree cleanup. #111 was not approved and remains separate.

| Issue | Reviewed branch head | Integration squash |
| --- | --- | --- |
| #109 | 2d2d6b31012681ddc3fad02e49d6815092ec010b | 06cb49da5 |
| #110 | e83d48d99f51de8389a7597778608e9014b3dbf6 | 8b995548d |

Started from published develop 93dc7199057ca4ef47f4def4278180dc48d5ce86. Both complete patches were independently reviewed against their actual current heads and combined without conflicts; stable patch IDs with zero context match each integration squash to its complete source branch patch. No runtime/test correction was needed.

Final checked runtime/test commit: **8b995548de04f1609b88045534ba87c13a9f483a**. Subsequent changes in this record's containing commit are documentation only.

- Fresh FVM setup and required generation of missing outputs: passed.
- `fvm dart format` on all four affected Dart files: zero changes.
- `fvm flutter analyze --no-pub --no-fatal-infos` on all four: exit 0; no errors/warnings; three test-only informational suggestions.
- `fvm flutter test --no-pub --concurrency=6 --reporter expanded test/home_search_bar_update_test.dart test/app_update`: **53 passed**, no skips. Includes mobile available/unavailable/pending/error/unsupported states, compact/2x text, profile picker bounds and dialog tap, five Unicode HTTP content types and malformed UTF-8 rejection, updater/cache/lifecycle consumers.
- **`./scripts/run_regression_tests.sh`: exit 0**. **5,546 application tests + 1,608 package/CLI tests passed**, two existing upstream go_router skips. Both shell policy/release-script suites and **72 Python tests passed**. Physical-core concurrency: 6. The final complete invocation finished successfully; no resumed/partial result is represented as a full-run pass.
- Complete integration diff, patch equivalence and `git diff --check`: passed. No outgoing merge commits introduced.

The recurring native Dart-VM callback/finalizer and libavif build-hook diagnostics appeared in successful runs; native logs are not clean. No engine/cache workaround or test exclusion was introduced. Manual acceptance is the user's branch review; no new combined APK/device session or release-signed upgrade was claimed.

The primary checkout remains at the user's detached #111 commit 2c0d46f36f0405f384129239a63a14d18cea66b3 with their temporary pubspec version 0.0.0+1 preserved. All implementation/integration work took place in isolated worktrees. No PR, master change, tag or release was created.

#111 follow-up: the user confirmed download and opening Android unknown-sources Settings, then received an install-start error on return. The local debug test APK and verified public release APK have different signing certificates, so native preflight must reject this pair. All 51 updater tests and three native policy tests passed again. See its separate branch handoff at 9ac4dd73b; actual same-certificate installer/replacement acceptance and #111 integration approval remain pending.

Logs: `/tmp/boorusama-followup-2026-10-29/updates-integration-{setup,format,analysis,tests,regression}.log`; #111 evidence is in `111-{permission-return-check,native-policy-recheck,signing-comparison}.log`. Publication is verified before issue closure and exact-tip remote/local cleanup.
