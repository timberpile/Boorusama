# P3: extracted Content contracts package qualification

Issue: [#154](https://github.com/timberpile/Boorusama/issues/154).
Branch: `maintenance/154-content-contracts-package`.
Reviewed extraction: `054652c4ebc5f9e567fe77920c7e20905bb78c8a`.
Checked candidate: `2c52b8c7935c8382b92232c79003b88d0e0b8958`.
Package delta base: P2 `60f0750315938b53201afc682bcb4e2af8bf5894`.
Develop base: `1affa7dd315bf5838ee27d16f59908a248a4be78`.

The only change beyond the reviewed extraction is a formatter-required blank
line in `group_capability.dart`. P3 remains stacked on P2; integration must
replay only the P3 delta after P2 is approved and integrated. Do not squash the
P2 ancestry again. No merge or publication is authorized by this handoff.

## User acceptance

On 2026-11-10 the user reported having manually tested P2 and P3 successfully,
with no problems found. This is successful user acceptance, separate from
automated verification and merge authorization. No repeat acceptance is
requested for unchanged P3 functionality. The user builds APKs personally;
no APK was built, packaged or delivered for this qualification.

## Package scope and independent source review

The P3 delta introduces shared content addresses, Summary/Details/member
contracts, codecs, access-scoped loading and an optional engine capability.
It preserves existing Post models, snapshots, repositories and viewer entries.
No production Group source, new source UI, Bookmark persistence migration,
anonymous read context or later-package behavior is activated.

An independent review/verification subagent inspected the complete P3 delta,
nearby origin/source-binding consumers and the approved contract/stage-01 plan
at `fdb68f657284e1f76701c83683aa0228484d09c8`. It found no confirmed blocker.
The review covered compatible interpretation before deduplication, immutable
metadata, defensive codecs, occurrence/hydration validation, paging/retry,
transactional validation indexes, generation cancellation, revocation clearing,
nested profile scopes and bounded shared-envelope observer ownership. It found
no fixed sleeps or strict host-speed assertions in the content tests.

This subagent inherited the session model and reasoning configuration; its
review is not represented as a named Sol/Astra review. A separate independent
GPT-6.1 Sol reviewer at High reasoning subsequently reviewed the exact checked
candidate and returned **APPROVE** with no confirmed correctness/access
isolation blocker. It authored no canonical source, tests or fixes and launched
no additional test compiler. Its approval was conditional on completion of the
new exact-candidate automated checks and granted no merge/publication authority.
The older stage-01 Astra review belongs to the historical candidate; no new
Astra result is claimed.

## New automated evidence

Pinned FVM: Flutter 3.47.2 / Dart 3.13.2. Physical-core detector: 6;
ordinary tests used concurrency 6 with no override.

- `./init.sh`: passed after rerunning with permission to update the shared FVM
  SDK cache. Localization validation and missing output generation passed;
  no tracked dependency or generated-output changes resulted. The initial
  sandbox attempt failed because the shared SDK cache was read-only.
- `fvm dart format --output=none --set-exit-if-changed` on all 30 Dart files in
  the P3 delta: final pass, zero changes. The first check detected the one
  blank-line correction committed in the checked candidate.
- `fvm flutter analyze --no-pub lib/core/content test/core/content
  lib/core/boorus/engine/src/booru_component.dart
  lib/core/boorus/engine/src/booru_engine.dart
  lib/core/posts/links/boorusama_post_link.dart`: passed, zero errors, warnings
  or informational findings.
- `fvm flutter test --no-pub --concurrency=6 test/core/content
  test/core/posts/links test/core/posts/post test/core/posts/details`: passed,
  379 tests, exit 0. Expected image failure fixture diagnostics do not indicate
  failed tests.
- First `./scripts/run_regression_tests.sh`: exit 1 after the application stage,
  6,284 passed and one failure in `post_grid_item_test.dart`:
  `decoded thumbnail probes preserve ImageListType.masonry sizing and request
  ownership` timed out waiting for a decoded thumbnail winner. Package/CLI and
  tooling stages did not run in that attempt. This file and its production
  image/listing paths are unchanged by P3; the same base passed in P2. The
  fixture mounts inside `tester.runAsync`, so production primary/final image
  deadlines run in real time while native I/O/decoding competes with other
  compilers. Scheduling sensitivity is a source-backed explanation, not a
  proven new P3 runtime defect.
- After other test compilers finished and available memory recovered, unchanged
  `fvm flutter test --no-pub --concurrency=6
  test/core/posts/listing/post_grid_item_test.dart`: passed all 30 tests in
  five seconds. No source, assertions, production deadlines or test guards were
  changed. This diagnostic does not replace the complete gate.
- Final `./scripts/run_regression_tests.sh` on the unchanged checked candidate:
  **passed, exit 0**, 2026-11-10 08:59:52–09:11:29 UTC. Application: 6,285 passed.
  Every package/CLI root ran: booru_clients 238, boorusama_cli 254,
  cache_manager 59, coreutils 191, dtext 59, extended_image 47,
  filename_generator 31, flutter_sqlite3_migration 45, foundation 65,
  go_router 436, i18n_cli 32, kurumi 203 and retriable 16, totaling 1,676 passed.
  Both shell policy/release suites and all 76 Python tooling tests passed.
  The two existing go_router skips remain; no application test or complete
  suite was omitted from this final run. The original failed attempt remains
  evidence of a scheduling-sensitive native thumbnail fixture; the final pass
  does not erase that limitation or establish a stable performance budget.

Durable local logs and the independent subagent source review are in
`.worktrees/_artifacts/sequential-continuation-20261110/p3/` in the primary
workspace. `complete-regression.log` is the failed first attempt;
`thumbnail-unchanged-diagnostic.log` is the unchanged full-file diagnostic;
`complete-regression-final.log` is the completed successful full run;
`sol-high-review.md` is the separate named independent review. Earlier full
regression and named review in
`154-content-group-contracts.md` concern historical candidates and were not
reused as new extraction evidence.

## Limits and integration checkpoint

No new Android, live-service or benchmark result is claimed. The approved
stage-01 plan explicitly states that the inactive-contract stage does not need
a new full device campaign. User-reported manual acceptance is recorded above.
Host tests do not establish device responsiveness or live source behavior.

The extracted P3 candidate is technically qualified on its documented P2 base,
with successful user acceptance and no remaining confirmed source-review
finding. P2 must be approved and integrated first. P3 then needs its own explicit
integration approval. A complete pass on an unchanged candidate can be reused
across documentation-only updates; changed runtime/tests/dependencies or a
changed combination with develop require requalification. The primary checkout
and historical task worktrees remain untouched. No push, PR, merge, issue
closure, release or remote branch deletion was performed.
