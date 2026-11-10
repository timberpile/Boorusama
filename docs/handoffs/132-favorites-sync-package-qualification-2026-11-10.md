# P2 Favorites Sync package qualification

Continuation date: 2026-11-10 (Europe/Vienna). Issue: #132.

## Candidate and scope

- Branch: `feature/132-favorites-sync-package`.
- Package/source candidate: `60f0750315938b53201afc682bcb4e2af8bf5894`.
- Base and current develop: `1affa7dd315bf5838ee27d16f59908a248a4be78`.
- Formatted runtime/test candidate: `637f84a7c8d1f40d951785b36191bbea9d42ce5e`.
- Candidate tree before this report: `23e4c8bd0545aeb4f4595c6c881287f2989b6953`.

The package preserves populated Favorites Sync targets, saves settings without
fetching or clearing content, retains additive explicit fetch and isolated direct
favorite/unfavorite projection, and accepts ordinary persisted Pixiv token
rotation while rejecting a genuine account replacement. It introduces no content
contracts, unified storage migration, hierarchy, profile-independent import,
anonymous access, or later source/viewer activation. Formatting changed two Dart
files without changing behavior. No runtime correction was needed in this
continuation.

## User acceptance and historical evidence

The user reported successful manual P2 testing on 2026-11-10 and found no
problems. This acceptance is recorded as successful; no repeat manual acceptance
of unchanged behavior is required. It is not merge authorization.

Targeted CI success for original `60f0750` (117 Favorites tests) and the old
`19a84ae` full-regression/native/Sol High results remain historical evidence for
their respective candidates. They are not substituted for the complete local
qualification below. No new APK build, Android session or live-service mutation
was performed for P2 during this continuation.

## New automated verification

Pinned FVM Flutter 3.47.2 / Dart 3.13.2. Worker detector: 6 physical cores.
Fresh `./init.sh` completed using FVM and generated missing ignored outputs;
there were no tracked dependency or generated-output changes. The first
sandboxed attempt could not write the external SDK cache; the authorized
escalated initialization passed.

- Formatting qualification of all 13 added/modified Dart files in the package
  delta: `fvm dart format --output=none --set-exit-if-changed ...`; exit 0,
  zero changes after the formatting commit.
- `fvm flutter analyze --no-pub --no-fatal-infos
  lib/core/bookmarks/src/server_favorites test/core/bookmarks/server_favorites`:
  exit 0, zero errors, zero warnings, 38 informational findings.
- `./scripts/run_regression_tests.sh`: exit 0 on the candidate above; 6,218
  application tests and 1,676 package/CLI tests passed. Every discovered package
  test root ran: booru_clients 238, boorusama_cli 254, cache_manager 59, coreutils
  191, dtext 59, extended_image 47, filename_generator 31,
  flutter_sqlite3_migration 45, foundation 65, go_router 436, i18n_cli 32,
  kurumi 203, retriable 16. Both repository shell suites and all 76 Python tooling
  tests passed. No suite was skipped. go_router retains two explicit existing
  skips: `routing config works with shell route` and `Obsolete branches in
  StatefulShellRoute are cleaned up after route configuration change`.
- `git diff --check`: passed before this report; repeated for the final report.

Durable command output is under the ignored primary-workspace directory
`.worktrees/_artifacts/sequential-continuation-20261110/p2/`, including failed
initialization, successful initialization, formatter, analyzer and full runner
logs. The full runner included the documented native-hook warning, existing
locale/hit-test warnings and Dart VM finalizer diagnostics, and nevertheless
completed with exit 0 and no failed tests. No benchmark or live-service result
is inferred from host regression.

## Independent review

The independent reviewer inspected the complete issue delta and relevant
consumers/tests, including persisted assignments/restart, mixed memberships and
dates, settings-write failure, account/target changes, additive fetch, token
rotation, and constrained dialog behavior. Source verdict: **APPROVE**, no
blocking runtime findings. The reviewer authored only mechanical formatter
corrections, not the original feature or behavioral tests.

The first review ran in a separate Codex reviewer agent with inherited
model/effort. Detailed local source review: `independent-review.md` in the
evidence directory.

A separately selected independent **gpt-6.1-sol, High** reviewer also inspected
the complete issue delta through exact candidate
`637f84a7c8d1f40d951785b36191bbea9d42ce5e`: **APPROVE**, no confirmed blockers.
That reviewer authored no canonical implementation, tests or fixes, and did not
run competing compilers. Its report correctly noted that regression was still
running at review time; the completed exit-0 regression is recorded above.
Detailed local report: `sol-high-review.md` in the same evidence directory.
This new review is separate from the historical Sol High review of `19a84ae`.

## Integration gate

The current P2 candidate has passed the new local technical qualification and
the user's manual acceptance. The checked runtime/test tree already combines
P2 with current develop, so no further pre-integration suite is missing while
that combination remains unchanged. Both independent source reviews, including
the newly selected Sol High review, are recorded above.

Do not merge, push develop, close #132, create a PR or publish a release without
explicit P2 integration approval. P3 remains separately stacked and must not be
included in a P2 squash. A complete pass on this current develop-based candidate
can be reused across report-only changes. A changed develop/runtime combination
requires its own final-candidate verification. No second manual checklist is
requested for the unchanged accepted behavior.
