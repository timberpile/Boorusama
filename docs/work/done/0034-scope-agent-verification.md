# 0034 — Scope agent verification and measure Flutter concurrency

| Field | Value |
| --- | --- |
| Priority | Normal |
| Agent/session | Codex, 2026-10-14 |
| Branch | `agent/scoped-verification-workflow` |
| Worktree | `.worktrees/scoped-verification-workflow` |
| Status | Done, locally verified and squash-integrated into local develop; unpublished |
| Base | Current local `develop`, `212ef77da4383249d068479c0219445a60cc53ee` |

## Goal and constraints

Use scope-appropriate verification during development and one mandatory complete
regression check on the final integration candidate. No result caches, dependency
graphs, schedulers, or verification metadata systems. Preserve meaningful tests
and opt-in diagnostics. Delivery is local; no merge, push, or PR is authorized.

## Acceptance criteria

- [x] AGENTS, engineering guidance and repository skills agree on scope-based checks.
- [x] Documentation/status-only edits do not trigger application tests or invalidate
  an already checked runtime candidate; relevant runtime/test/dependency changes do.
- [x] All application, package, CLI and tooling suites remain mandatory before develop
  integration, with reuse permitted for the same already verified candidate.
- [x] Compare concurrency 2/4/6 and the requested follow-up 8/10/12 on one fixed
  code state with two warm runs each;
  record failures, wall time and readily available peak memory.
- [x] Compare the selected main feature folders and Flutter packages at two versus
  six, and explain how users select a feature, file, case or package.
- [x] Keep workload benchmarks opt-in and perform no speculative test cleanup.
- [x] Directly verify documentation/runner changes and complete initial full regression.
- [x] Default ordinary application/package/CLI tests to available physical cores.
- [x] Reevaluate timing-sensitive tests and add durable implementation/review guidance.
- [x] Verify the final continuation with parallel stress and the full required suite.

## Progress

The sections labeled historical/initial describe the completed first delivery.
The user subsequently requested physical-core concurrency and reevaluation of
strict timing tests; that continuation is recorded below.


- Current develop lacks the unmerged TEST-001 cleanup. Carry forward only its
  three workload relocations and unchanged opt-in runner, using current source
  contents and adjusted helper imports; other TEST-001 optimizations are excluded.
- AGENTS, engineering guidelines, integration workflow and all six repository
  skills now use the same scope rules. Release delivery retains full qualification.
- Added a small serial regression runner with complete package/CLI discovery and
  fail-fast behavior; no selector, cache, scheduler or verification metadata.
- Direct checks passed: both shell scripts parse, runner stub checks cover
  application/Dart/Flutter/GraphQL package discovery, tooling order, fail-fast
  application/package/tooling failures, calls from outside the checkout, and
  benchmark separation; 26 relative documentation link targets resolve.
- Relocated benchmarks format without changes. Their source contents match the
  base byte-for-byte except for the two helper import paths.
- Six warm comparison runs passed without failures or skips. The initial full
  regression passed at concurrency six. The requested 8/10/12 extension and
  module comparisons are complete. A later complete application run at six
  hit the same share-copy flake; final qualification at four passed every
  required suite with zero skips.

## Concurrency measurement method

Same initialized worktree and fixed application/test/dependency state, pinned
FVM Flutter 3.47.2 / Dart 3.13.2, Linux host reporting 12 logical CPUs and about
19.5 GiB RAM. One full cold warm-up at concurrency two is excluded from the
comparison. Six serial warm application runs use concurrency 2/4/6/6/4/2 with
`fvm flutter test --no-pub --concurrency=N --reporter=json`; no simultaneous
suite or benchmark commands. Command wall time includes startup, compilation,
loading and teardown, plus small reporter-log parsing overhead in the temporary
driver. Shared-host load remains uncontrolled noise.

GNU `/usr/bin/time -v` records maximum process/child RSS, not the aggregate
memory used by concurrent processes. This readily available number is a limited
resource indicator; no memory profiler or background monitoring is introduced.
Raw JSON reporter logs, timings and the temporary measurement driver stay under
`/tmp/boorusama-concurrency-study*`. Results are recorded here in normal
work-item tables, not a verification database or cache.

## Historical concurrency results and initial decision

