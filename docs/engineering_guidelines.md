# Engineering and verification guidelines

Consult relevant sections when the current change needs additional engineering
conventions. [AGENTS.md](../AGENTS.md) defines workflow routing and required
verification; issue and integration guidance is loaded only when needed.

## Tools

- Always use `fvm` for `flutter` and `dart` commands. Run tests with
  `fvm flutter test`.
- Run `./gen.sh` to generate i18n, language configs, and booru client configs
  when those inputs change. In a fresh worktree, first run `fvm dart pub get`
  from `packages/boorusama_cli` before the first generation. Consult
  [build troubleshooting](build_troubleshooting.md) for the repeated native
  build warning.
- Use an Android emulator only when device/UI integration is necessary. Follow
  [lease procedure](android_emulator.md) and use Maestro MCP for UI control.
- Sample related code before writing new code so changes follow existing
  patterns. Run `fvm dart format` after creating or editing Dart files;
  batch formatting where practical.

## Scope-appropriate verification

During implementation, run relevant tests, format changed Dart files with
`fvm dart format`, and analyze affected code when useful. Expand the checks when
a change crosses a meaningful boundary; prefer the broader check if scope is
uncertain.

| Change | Required local checks |
| --- | --- |
| Documentation, issue metadata, comments, or other non-runtime-only files | Relevant documentation/tooling checks (for example, links and `git diff --check`); no Flutter/application suite. Executable scripts and configuration that alter runtime/build/test behavior are not documentation-only. |
| Clearly scoped application feature/fix | Directly affected test files or an entire affected directory, plus nearby/consumer tests when shared behavior is affected. Unrelated subsystems/packages need not run for local task verification. |
| Local package | That package's complete suite, plus relevant application/other-package consumer tests. |
| Broad/shared infrastructure or unclear scope | Complete local suite. This includes shared core models, dependencies/toolchain, generated-code infrastructure, test infrastructure and repository-wide behavior. |

For example, run affected application files with
`fvm flutter test --no-pub --concurrency="$(python3 scripts/physical_core_count.py)" <test-paths>` and package tests from
that package's directory. These checks establish local task confidence. State
which checks ran and whether integration verification is still pending.

### Selecting a feature, file or package

There is no separate test-module registry. Application features group tests in
folders under `test/`, and local packages have their own `test/` folders.
`fvm flutter test` from the repository root runs the application tests; it does
not automatically run every package. A path argument narrows discovery to that
file or directory (including descendant test files).

From the repository root, detect workers once for this shell:

```bash
test_workers="$(python3 scripts/physical_core_count.py)"
# Bookmark feature only
fvm flutter test --no-pub "--concurrency=$test_workers" test/core/bookmarks
# One file only
fvm flutter test --no-pub "--concurrency=$test_workers" test/core/bookmarks/bookmark_provider_test.dart
# Two affected feature directories
fvm flutter test --no-pub "--concurrency=$test_workers" test/core/bookmarks test/core/search
```

Use `--plain-name 'part of a test name'` with a file path to narrow a diagnostic
check to matching cases. Case-filtered checks do not replace the relevant whole
file/package checks when those are required.

Packages are separate test roots. For example:

```bash
(cd packages/cache_manager && fvm flutter test --no-pub "--concurrency=$test_workers")
(cd packages/filename_generator && fvm dart test "--concurrency=$test_workers")
```

Concurrency limits how many test files run at once, rather than parallelizing
all cases inside one file. Raising it usually offers little benefit for a
single-file check. Default ordinary Flutter and Dart test commands to detected
available physical cores, with at least one worker. On Linux the helper counts
unique socket/core identities within process CPU affinity; on macOS it queries
`hw.physicalcpu`. SMT siblings count once; non-SMT cores are not halved. Unknown
or incomplete topology conservatively uses one, with an explicit override for
constrained or unsupported environments.

To request a narrow check from an agent, say, for example, "Run the bookmark
feature tests and any directly affected consumer tests", or name
`test/core/bookmarks` explicitly. Local targeted verification and the complete
pre-integration gate remain separate.

## Complete local test suite

A complete local regression pass is mandatory before a task is considered safe
to integrate into `develop`. Run it once against the final integration candidate,
including its combination with the current develop base. Targeted verification
proves the task locally; full verification proves the integration candidate.
Broad/infrastructure changes also require this full check for local handoff.

Run from the task worktree, using its pinned FVM SDK and generated outputs:

- Application: `fvm flutter test --no-pub "--concurrency=$test_workers"` from the
  repository root, where `test_workers="$(python3 scripts/physical_core_count.py)"`.
- Every package with `test/**/*_test.dart`, including `packages/boorusama_cli`:
  run its complete suite from that package directory. Use
  `fvm flutter test --no-pub "--concurrency=$test_workers"` for Flutter packages
  and `fvm dart test "--concurrency=$test_workers"` for Dart-only packages; do not filter by path or test name.
- Repository tooling, from the repository root:

  ```bash
  .github/scripts/test-pull-request-policy.sh
  .github/scripts/test-android-release-scripts.sh
  python3 -m unittest discover -s scripts/tests
  ```

`./scripts/run_regression_tests.sh` runs all these commands serially and stops
on failure. It excludes the opt-in workloads under `benchmark/`. The default is
available physical core count for both application and package/CLI tests (six
on the measured 6-core/12-thread host). Use
`TEST_CONCURRENCY=2 ./scripts/run_regression_tests.sh` for an explicit override.
The release CI application and CLI commands use the same detector; CI coverage
and authorization rules are unchanged.

