# Engineering and verification guidelines

Read this before changing Dart or Flutter code or tests. The ticket and
development workflows are in [docs/work/README.md](work/README.md) and
[docs/development_workflow.md](development_workflow.md).

## Tools

- Always use `fvm` for `flutter` and `dart` commands. Run tests with
  `fvm flutter test`.
- Run `./gen.sh` to generate i18n, language configs, and booru client configs
  when those inputs change. In a fresh worktree, first run `fvm dart pub get`
  from `packages/boorusama_cli`, as described in the development workflow.
- Use the Maestro MCP server to control the available Android emulator when
  testing or validating UI behavior.
- Sample related code before writing new code so changes follow existing
  patterns. Run `fvm dart format` after creating or editing Dart files;
  batch formatting where practical.

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

Project knowledge belongs under `docs/`. Check the relevant documentation
before investigating a subsystem. Update it when you discover non-obvious
information that would save a future agent significant investigation:
architectural constraints, unexpected framework behavior, important decisions
and rationale, build/tooling quirks, or unsuccessful approaches worth avoiding.
Do not store source-obvious facts, temporary debugging observations, or
speculation.