Each of the six initial warm 2/4/6 runs executed the same 3,271 application
cases, with zero skipped or failed cases and exit status zero. No timeout, OOM, or worker/process failure was reported. The cold warm-up passed in 478.80 seconds and is excluded below.

| Concurrency | Warm run 1 seconds | Warm run 2 seconds | Median seconds | Peak process RSS GiB (runs) |
| --- | ---: | ---: | ---: | ---: |
| 2 | 362.02 | 357.34 | 359.68 | 1.544; 1.541 |
| 4 | 214.52 | 213.87 | 214.19 | 1.527; 1.542 |
| 6 | 178.12 | 181.48 | 179.80 | 1.542; 1.541 |

Before fixing the timing-dependent fixture, chose **four workers for the local full application suite**. The two warm
comparison runs at four passed in 214.52 / 213.87 seconds, a median 40% below
two. Six was faster in both warm runs and passed an initial complete regression,
but a later complete application run at six failed the same load-sensitive
share-copy case seen above six. The final default therefore favors four's
clean observed comparison runs over six's inconsistent later result.

That initial policy kept Flutter packages at two workers, Dart packages at
their defaults, and CI unchanged. It is superseded by the physical-core policy
below; the old root-only `APPLICATION_TEST_CONCURRENCY` override is replaced
by `TEST_CONCURRENCY` for every application/package runner.

The limited RSS measure does not establish equal aggregate memory consumption
across worker counts. Two warm repetitions per value do not prove absence of
future flakiness. Shared-host load and compilation/decoder timing still add noise;
the user subsequently requested two warm samples each at 8, 10 and 12 workers.
Those ran serially in order 8/10/12/12/10/8 after the initial complete regression
check; the application/test/dependency state stayed unchanged. The extension
and subsequent final gate informed the choice without statistical benchmarking.

## Requested extension: 8, 10 and 12 workers

Two further warm runs per value use the same application/test/dependency state
and JSON reporter, serially in order 8/10/12/12/10/8. All execute 3,271 cases
with zero skips. Failed runs remain visible below; their durations are not
accepted as successful-suite speedups.

| Concurrency | Run 1 seconds | Run 2 seconds | Passing runs | Failed cases by run | Peak process RSS GiB (runs) |
| --- | ---: | ---: | ---: | --- | --- |
| 8 | 170.56 | 180.37 | 1/2 | 1; 0 | 1.543; 1.574 |
| 10 | 171.27 | 169.45 | 1/2 | 1; 0 | 1.560; 1.578 |
| 12 | 168.24 | 166.83 | 1/2 | 1; 0 | 1.562; 1.549 |

Each setting failed once on `share_original_copy_test.dart`, case "copying
Original prepares the exact image and reports success": the `Copied` toast was
absent at the assertion after a fixed 150 ms real-time wait. Each setting also
passed once. Three subsequent isolated concurrency-one rechecks of that exact
case passed (7.38 / 6.87 / 6.88 seconds). This is consistent with load-sensitive
fixture timing; the comparison does not prove causation or a production defect.
No test scenarios/assertions were changed during those measurements. No OOM, timeout or worker
crash was reported; aggregate concurrent memory was not measured.

Higher settings show only small duration reductions and inconsistent runs.
Six passed both warm measurements and an initial complete regression, but a
later run against the corrected wrapper failed this same toast assertion
(178.38 seconds; 3,270 passed / one failed; package/tooling execution correctly
stopped). This additional evidence invalidated the provisional choice of six.
**Four was used for the initial final qualification.** The failed six-worker run
is retained at `/tmp/boorusama-corrected-final-regression.log`; extended raw
artifacts remain under `/tmp/boorusama-concurrency-extended*`.

## Requested module comparison

The user selected the seven main application feature groups (backups, bookmarks,
posts, search, bulk downloads, settings and site-specific tests) plus all six
Flutter packages. Each gets one warm run at the current targeted/package setting
of two, and one at six; pair order alternates to reduce systematic order bias.
Commands run serially. This is a simple diagnostic comparison, not a statistical
benchmark. Dart-only packages already default to six on this host (confirmed with
`fvm dart test --help`), so identical settings are not run twice.

