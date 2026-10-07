# Boorusama agent instructions

## Isolation and scope

Before changing repository files, create or reuse an isolated task worktree.
For a new task, run (based on current local `develop`):

```bash
python3 scripts/agent_worktree.py create <task-slug>
```

Perform all implementation and verification inside the reported worktree.
If the expected task worktree may already exist, inspect it first:

```bash
python3 scripts/agent_worktree.py status <task-slug>
```

Continue an existing worktree for the same task; never reuse it for unrelated work.
Do not edit, switch, stash, or reset the user's primary checkout.

Keep changes within the request; avoid unrelated cleanup. Local work and commits
on the agent's own isolated task branch/worktree are explicitly authorized as
part of the requested task; no separate approval is needed unless the user says
otherwise.

Merging or integrating changes, modifying `develop` or any other branch/worktree,
publication, and remote changes require explicit user authorization. Use `gh`
and explicitly target `timberpile/Boorusama`; provide manual instructions for
other repositories.

After successful, verified integration of a completed task into local `develop`,
automatically remove that task's local worktree and branch; integration approval
authorizes this cleanup without another confirmation unless the user asks to
retain them. First confirm that all task changes are integrated, the worktree is
clean (including untracked/ignored files), and no pending work or needed artifacts
remain. Remove only known disposable task-generated files; retain anything
uncertain. For squash integration, verify patch/tree equivalence rather than relying
on ancestry alone. Never force-remove a worktree. Delete only the exact completed
task's local branch/worktree; other cleanup and remote deletion require explicit
authorization.

## Workflow selection

Use the applicable `.agents/skills/<name>/SKILL.md`:

| Skill | Use when |
| --- | --- |
| [implement-change](.agents/skills/implement-change/SKILL.md) | Clear, scoped implementation |
| [debug-issue](.agents/skills/debug-issue/SKILL.md) | Known symptom, uncertain cause |
| [design-change](.agents/skills/design-change/SKILL.md) | Significant architecture, data/migration, subsystem, or UX/state decisions; requested design |
| [execute-plan](.agents/skills/execute-plan/SKILL.md) | Implement an existing plan or detailed design |
| [verify-change](.agents/skills/verify-change/SKILL.md) | Requested review or justified additional validation of a large change |

Default: inspect → implement → targeted verification → report. Tickets, issues,
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
- Localize user-facing strings and use `context.t`.
- Treat external/site/API data as nullable; use `equatable` when useful.
- Prefer readable pattern matching; comment non-obvious decisions.

## Verification and devices

Format changed Dart files with `fvm dart format`, run directly related behavior
tests, and analyze affected scope when useful. Broaden checks only for
cross-cutting changes or insufficient targeted coverage; no default full suite.
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
