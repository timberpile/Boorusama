# Engineering and verification guidelines

Consult relevant sections when the current change needs additional engineering
conventions. [AGENTS.md](../AGENTS.md) defines workflow routing and required
verification; queue and integration documentation are loaded only when needed.

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

## Complete local test suite

After the final edit, run all of the following locally before final review or
handoff. Keep focused checks during implementation; they do not replace this
final run. Run from the task worktree, using the pinned FVM SDK and generated
outputs required by that checkout.

- Application: `fvm flutter test --no-pub --concurrency=2` from the repository root.
- Every package with `test/**/*_test.dart`, including `packages/boorusama_cli`:
  run its complete suite from that package directory. Use
  `fvm flutter test --no-pub --concurrency=2` for Flutter packages and
  `fvm dart test` for Dart-only packages; do not filter by path or test name.
- Repository tooling, from the repository root:

  ```bash
  .github/scripts/test-pull-request-policy.sh
  .github/scripts/test-android-release-scripts.sh
  python3 -m unittest discover -s scripts/tests
  ```

Inspect every result. A failed, skipped, or unrun suite does not satisfy this
requirement; report existing individual test skips separately. Fix in-scope
failures and rerun the entire suite after further edits. If a failure cannot be
resolved within scope or a required check cannot run, report the blocker before
final review and do not claim readiness. Record the checked commit or final diff
and distinguish local results from CI, device, and upgrade acceptance.

## Opt-in workload benchmarks

The high-volume benchmark tests under `benchmark/` do not run during the
default application suite (`fvm flutter test` discovers `test/`).
Run `./scripts/run_test_benchmarks.sh` explicitly when investigating
post snapshot serialization, bookmark cold-load performance, or following-feed
cache deserialization. The script uses the pinned FVM Flutter toolchain.

These are diagnostic workloads, not a substitute for fast functional regression
tests under `test/`. Their loose duration limits only detect catastrophic
regressions; compare recorded results on the same machine and toolchain rather
than treating a single wall-clock sample as a performance budget.

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

## Tests

- Focus on observable behavior rather than implementation details.
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