| Module path | Cases per run | Current (2) seconds | Six seconds |
| --- | ---: | ---: | ---: |
| `test/core/backups` | 556 | 76.70 | 56.47 |
| `test/core/bookmarks` | 336 | 34.26 | 23.97 |
| `test/core/posts` | 641 | 86.87 | 44.00 |
| `test/core/search` | 563 | 87.51 | 44.50 |
| `test/bulk_downloads` | 102 | 19.21 | 16.86 |
| `test/settings` | 95 | 16.71 | 11.77 |
| `test/boorus` | 148 | 16.24 | 11.45 |
| `packages/booru_clients` | 76 | 7.85 | 6.32 |
| `packages/cache_manager` | 56 | 10.73 | 8.12 |
| `packages/extended_image` | 47 | 5.07 | 4.55 |
| `packages/flutter_sqlite3_migration` | 45 | 2.96 | 2.73 |
| `packages/foundation` | 65 | 3.13 | 2.66 |
| `packages/kurumi` | 83 | 5.97 | 4.78 |

All 26 module commands passed with zero failures/skips. Large folders (especially
posts and search) benefited materially in this single paired sample. Package
reductions ranged from 0.23 to 2.61 seconds; startup/loading and single-sample
noise limit confidence in small differences. The initial recommendation kept targeted Flutter/package
checks at two and suggested six for larger directories. The subsequent
physical-core policy below supersedes that recommendation. There is no per-module configuration or automatic selection.
A single-file check cannot gain file parallelism from a larger worker limit.

The engineering guide now includes copyable commands for a feature directory,
one file, multiple directories, named-case diagnostics and standalone packages.
Ordinary English requests naming a feature are sufficient; agents select the
paths and relevant consumers while leaving full integration qualification
separate.

Raw logs and focused rechecks are in `/tmp/boorusama-module-comparison`; progress
is `/tmp/boorusama-module-progress.log`.

A direct wrapper check uncovered a false-success path when package discovery
returned an error. The wrapper now distinguishes no matching test files (exit
one) from discovery errors, and propagates manifest-check errors. Behavioral
checks confirm discovery failures stop the gate. The final complete pass on the corrected runner at four succeeded; the initial
full pass at six was not substituted for verification of these script changes.

## Implemented workflow

- Documentation/status/comments-only work: relevant direct checks, no application
  suite. Updating this report after verification does not trigger another run.
- Scoped application work: affected files/directories and meaningful consumer
  boundaries; package work: the whole affected package and relevant consumers.
- Broad shared/infrastructure/test/toolchain changes or unclear scope: full suite.
- Before develop integration: a full application + all package/CLI + tooling
  pass on the final combined candidate. A pass already checking that candidate
  survives handoffs and documentation-only updates; relevant runtime/test/
  dependency or develop-combination changes require a new qualification.
- Normal task reports record checked state and commands; no caches, graphs,
  databases, hashes or background scheduling are introduced.
- `scripts/run_regression_tests.sh` is a simple serial fail-fast command wrapper.
  Opt-in benchmarks remain separate. No test scenarios/assertions are removed.

## Initial verification (commit `f174d90eb`)

- `fvm dart format benchmark`: three files, zero changes.
- `fvm flutter analyze --no-pub --no-fatal-infos benchmark`: passed, no issues.
- `bash -n scripts/run_regression_tests.sh scripts/run_test_benchmarks.sh`: passed.
- Temporary runner behavioral checks: package discovery and SDK choice, failure
  propagation, external working directory, tooling order, manual concurrency
  override, benchmark separation, discovery errors and manifest errors all
  passed. ShellCheck is unavailable.
- `./scripts/run_test_benchmarks.sh`: four cases passed (9.45 seconds).
- Final `./scripts/run_regression_tests.sh`: **passed all 16 required suites in
  300.70 seconds** at application concurrency four: 3,271 application,
  934 package/CLI, 34 shell policy/release and 50 Python tooling cases (4,289 total),
  zero skips. The checked state is the final task diff on base
  `212ef77da4383249d068479c0219445a60cc53ee`, including the corrected discovery/
  manifest error handling, four-worker application default, two-worker Flutter
  package default, and unchanged benchmark relocations. Only documentation and
  status were updated afterward; this pass is reused without another app run.
- Initial full pass at six: 4,289 cases / zero skips in 319.79 seconds. Subsequent
  corrected-wrapper application run at six failed as recorded above; the final
  pass at four qualifies the delivered state.
