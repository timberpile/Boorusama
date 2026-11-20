# MiteMite service lifecycle: local implementation handoff

Integration was approved on 2026-11-20 for this fix and the Group source-loss
follow-up. See Section 10 for the complete integration qualification. The
local-only instructions and source snapshots below describe the earlier
preparation stages.

## 1. Task, branch, and authorization

Fix the `A MiteMiteService was used after being disposed` assertion when opening Bookmarks. The owner requested a separate fix based on `develop`, not changes to the viewer feature branch.

- Repository: `timberpile/Boorusama`.
- Continue the prepared branch: `bug/mitemite-service-lifecycle`.
- Branch base and source examined for this handoff: `develop` at `04fd511a895aabbf2c08d833cc1ce3473181621d`.
- Original report: `feature/176-group-viewer-design`; the earlier investigation examined `026798566a6361f4b12038c2111954ddaf1fcf3d`.
- This is an explicitly requested, issue-free scoped fix. No new issue was created. Do not use #176 as this fix's issue ID or close it: that is the separate viewer feature.
- The prepared remote branch originally contained documentation only. See Section 9 for the local implementation and verification outcome.

Read current `AGENTS.md`, `.agents/skills/debug-issue/SKILL.md`, and the relevant development/verification guidance. Fetch current remote references and inspect `git status` and `git worktree list`. Reuse this task's worktree if one exists; otherwise attach this existing branch in an isolated worktree according to `docs/development_workflow.md`. Do not run the create helper as though the remote branch did not already exist. Preserve all unrelated work; do not switch, reset, or stash the user's checkout.

Implement, test, review, and commit the scoped fix on this branch. Do not merge to `develop`, create a PR, close issues, or modify `feature/176-group-viewer-design`. Publishing implementation commits requires the normal explicit task-branch push authorization; documentation publication does not authorize a develop merge. Recheck the current develop delta before implementation and any later integration; do not blindly apply a sketch to changed code.

## 2. Report and evidence

The owner reports that entering Bookmarks briefly displays an assertion on screen (approximately half a second), after which Bookmarks generally work.

The supplied stack trace establishes this call chain:

```text
ChangeNotifier.debugAssertNotDisposed
  -> ChangeNotifier.addListener
  -> MiteMiteChanges.build (providers.dart:157 in the reported build)
  -> syncCollectionAliasesProvider / publishedBookmarkRootsProvider
  -> BookmarkGroupBrowserPage.build
```

This proves that `MiteMiteChanges.build` attempted to register a listener on an already-disposed service. The line numbers identify the reported build, not an invariant location in future revisions. Do not copy the full user log or local filesystem paths into the repository.

Source inspection at the develop baseline establishes:

- `miteMiteServiceProvider` creates and owns a `MiteMiteService`; its `ref.onDispose` disposes `createdService`.
- `MiteMiteChanges.build()` reads `ref.watch(miteMiteServiceProvider).valueOrNull` and immediately calls `service?.addListener(changed)`.
- Other projections and `MiteMiteLifecycle` also read the service through unfiltered `.valueOrNull`.
- The provider file has the same blob SHA (`e94997a72729ad486b8e84eb5ab7699d9699a65b`) on the examined feature snapshot and develop baseline. The unsafe code is not exclusive to #176.

### Confidence and remaining uncertainty

**Confirmed:** the disposed-listener assertion and the unsafe consumer/ownership combination above.

**Confirmed by the local controlled regression (Section 9):** provider recomputation disposes service A while Riverpod retains A as previous data in a loading/error `AsyncValue`; `.valueOrNull` exposes A, and a consumer attaches to it. Riverpod's retained previous value is useful for immutable display data, not as proof that an owned resource remains usable.

**Unknown:** the exact dependency change or invalidation that triggered this in the owner's session. Do not claim that opening Bookmarks itself invalidates the provider. Also do not claim that a release build is correct merely because debug assertions disappear.

Start by reproducing the retained-value lifecycle in a controlled test. If the test or the local call graph contradicts this explanation, trace actual ownership/disposal rather than forcing the proposed fix. No product decision is needed for the narrow fix; unexpected architectural changes need separate discussion.

