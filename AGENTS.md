# Boorusama agent instructions

## Isolation and scope

Use an isolated task branch/worktree; GitHub issues and legacy work items always require one. Small
explicit changes may use local `develop` under the
[development workflow](docs/development_workflow.md#isolation-and-small-changes).
When the user specifies an existing task branch, continue that branch instead of
creating a new one. Reuse its isolated worktree if present; otherwise create an
isolated worktree for that branch and work there. If it is checked out in the
primary checkout, preserve its changes and detach that checkout before attaching
the branch to the task worktree.

Keep changes within the request; avoid unrelated cleanup. Follow that workflow
for checkout setup, authorization, integration, and cleanup.
Commit all task changes before reporting completion, unless the user explicitly
asks to leave them uncommitted. Stage only changes belonging to the task.

## Workflow selection

Use the applicable `.agents/skills/<name>/SKILL.md`:

| Skill | Use when |
| --- | --- |
| [implement-change](.agents/skills/implement-change/SKILL.md) | Clear, scoped implementation |
| [debug-issue](.agents/skills/debug-issue/SKILL.md) | Known symptom, uncertain cause |
| [design-change](.agents/skills/design-change/SKILL.md) | Significant architecture, data/migration, subsystem, or UX/state decisions; requested design |
| [execute-plan](.agents/skills/execute-plan/SKILL.md) | Implement an existing plan or detailed design |
| [verify-change](.agents/skills/verify-change/SKILL.md) | Requested review or justified additional validation of a large change |
| [test-android](.agents/skills/test-android/SKILL.md) | Android emulator verification with Maestro and disposable live-data scenarios |
| [prepare-release](.agents/skills/prepare-release/SKILL.md) | Next release version and changelog; explicitly requested delivery through a GitHub draft |

Default: inspect → implement → scope-appropriate verification → review → report.
Tickets, issues, design/plan documents, subagents, and reviewer pairs are optional, not routine
prerequisites. Use PRs only when explicitly requested. Do not automatically chain
skills; implementation includes verification. Use Superpowers only when explicitly
requested.

## Context and conventions

Read only relevant code, tests, and docs. Consult
[engineering guidelines](docs/engineering_guidelines.md) for needed detail.
Use the [issue workflow](docs/issue_workflow.md) for new tracked tasks and
explicit issue work. Read [legacy queue rules](docs/work/README.md) only when the
requested task already exists there. Do not create new local tickets or migrate
existing work items without an explicit migration request. Ordinary scoped
changes still need no issue. Read relevant
[development workflow](docs/development_workflow.md) sections for integration,
publication, releases, or upstream synchronization.

- **Repository language:** All code comments, documentation, commit messages, issues, legacy work items, design/merge plans and agent handoffs must be written in **English**. Only user-facing UI localization resources may contain text in their intended target languages. Translate any new non-localization German prose to English before committing.
- Always use `fvm` for Flutter/Dart.
- Use manually declared Riverpod `Notifier`/`AsyncNotifier` providers; no provider codegen.
- Follow nearby architecture/style; keep business logic out of widgets when practical.
- Before UI changes, inspect comparable screens; reuse application components, spacing,
  typography, sizing, and interactions. Justify intentional deviations.
- Prefer Kurumi components for popup, context, and anchored menus; do not mix
  differently styled Material and Kurumi menu rows in one popup.
- Localize user-facing strings and use `context.t`.
- Treat external/site/API data as nullable; use `equatable` when useful.
- Prefer readable pattern matching; comment non-obvious decisions.

## Verification and devices

Format changed Dart files with `fvm dart format`, run directly related behavior
tests during implementation, and analyze affected scope when useful. Default
ordinary test concurrency to detected available physical cores (minimum one),
using `python3 scripts/physical_core_count.py`; `TEST_CONCURRENCY` overrides the
complete runner. Workload benchmarks keep their explicit serial setting.
Tests should use controlled clocks or completion signals instead of fixed sleeps
and strict wall-clock budgets; retain meaningful timing contracts and bounded
hang guards as described in the [test guidelines](docs/engineering_guidelines.md#tests).
Choose verification by the change's scope, following the
[verification guidance](docs/engineering_guidelines.md#scope-appropriate-verification):

- Documentation, work-item status, comments, and other non-runtime-only changes:
  run relevant documentation/tooling checks; do not run application tests.
- Scoped application changes: run affected test files or directories and nearby
  consumer tests when a meaningful boundary is crossed.
- Local package changes: run that package's complete suite and relevant consumer
  tests in the application or other packages.
- Broad changes to shared core models/infrastructure, dependencies/toolchain,
  generated-code infrastructure, test infrastructure, repository-wide behavior,
  or genuinely unclear scope: run the complete local suite. Prefer broader checks
  when uncertain.

Before a task is safe to integrate into `develop`, the final integration candidate
must pass the [complete local test suite](docs/engineering_guidelines.md#complete-local-test-suite)
(application, every package/CLI, and repository tooling). Targeted verification
proves the task locally; full verification proves the integration candidate.
Reuse a complete pass on that same candidate across handoffs and documentation
or status-only updates. Relevant code, tests, dependencies, generated runtime
output, or changes to the combined develop candidate require re-verification.
Record the checked commit/state, commands, results and limits in the normal task
report; no cache or verification metadata is needed. Report failed or incomplete
checks without claiming the candidate is ready to integrate.
Run `./gen.sh` only when changed inputs or missing generated output require it.

For UI changes, exercise affected actions at narrow width, enlarged text, and
with the keyboard open when relevant. Apply these checks where the interaction
can be constrained (e.g. dialogs, sheets, forms, or search/filter controls);
prefer targeted widget tests when they cover this efficiently.

Use an emulator only for necessary device/UI integration. Before any operation,
read and follow the [exclusive lease procedure](docs/android_emulator.md).
Use Maestro MCP for interactive UI control. Saved pilot YAML may also run through
`scripts/android_ui_test.py` under the same lease procedure. Full dev-app resets
require an explicitly disposable environment and `--confirm-reset`; see the
[Android UI testing guide](docs/android_ui_testing.md). Preserve other signed-in
test environments. Read only needed entries from ignored `.test_credentials` and
never commit or expose them in logs, screenshots, issues, responses, or fixtures.

Report changes, significant decisions, checks actually performed, and limitations.