- All 26 module comparison commands and three isolated toast rechecks passed.

- Raw final analysis, benchmark and regression logs are
  `/tmp/boorusama-final-{analysis,benchmarks,regression}.log`; command wall times
  and exits are in `/tmp/boorusama-final-results.json`. Final four-worker proof is
  `/tmp/boorusama-final-c4-regression.log` and `/tmp/boorusama-final-c4-result.json`.

No remote CI, Android JVM/device/instrumentation or upgrade execution is claimed:
there are no native or application runtime changes. Local develop and unrelated worktrees stay
untouched; merge, push and PR creation remain unauthorized.


## Follow-up: physical cores and scheduling-independent tests

The user replaced the fixed concurrency recommendation with available physical
core count, and asked for strict timing tests to be reevaluated. This host has
six physical cores / twelve logical threads. `scripts/physical_core_count.py`
counts unique socket/core identities among CPUs in Linux process affinity;
macOS uses `sysctl hw.physicalcpu`. Unknown/incomplete topology falls back to
one, rather than assuming every CPU exposes two SMT threads.

`run_regression_tests.sh` now passes this count to every application, Flutter
package and Dart package/CLI command. `TEST_CONCURRENCY=N` overrides all these
commands and must be a positive integer. Release CI application/CLI commands
use the same detector; CI suite coverage is unchanged. Benchmarks stay opt-in
and serial. Eleven new tooling cases cover topology, affinity, platform/fallback
behavior, override validation, package propagation and fail-fast handling.

### Timing audit and retained coverage

| Area | Evidence / change | Retained contract |
| --- | --- | --- |
| Original-image copy and video-link copy widgets | Full-suite failures followed a fixed 150 ms wait. Replace fixed 100/150/200/650 ms completion guesses across four share files with observable completion/progress signals and bounded pumping. Await `Copied` and the action becoming enabled again before checking cleanup. | Exact image bytes/path/MIME, cache removal, staging cleanup, noncancellable clipboard phase, busy/progress UI, unsupported-media behavior. |
| Rate limiter | Six cases used real elapsed upper bounds of 50/200 ms and lower bounds of 80/500 ms. Inject a clock (default remains `DateTime.now`) and use fake timers to check no delay or the exact delay, including one millisecond before/at release. | Resolver bypass/application, default POST throttling, expired timestamp cleanup, maximum delay and window capacity. All six scenarios remain. |
| API HTML transport | A 200 ms bound could expire under load and its broad catch could swallow the timeout. Use a five-second hang guard and explicitly rethrow `TimeoutException`. | HTML routing still must complete before the guarded await; genuine timeout fails the test. |
| API request safety and subscription hydration | Four 250 ms deadlock guards become five-second guards. | Explicit starts, deferred completions and state assertions still establish ordering/concurrency independently of host speed. |
| Pending cached-media cancellation | A 300 ms guard becomes five seconds; the pending cache future stays held until cleanup. | Cancellation must finish before the cache lookup is released, rather than merely finish quickly. |
| Other API admission/authentication/hydration/provider/grid checks | Existing one-to-five-second guards, held work and state/completion checks inspected and retained. | Deadlocks still fail; no unsupported blanket timeout increase. |
| Simulated latency / product timeout configuration | Slow stream fixtures, Dio timeout test data, cooldown/debounce/pacing semantics retained. | Behavior involving time remains protected. |
| Extended workloads / tooling / native host fixtures | Benchmark loose ten-second budgets and 30/45-second runner guards, export two-minute guard, Python subprocess guards, deliberate emulator-lease expiry ordering and Android transfer latch guard retained. | Benchmarks remain serial/optional; functional/tooling ordering and native hang protection remain. |

No test is removed, skipped or excluded by this follow-up. The optional production
clock seam is the only application change; default runtime behavior is unchanged.
The share helper's ten-second limit is a hang guard for real native I/O/widget
work and returns immediately when the required condition is met, rather than
adding a larger fixed sleep. Existing meaningful product progress timers remain.

### Test-authoring guidance