The earlier fixed-four recommendation addressed a share-copy test that assumed
native I/O finished within 150 ms. Its checks now await completion and lease
release, and timing contracts use controlled clocks where practical. Historical
concurrency measurements were host-specific; they do not justify a global
fixed worker count. Retired experiment records remain in Git history.

Inspect every result. A failed, skipped, or unrun suite does not satisfy the full
requirement; report existing individual test skips separately. Fix in-scope
failures and rerun affected checks; before integration the final candidate still
needs a complete pass. Targeted tests and CI do not replace this local gate.

A complete pass already checking the same integration candidate can be reused
when another agent takes over. Documentation, status, or report-only updates do
not invalidate it and must not trigger another application suite. Relevant code,
tests, dependencies, generated runtime output, or a changed combined develop
candidate require appropriate re-verification, including a complete pass on the
new final candidate before integration. Formatting/comments with no behavior
change need only relevant direct checks.

Record the checked commit/state, executed commands, results, skips and limits in
the normal task report or handoff. Do not add result caches, hashes or verification
metadata systems. Distinguish local tests from CI, device and upgrade acceptance;
report blockers without claiming integration readiness. Authorization to merge
or publish is separate from successful verification.

## Opt-in workload benchmarks

The high-volume tests under `benchmark/` remain outside ordinary application
discovery. Run `./scripts/run_test_benchmarks.sh` only when investigating post
snapshot serialization, bookmark cold loads, or following-feed deserialization.
It uses the pinned FVM SDK and concurrency one. These diagnostic workloads and
loose duration guards do not replace functional regression tests or constitute
stable performance budgets; compare repeated same-host measurements.

## Code style

- For Riverpod, use `Notifier`/`AsyncNotifier` and manually declared
  providers; do not use code generation.
- Prefer factory methods or constructors for complex setup. Put constructors
  at the top of a class.
- Put business logic in state classes or dedicated files, not widgets.
- Never hardcode user-facing text. Add it to i18n resources and access it
  through `BuildContext` with `context.t`.
- Use `equatable` for value equality when needed.
- Use pattern matching to make code more readable; use traditional
  `if`/`else` only when it improves readability.
- Treat external data as nullable and handle null cases explicitly.
- Comment only non-obvious logic or decisions, not what the code already says.

## UI consistency

Inspect comparable screens and interactions before implementing UI. Reuse existing
application components and their spacing, typography, sizing, and behavior. Prefer
`KurumiAnchor`, `KurumiPopupMenuItem`, and `KurumiContextMenu` for menus; keep row
styling consistent within a popup rather than mixing Material and Kurumi items.
Make deviations intentional and explain why they are needed.

Use `KurumiAppBar` and `KurumiSliverAppBar` for application toolbars. They fit
plain `Text` titles to the existing toolbar height and available width, retaining
fewer lines unless wrapping increases the rendered font size by at least 50%.
Each candidate fits the full title within its actual constraints, down to 12 sp;
only titles that cannot fit at that floor use a multiline ellipsis. They
preserve the original text scaler without restoring removed status-bar padding.
For compound titles, put each text label in `KurumiFittedText` with bounded
constraints (for example, inside `Flexible` in a `Row`); keep icons, buttons, and
editable search fields as controls. The toolbar preference is inherited by these
labels; outside toolbars (including bookmark cards), `KurumiFittedText` keeps
maximizing the fitting wrapped font size. These components are exported by Kurumi.

## Tests

- Focus on observable behavior rather than implementation details.
- Keep functional tests independent of host speed and parallel scheduling. Use
  fake/injected clocks to assert exact timeout, cooldown, debounce or pacing
  behavior; use completers, events and explicit gates for async ordering.
- Await observable completion instead of sleeping for an assumed duration.
  Native I/O/widget decoding can use a bounded condition wait when no completion
  signal is exposed. Its timeout is a generous hang guard, not a latency budget.
- Preserve meaningful timing and cancellation coverage. Do not hide flakes by
  increasing fixed sleeps, retrying whole tests, deleting assertions or excluding
  tests. A timeout can be reevaluated as a hang guard when held work/state proves
  the behavioral contract independently of elapsed wall time.
- Keep strict elapsed-time budgets in explicitly justified performance tests,
  normally opt-in benchmarks with controlled conditions. Exercise changed async
  fixtures under the normal physical-core concurrency and relevant stress settings.
- Mock or stub external dependencies only; avoid mocking internal logic.
- Keep tests minimal and logically grouped. For repeated scenarios, use a loop
  over explicit test-case records with one `test()` per case.
- Do not test trivial language behavior, one-line getters/setters, or
  redundant validation. Protect meaningful logic and edge cases.
- Write clear sentence-style test names describing behavior and outcome,
  without function or class names.

For example:

```dart
final cases = [
  (input: 'valid@email.com', isValid: true),
  (input: 'invalid-email', isValid: false),
];
for (final c in cases) {
  test('returns ${c.isValid} for ${c.input}', () {
    expect(validate(c.input), c.isValid);
  });
}
```

## Persistent project knowledge

Project knowledge belongs under `docs/`. Read relevant subsystem documentation
when it materially affects the task. Update it within the requested scope when
you discover non-obvious information that would save significant investigation:
architectural constraints, unexpected framework behavior, important decisions
and rationale, build/tooling quirks, or unsuccessful approaches worth avoiding.
Do not store source-obvious facts, temporary debugging observations, or
speculation.