## 3. Required behavior and boundaries

An already-disposed service must never be newly attached to a listener or used to start operational work. On replacement, consumers must stop using A, tolerate temporary service unavailability, and attach to B when B is ready. A failed replacement must not resurrect A; a later successful retry must work.

Keep a single disposal owner: `miteMiteServiceProvider`. Preserve cancellation of obsolete initialization, repository coordination, sync identity/trust, subscriptions, aliases, read/unread state, pending local changes, and transport activation behavior.

This is a provider/consumer lifecycle fix. Do not change persisted formats, add a storage migration, update Riverpod/Flutter, redesign Bookmarks, or refactor sync scheduling beyond changes demonstrated necessary by this failure. Do not delete user settings, bookmarks, mirrors, aliases, or caches as a workaround.

## 4. Implementation approach

### A. Centralize selection of a currently usable service

Add a small manually declared, non-owning provider next to `miteMiteServiceProvider`, following nearby style. Proposed name: `currentMiteMiteServiceProvider`.

Illustrative, unexecuted sketch:

```dart
/// Excludes retained resources from previous async generations.
/// The source provider remains the only owner of service disposal.
final currentMiteMiteServiceProvider = Provider<MiteMiteService?>(
  (ref) => ref
      .watch(miteMiteServiceProvider)
      .unwrapPrevious()
      .valueOrNull,
  dependencies: [miteMiteServiceProvider],
);
```

Confirm this against the actual Riverpod version pinned by the local `pubspec.lock`. The earlier inspected lock used the `khoadng/riverpod` fork at `5a513c5aeee5a91d7cf5aa9a6e6a414b822bdee9`, version 2.6.1. Its `AsyncValue.unwrapPrevious()` maps a loading `AsyncData` back to `AsyncLoading`, and removes the previous value from loading/error states.

A raw `asData?.value` or `is AsyncData` check is not an equivalent fix: refresh may retain an `AsyncData` wrapper with `isLoading == true`. Do not substitute `requireValue`, which can turn temporary unavailability into a build failure. An explicitly tested equivalent predicate is acceptable, but centralize the rule instead of scattering inconsistent guards.

This projection prevents the retained-value failure mechanism. It is not a universal proof that an arbitrary cached reference is alive forever, particularly across asynchronous boundaries.

### B. Use the projection in the change bridge and synchronous consumers

In `MiteMiteChanges.build()`, watch the new provider, attach only when non-null, and keep balanced removal of the same callback. Update its explicit `dependencies` to include the new dependency. Preserve the revision bridge rather than introducing a second `ChangeNotifierProvider` that might assume disposal ownership.

Audit and update these consumers in `lib/core/backups/mitemite/providers.dart`:

- `publishedBookmarkRootsProvider`;
- `publishedFollowingRootsProvider`;
- `followingSyncPresentationProvider`;
- `syncCollectionAliasesProvider`;
- `miteMiteManagementViewProvider`;
- `_MiteMiteLifecycleState.build()` / `_attach()`.

Update affected explicit dependency declarations so overridden/scoped service providers continue to resolve correctly. Retain existing `.select` projections and their equality behavior; do not make collection labels and lists rebuild on every operational timestamp or sync poll.

Keep existing lazy/activation guards in front of new service watches. In particular, do not turn an inactive Bookmarks view into service creation, transport activation, or periodic scanning merely by introducing the helper. Preserve intentional existing service reads elsewhere; this task is not a redesign of activation policy.

For unavailable services, projections may use their established empty/null fallback. Such fallbacks must not erase persisted data or be interpreted as an instruction to unpublish/delete collections. Error/loading presentation must continue observing the underlying `AsyncValue` where needed; do not hide initialization errors permanently behind an empty collection or endless spinner.

### C. Audit all service references, including callbacks

Find actual call sites instead of changing every `.valueOrNull` in the application:

```bash
rg -n 'miteMiteServiceProvider|MiteMiteChanges|MiteMiteLifecycle' lib test
rg -n 'unwrapPrevious|invalidate\(|refresh\(' lib/core/backups lib/core/bookmarks
```