There is no standalone repository test-writing skill. `implement-change` is the
normal implementation workflow, including tests; `debug-issue` handles failures.
Both now require controlled clocks and completion/ordering signals instead of
host-speed assumptions, preserve timing/cancellation contracts, and exercise
changed fixtures with ordinary parallel settings. `execute-plan` and
`verify-change` receive matching implementation/review guidance. AGENTS and the
engineering guide explain the shared policy and copyable module commands.
Superpowers TDD is available separately; it is not part of the default repository
workflow and was not modified.

### Follow-up verification

- Final format: ten affected Dart files, zero changes.
- Affected analysis: no warnings/errors; one pre-existing informational lint in
  the subscription test (`avoid_redundant_argument_values`, unchanged line).
- Final focused run at concurrency twelve: 70 cases passed in 12.56 seconds.
- Complete application stress at concurrency twelve: **3,271 cases passed,
  zero skips/failures, 171.77 seconds**. This includes the formerly load-sensitive
  copy fixture under the full workload. It is one post-fix stress sample, not proof
  that no future flake can occur.
- CPU detector: six here; all seven topology/platform cases pass. All four
  behavioral regression-runner cases pass. Both runner shell scripts parse;
  workflow YAML parses, both CI command shells parse and their root/CLI-relative
  detector paths return six. Twenty relative guidance links resolve.
- Final `./scripts/run_regression_tests.sh`: **all 16 required suites passed in
  274.46 seconds**, with six workers for every application/package/CLI command.
  Counts: 3,271 application + 934 package/CLI + 34 shell policy/release + 61 Python
  tooling = **4,300 cases, zero skips/failures**. The eleven added tooling cases
  explain the increase from the initial 4,289; no existing cases were removed.
  Checked state is the final continuation diff on `f174d90eb`, on develop base
  `212ef77da4383249d068479c0219445a60cc53ee`. Only documentation/status updates
  follow this pass; they do not invalidate runtime verification.
- Observed end-to-end full-gate duration: initial fixed-four-root/two-Flutter-
  package gate 300.70 seconds; final physical-six gate 274.46 seconds. These are
  individual samples with different fixture/worker settings and shared-host
  noise; they do not establish a controlled whole-suite speedup. Historical
  comparable repeated application measurements and module pairs remain above.
- Optional `./scripts/run_test_benchmarks.sh`: all four cases passed at
  concurrency one in 9.37 seconds. Ordinary suite discovery still excludes them.
- No remote CI or macOS hardware execution, device/instrumentation test or
  publication was performed. macOS detection is unit-tested; live topology
  verification covers this Linux host. No merge/push/PR is authorized.

Raw follow-up outputs remain under `/tmp/physical-core-{format,analysis,targeted-12,application-12,full-physical}.log`.


### Remaining application hotspots

The twelve-worker stress JSON reporter identifies these longest per-file spans
(first visible case start to last case completion). They overlap across files,
include scheduling/waits and are diagnostic hotspots, not additive suite totals
or controlled per-file benchmarks. No new exclusions are justified by this sample.

| File | Cases | Visible-case span seconds |
| --- | ---: | ---: |
| `test/core/search/subscriptions/pinned_searches_page_test.dart` | 60 | 24.32 |
| `test/core/posts/shares/gif_ffmpeg_backend_test.dart` | 16 | 22.95 |
| `test/core/search/subscriptions/following_feed_management_page_test.dart` | 13 | 22.52 |
| `test/core/posts/details/mixed_post_details_page_test.dart` | 44 | 21.89 |
| `test/core/search/subscriptions/search_page_pin_action_test.dart` | 50 | 20.86 |

The historical module pairs already show where directory-level parallelism helps;
this follow-up targets reliability, not a statistically established speedup. Do
not compare a single post-fix stress sample against the historical table as proof
of a timing improvement. Shared-host load and changed fixture/worker settings
limit whole-suite before/after attribution.


## Authorized local integration

On 2026-10-14 the user authorized the local merge. Squash integration uses the
unchanged develop base `212ef77da4383249d068479c0219445a60cc53ee` and approved
source `dc36acc0de0d6f38110cb95dd135b7c5072a245c`. The staged integration tree
matched the source exactly before this documentation-only integration record.
The complete 4,300-case pass and four optional benchmark cases above therefore
qualify the same runtime/test candidate; no duplicate application run is needed.
Only this status/report changes afterward. Nothing is pushed or published.
