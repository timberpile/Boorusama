## Commands
- `fvm flutter test` - Run tests
- `./gen.sh` - Generate i18n, language configs, and booru client configs
Always use `fvm` for `flutter` and `dart` commands.
When testing/validating ui behavior, use the Maestro MCP server to control the available android emulator.

# Code style
- For Riverpod, always use Notifier/AsyncNotifier. Manually declare providers, no codegen.
- Prefer using factory methods/constructors for creating instances with complex setup, move all constructor to the top of the class.
- Always put business logic into state classes or a dedicated file.
- Never hardcode user-facing text. Add it to the i18n resources and access it through `BuildContext` with `context.t`.
- Use `equatable` for value equality when necessary.
- Always use pattern matching to make code more readable, only use traditional if/else when it improves readability.
- When parsing data from external sources, always assume data is nullable and handle null cases explicitly in the code.
- Avoid writing comments that over-explain the code. Write comments only when necessary to explain complex logic or decisions that are not immediately clear from the code itself.

# Testing
- Focus on observable behavior, not implementation details.
- Use mocks/stubs only for external dependencies, avoid mocking internal logic.
- Keep tests minimal and logically grouped. For repeated scenarios, use loops with explicit test case records—one `test()` call per iteration, testing the same behavior with different inputs.
- Don't write tests for obvious language behavior, one-line getters/setters, or redundant validation. Each test should protect meaningful logic or edge cases only.
- Test names must be clear sentences describing behavior and outcome. Do not include function or class names

Example of parameterized tests:
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

# Workflow
- Run `dart format` after each file creation, prefer batch formatting.
- Always take a look and sample related code before writing new code to understand the existing patterns.
- Use the GitHub CLI (`gh`) for all GitHub-related tasks.
- When committing, use conventional commits format, e.g. `fix(posts): handle null tags` and only write commit summaries, no descriptions.

## GitHub development process

- NEVER perform GitHub actions on any repository other than `timberpile/Boorusama`. Always target `timberpile/Boorusama` explicitly in GitHub CLI commands. For every other repository, provide manual instructions instead of taking action.
- Read `docs/development_workflow.md` before starting repository changes.
- Direct commits to `develop`, including upstream synchronization merge commits, are allowed only when the user explicitly authorizes them for the current change. This authorization does not carry over to later changes.
- Without explicit authorization for a direct `develop` commit, use the standard branch and pull-request workflow. Creating a GitHub issue is recommended.
- Keep GitHub issue descriptions short and proportional to the issue. For a small issue, use a few concise sentences or bullets covering the problem, relevant reproduction context, and expected behavior. Avoid long paragraphs and implementation narratives unless needed to understand the issue.
- Do not include validation reports, test counts or results, static-analysis results, testing tool logs, or development history in issue descriptions. Keep verification details in work reports or review discussions instead.
- Synchronize `upstream/master` by merging it locally into `develop` and pushing the resulting merge commit directly, following `docs/development_workflow.md`. Do not create a synchronization branch or pull request.
- Create the work branch from the latest `origin/develop`:
  - `feature/<issue-id>-<short-description>` or `feature/<short-description>` for features and additive changes.
  - `fix/<issue-id>-<short-description>` or `fix/<short-description>` for bug fixes and corrective changes.
- Never commit or push directly to `master`.
- Pull requests for features and fixes target `develop`. Only `develop` may open a release/promotion pull request to `master`.
- Set the pull request title to exactly `Merge branch '<branch-name>'`. When an issue exists, include `Closes #<issue-id>` in the body.
- Keep pull request descriptions brief. Use a few concise bullets describing only the meaningful end-state changes introduced when merged. Exclude implementation details, test history, development phases, temporary steps, and exhaustive file-level summaries unless they are essential to understanding the result.
- Do not enable GitHub auto-merge. Wait for explicit user approval, then squash-merge feature and fix pull requests manually.
- Do not edit the generated squash commit title. Delete the local branch after GitHub has merged the pull request and deleted its remote branch.

## Persistent project knowledge

Project knowledge is stored under `docs/`.

Before investigating a subsystem, check the relevant documentation.

When you discover non-obvious information that would save a future
agent significant investigation, update the appropriate document.

Do not store:
- information obvious from the source code
- temporary debugging observations
- speculation

Record:
- architectural constraints
- unexpected framework/library behavior
- important implementation decisions and their rationale
- build/tooling quirks
- unsuccessful approaches worth avoiding

## Repository task queue

- Record each task or issue in its own Markdown file under `docs/work/`.
- Read `docs/work/README.md` before working on repository tasks. For a specific
  request, check the queue for related tasks and stay within the requested scope.
- The containing folder is the source of truth for task status:
  - `ready/`: available, unclaimed work.
  - `in-progress/`: claimed work currently being handled.
  - `blocked/`: work that cannot proceed until a documented blocker is resolved.
  - `done/`: work whose acceptance criteria have been verified.
- When asked to work through the queue, select the highest-priority eligible
  task from `ready/`, respecting its dependencies. Move it to `in-progress/`
  before starting and record the agent/session and work branch in the file.
  Do not take over another agent's claimed task without coordination.
- Keep filenames stable when moving tasks. Do not duplicate folder status in
  a status field or maintain a separate status checklist in the README.
- Include priority, affected feature or branch, problem, expected behavior,
  acceptance criteria, relevant context, and dependencies in each task file.
  Update progress and handover notes in that file as work proceeds.
- If blocked, document the blocker and what is needed to resume, then move the
  file to `blocked/`. Once resolved, move it to `ready/` or `in-progress/`
  according to whether an agent is resuming it.
- Move a task to `done/` only after verifying its acceptance criteria and
  recording completion evidence. Update links when moving task files.
- Follow `docs/development_workflow.md` for code changes. Repository tasks do
  not require GitHub issues and do not authorize unrelated work or delivery.