Classify direct `.valueOrNull`, `.value`, `asData`, retained `_service` fields, callbacks, and awaited `.future` reads. Immutable bookmark data may intentionally retain previous values and must not receive a blanket replacement.

Convert service-instance consumers where applicable; retain raw async-state reads for legitimate loading/error UI. An action callback must not operate on A merely because it captured A when the widget last built. Re-read the current service at action time or use an appropriate existing generation/identity check. Do not treat an awaited future as a permanent lifetime guarantee after subsequent async work.

For `MiteMiteLifecycle`, exercise replacement while timers, directory watchers, post-frame startup work, or local-change callbacks are pending. Existing detach must cancel obsolete scheduling and remove listeners without touching a newly attached instance. Do not let an obsolete post-frame callback launch duplicate startup work against B. Add a narrow identity/generation guard only where a test demonstrates it is needed; do not broadly rewrite the scheduler.

Distinguish harmless cleanup from operational use: Flutter permits listener removal after disposal, so a test must not incorrectly reject `removeListener` cleanup. Inspect the service's `setForeground`, cancellation and disposal contracts before assuming all cleanup operations are safe. Do not call new operational methods on an obsolete instance.

### D. Investigate the triggering rebuild without expanding scope

Inspect the watched dependencies of `miteMiteServiceProvider` and relevant invalidation/override sites. Reproduce explicit service invalidation and dependency-driven recomputation independently of the owner's complete UI sequence. Check production construction/disposal, not only an overridden provider.

If unexpected churn is demonstrated, document the trigger and make only the necessary scoped correction. Safe handling of legitimate recomputation remains required even if unnecessary invalidation is also removed. If the original trigger cannot be established, report that limitation while delivering the verified lifecycle fix; do not invent a cause.

## 5. Regression tests

Prefer provider and widget tests without an emulator. Proposed focused file: `test/core/backups/mitemite/provider_lifecycle_test.dart`; extend an existing suitable lifecycle test if current develop already has one. Inspect `test/core/backups/mitemite/following_service_test.dart` and nearby service tests for real repository/service setup. `MiteMiteService` is final: do not plan to subclass it just to count events. Reuse real service construction with fake dependencies or existing fixtures, avoiding a production API added solely for this test.

Use a controllable completion gate for replacement initialization. Exercise actual Riverpod recomputation and the real consumer graph. A test that merely asserts `unwrapPrevious()` behavior, overrides the new helper itself, or never disposes A does not reproduce this bug. An override of the source factory must mirror real ownership (`ref.onDispose`), return a fresh instance per generation, and never reuse a disposed service.

Required scenarios:

| Scenario | Essential assertions |
| --- | --- |
| Initial pending creation -> A ready | Consumers tolerate null; A becomes usable and notifications reach the bridge. |
| A ready -> explicit invalidate/refresh -> delayed B | A is disposed by its owner; intermediate reads/rebuilds do not attach to A; B is unavailable until completion and then works. Cover retained-data refresh, not just a fresh `AsyncLoading`. |
| A ready -> watched dependency changes -> delayed B | Reload semantics also exclude A and recover correctly. |
| Replacement fails -> retry succeeds | Error with previous data never exposes A as usable; original async error remains observable; retry attaches to a fresh instance. |
| Repeated replacement and teardown | No accumulating listeners, duplicate bridge notification effects, double-disposal, or late callback errors; container/widget cleanup completes. |
| Bookmarks with received mirrors/aliases | Watch the real alias/root projections and exercise the browser's conditional alias subscription; assert no framework exception/ErrorWidget while the replacement is pending and after it resolves. |
| Lifecycle scheduling | Exercise replacement/unmount with pending startup, poll/debounce or async work as applicable; obsolete work does not operate on A or create duplicate attachment/startup work for B. |
| Inactive sync and scoped overrides | Existing non-activation behavior remains intact; child-container overrides reach the bridge/projections through their declared dependencies. |

