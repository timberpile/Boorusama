# Boorusama agent instructions

## Isolation and scope

Use an isolated task branch/worktree; work items always require one. Small
explicit changes may use local `develop` under the
[development workflow](docs/development_workflow.md#isolation-and-small-changes).
Keep changes within the request; avoid unrelated cleanup. Follow that workflow
for checkout setup, authorization, integration, and cleanup.

## Workflow selection

Use the applicable `.agents/skills/<name>/SKILL.md`:

| Skill | Use when |
| --- | --- |
| [implement-change](.agents/skills/implement-change/SKILL.md) | Clear, scoped implementation |
| [debug-issue](.agents/skills/debug-issue/SKILL.md) | Known symptom, uncertain cause |
| [design-change](.agents/skills/design-change/SKILL.md) | Significant architecture, data/migration, subsystem, or UX/state decisions; requested design |
| [execute-plan](.agents/skills/execute-plan/SKILL.md) | Implement an existing plan or detailed design |
| [verify-change](.agents/skills/verify-change/SKILL.md) | Requested review or justified additional validation of a large change |
| [prepare-release](.agents/skills/prepare-release/SKILL.md) | Next release version and changelog; explicitly requested delivery through a GitHub draft |

Default: inspect → implement → full final verification → review → report. Tickets, issues,
design/plan documents, subagents, and reviewer pairs are optional, not routine
prerequisites. Use PRs only when explicitly requested. Do not automatically chain
skills; implementation includes verification. Use Superpowers only when explicitly
requested.

## Context and conventions

Read only relevant code, tests, and docs. Consult
[engineering guidelines](docs/engineering_guidelines.md) for needed detail.
Read [queue rules](docs/work/README.md) and related tickets only for explicitly
requested work items; one agent may claim and implement directly. Read relevant
[development workflow](docs/development_workflow.md) sections for integration,
publication, releases, or upstream synchronization.

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
tests during implementation, and analyze affected scope when useful. After the
last edit and before final review, handoff, or claiming changes are ready, rerun
the [complete local test suite](docs/engineering_guidelines.md#complete-local-test-suite).
This includes application, package, CLI, and repository-tooling tests, even for
small or documentation-only changes. Targeted passes and CI do not replace this
local run. Fix failures and repeat the complete suite after any further edits;
if blocked, report the incomplete checks without presenting the change as ready.
Run `./gen.sh` only when changed inputs or missing generated output require it.

For UI changes, exercise affected actions at narrow width, enlarged text, and
with the keyboard open when relevant. Apply these checks where the interaction
can be constrained (e.g. dialogs, sheets, forms, or search/filter controls);
prefer targeted widget tests when they cover this efficiently.

Use an emulator only for necessary device/UI integration. Before any operation,
read and follow the [exclusive lease procedure](docs/android_emulator.md).
Use Maestro MCP for UI control. Test accounts are already signed in; read only
needed entries from ignored `.test_credentials` and never commit or expose them
in logs, screenshots, issues, responses, or fixtures.

Report changes, significant decisions, checks actually performed, and limitations.