Use bounded `pump`/completion signals and controlled time, not sleeps, timing-budget inflation, or repeated flaky retries. Inspect `tester.takeException()` across the intermediate frame and after completion; a final `pumpAndSettle` alone can miss the temporary error widget. Capture unexpected async/provider errors as test failures rather than swallowing them.

For listener balance, distinguish a bridge build's legitimate revision increment from a service notification. Test one callback effect per known single notification after the generation has settled, not an arbitrary exact revision delta across all rebuilds. Prefer observable behavior over invasive test instrumentation.

Observe at least the focused regression failing on the unfixed code for the reported lifecycle mechanism, then passing with the fix, when practical under repository guidance. If reproduction differs, record what the test actually proves.

## 6. Verification and acceptance

Follow current `AGENTS.md` rather than treating these examples as a replacement for its gates:

```bash
# After creating the proposed regression file; adjust only to actual changed paths.
fvm dart format lib/core/backups/mitemite/providers.dart \
  test/core/backups/mitemite/provider_lifecycle_test.dart

fvm flutter test \
  --concurrency="$(python3 scripts/physical_core_count.py)" \
  test/core/backups/mitemite/provider_lifecycle_test.dart

fvm flutter test \
  --concurrency="$(python3 scripts/physical_core_count.py)" \
  test/core/backups/mitemite

git diff --check
```

Also format/analyze other touched files and run the relevant Bookmarks and Following consumer tests discovered during the call-site audit. Respect a configured concurrency override. If changing shared infrastructure beyond this subsystem or discovering unclear scope, broaden verification as required by the repository.

Before claiming readiness for develop integration, run the complete local suite from `docs/engineering_guidelines.md#complete-local-test-suite` on the final integration candidate. A targeted pass alone is not that gate. No merge is authorized by this handoff. No generated files should need changing unless actual inputs require it.

Device acceptance is supplemental when necessary: open Bookmarks containing received groups/aliases, navigate away/back, exercise supported service recreation and background/resume, and inspect both the screen and logs. Follow `docs/android_emulator.md` before device use. Do not move the fix onto #176 just to reproduce the original branch; any cross-branch acceptance must preserve that branch and be explicitly coordinated.

Acceptance means: no disposed-service assertion or transient error widget in covered transitions; fresh service notifications and relevant projections work after recovery; no lost persisted state, activation regression, duplicate ownership, or obsolete operational callbacks. Never claim an unperformed device check.

## 7. Local-agent completion report

Report the implementation branch and commit, the reproduced mechanism and any identified trigger, changed consumers, regression evidence, exact commands/results, and remaining limitations. Explain material deviations from the proposal. Commit all task changes and keep the documentation accurate; do not turn this handoff into a duplicate issue tracker. State explicitly whether checks establish only targeted correctness or also the complete integration gate, and whether any code was published under separate authorization.

## 8. Source references and remote limits

- [Develop provider ownership, bridge and projections](https://github.com/timberpile/Boorusama/blob/04fd511a895aabbf2c08d833cc1ce3473181621d/lib/core/backups/mitemite/providers.dart).
- [Original feature snapshot of the same provider file](https://github.com/timberpile/Boorusama/blob/026798566a6361f4b12038c2111954ddaf1fcf3d/lib/core/backups/mitemite/providers.dart).
- [Original feature snapshot's browser consumer](https://github.com/timberpile/Boorusama/blob/026798566a6361f4b12038c2111954ddaf1fcf3d/lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart).
- [Pinned Riverpod AsyncValue implementation examined in the initial investigation](https://github.com/khoadng/riverpod/blob/5a513c5aeee5a91d7cf5aa9a6e6a414b822bdee9/packages/riverpod/lib/src/common.dart).
- [Riverpod v2 disposal/recomputation semantics](https://docs-v2.riverpod.dev/docs/essentials/auto_dispose).
- [Existing service/consumer test setup](https://github.com/timberpile/Boorusama/blob/04fd511a895aabbf2c08d833cc1ce3473181621d/test/core/backups/mitemite/following_service_test.dart).

Remote preparation inspected source and the owner-supplied trace and published this handoff. It did not implement the fix, execute Flutter/Dart tests, reproduce on a device, or obtain an independent code review. Code sketches and test cases above are implementation guidance, not verified patches.

## 9. Local implementation and verification (2026-11-20)

Implementation continues on `bug/mitemite-service-lifecycle`, based on the
unchanged develop baseline `04fd511a895aabbf2c08d833cc1ce3473181621d` and the
published handoff commit `d96eed79a70eb4fa8199a7fe5095c14d01877c1d`.
Publication and develop integration were outside the original scoped handoff;
the subsequent owner approval and qualification are recorded in Section 10.

### Confirmed mechanism and consumer audit

The first controlled regression failed on the original production consumer:
explicit invalidation disposed service A, while the refreshing `AsyncValue`
still returned A from `valueOrNull`. Rebuilding `miteMiteChangesProvider` then
reported `A MiteMiteService was used after being disposed`. The final regression
file also covers dependency reloads, retained-data errors and retry, and the
real production factory's disposal and cancellation of obsolete initialization.
The exact trigger in the owner's session remains unknown. The audited production
call sites contain no explicit invalidation/refresh of the service provider;
its watched infrastructure, metadata, platform, and repository futures can
legitimately cause recomputation. Opening Bookmarks is not established as a
trigger, and no unnecessary production churn was demonstrated.

`currentMiteMiteServiceProvider` centralizes `unwrapPrevious().valueOrNull` and
owns no resource. The change bridge, published roots, Following presentation,
aliases, management projection, lifecycle, notification delivery, and Following
publisher labels use current instances. Management keeps the underlying async
loading/error UI while excluding retained service data. Explicit provider
dependencies, existing lazy guards, and stable collection projections remain.

Action callbacks recheck captured service identity when invoked and after
initialization, pickers, dialogs, or further async work. This includes
publication/subscription management, aliases, local copies, and read/definition
acknowledgements. A stale action exits without borrowing a replacement's
identity or trust. Skipped viewer acknowledgements remain eligible for retry.
Offer-exit acknowledgement is intentionally different: it must outlive route
disposal, so it captures the owning container and checks current service identity
there. A page-context mounted check suppressed this existing behavior; the
Subscriptions NEW consumer regression detected it and verifies the correction.

A separate controlled widget regression failed when a post-frame startup
callback ran after A's disposal but before the lifecycle widget rebuilt.
Scheduled operations now verify the attached service against the current source;
startup callbacks also verify their captured instance. In-flight bookkeeping
belongs to its service generation, so A's completion cannot clear B's work or
schedule follow-up work for B. Poll/debounce cancellation and watcher callbacks
retain their existing policy. Listener removal and `setForeground(false)` remain
cleanup: the latter only updates elapsed foreground accounting and performs no
I/O. The source provider remains the sole disposal owner.

The new tests use real coordinated Hive bookmark storage, completion gates, and
virtual timer advancement. They exercise the real browser's conditional alias
subscription with persisted received groups/reading metadata and aliases, and
check framework exceptions during replacement as well as after recovery. The
scope also covers repeated listener effects, parent/child overrides, inactive
sync, a pending local-change debounce, held transport initialization, polling,
unmount, and obsolete edit dialogs. No persisted format, migration, SDK,
Riverpod version, or transport scheduling policy changed.

### Checks and limits

Checked source: the implementation and regression tree committed with this
report; only this outcome documentation was edited after final runtime checks.
Ordinary tests used six workers, as detected by
`python3 scripts/physical_core_count.py`.

- Before the fix, `fvm flutter test --no-pub --concurrency=6
  test/core/backups/mitemite/provider_lifecycle_test.dart` failed on the disposed
  listener mechanism. After the projection, the focused file passed; the
  expanded file passed all 13 lifecycle regressions.
- The controlled obsolete-startup regression also failed before its generation
  guard. Its passing version is included in the final consumer run.
- `fvm flutter test --no-pub --concurrency=6
  test/core/backups/mitemite/bookmark_mirror_engine_test.dart --plain-name
  'Subscriptions NEW stays through its first visit and late offers survive
  successful exit at 320dp enlarged text'`: 1 passed after the route-exit
  correction. The original consumer run had caught that correction's need.
- Final affected-directory command: `fvm flutter test --no-pub --concurrency=6
  test/core/backups/mitemite test/core/bookmarks
  test/core/search/following_topics`: exit 0, 2,279 passed, no failures or skips.
  This final run includes all 13 lifecycle regressions and the corrected
  offer-exit consumer; no runtime or test source changed during this run.
- `fvm dart format` on all 12 changed source files and the new regression file:
  final `--output=none --set-exit-if-changed` check passed with no changes.
- `fvm flutter analyze --no-pub --no-fatal-infos` on those same 13 files:
  exit 0, no errors, no warnings, 105 informational lint findings. This is not a
  clean-lint claim; informational findings remain visible in the log.
- `git diff --check`: passed.

Durable local logs are in the ignored
`.worktrees/_artifacts/mitemite-service-lifecycle/` directory, including
`regression-before.log`, `lifecycle-startup-before.log`,
`offer-exit-regression.log`, `consumer-suites-final.log`, and `analyze-final.log`.
At that scoped handoff, device/live-service acceptance and the complete local
integration suite had not been run; Section 10 records the subsequent full pass. The original device sequence and native directory-watcher integration
remain unverified; these provider/widget checks establish targeted lifecycle
correctness, not develop-integration readiness. No implementation was pushed,
no PR or issue was created/closed, and no work was performed on the viewer branch.


## 10. Develop integration qualification (2026-11-20)

The owner approved integrating both fixes with “passt so, kannst mergen”.
The approved task tip was `f30a23d352c9cc08f37e1821fd8b6d8a107d6e1e`.
Its four commits rebased cleanly onto current `origin/develop` at
`5b17615346d2a162ebe287e400e97c60aa666798`; `git range-diff` reported every
patch unchanged. The resulting runtime/test candidate was
`41e2b3facc45a5bd120bf07c4be4c178bfb69f90`. No runtime, dependency, test, or
tracked generated-code input changed during or after qualification; subsequent
handoff edits are documentation only.

The develop base already includes the unified Group viewer. Its changed English
translation inputs required `./gen.sh i18n`, which completed successfully before
the full suite. Existing scope, service/source ownership, cancellation, error
presentation, and sync behaviour were reviewed against the combined candidate.
The primary checkout and unrelated task branches/worktrees were preserved.

Complete local verification used six workers from
`python3 scripts/physical_core_count.py`:

```sh
./scripts/run_regression_tests.sh
```

The completed pass has durable `REGRESSION_EXIT=0` evidence:

- Application: **7,996 passed**, no skips.
- All **13** package/CLI suites: **1,730 passed**, two existing skips in
  `packages/go_router`. The skipped cases are the fragment-based redirect-only
  route and `canPop` returning false when `Navigator.canPop()` returns false.
- `.github/scripts/test-pull-request-policy.sh`: passed.
- `.github/scripts/test-android-release-scripts.sh`: passed.
- `python3 -m unittest discover -s scripts/tests`: **76 passed**.
- All 16 changed Dart files: formatting unchanged with
  `fvm dart format --output=none --set-exit-if-changed`.
- `fvm flutter analyze --no-pub --no-fatal-infos` on those same files: exit 0,
  **0 errors, 0 warnings, 107 informational findings**; this is not a clean-lint
  claim.
- `git diff --check`: passed. The worktree was clean throughout the completed
  runtime check.

The earlier test/analyzer processes were interrupted by the execution
environment and have no completion proof; those partial results were not reused.
The unchanged candidate was checked again in full, with analysis performed
separately afterward. Durable evidence is retained outside the disposable task
worktree under `.worktrees/_artifacts/mitemite-integration-20261120/`:
`generate-i18n.log`, `regression-final.log`, `format.log`, and `analyze-final.log`.

The approved integration uses one Conventional Commit on develop. Its tree must
match the final task tree exactly before publication; the documentation-only
qualification updates do not require repeating the runtime suite. No GitHub
issue is associated with these two scoped fixes. Device/native-watcher and
authenticated live-service acceptance were not performed; the original session's
precise invalidation trigger remains unknown.
