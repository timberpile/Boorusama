# Boorusama agent instructions

## Workflow and scope

Choose the applicable skill from `.agents/skills/<name>/SKILL.md`:

| Skill | When to use |
| --- | --- |
| `research-ticket` | Investigate reports, check existing issues, and draft issues or handoffs |
| `debug-issue` | Investigate bugs with an uncertain cause |
| `design-change` | Resolve significant architecture, persistence, or UX decisions |
| `implement-change` | Implement a clear, scoped change |
| `execute-plan` | Implement an existing plan or detailed design |
| `verify-change` | Review or independently validate a change |
| `prepare-release` | Prepare the next release or an explicitly requested release draft |

Inspect relevant code, tests, and documentation first. Keep changes within
the authorized scope; do not clean up unrelated work. Default implementation
workflow: inspect → implement → scope-appropriate verification → review → report.
Research alone does not authorize issue publication or code changes. GitHub Issues
are the only task tracker, but ordinary changes need no issue. Do not require
plans, PRs, subagents, or separate reviewers as routine prerequisites. Use PRs
and Superpowers only when explicitly requested; do not automatically chain skills.

## Isolation, commits, and publication

Follow [development workflow](docs/development_workflow.md) for worktrees,
branch reuse, authorization, integration, publication, durable working files,
and cleanup. Work on an isolated branch/worktree for GitHub Issues; the documented
small issue-free change exception permits a local `develop` commit. Preserve
unrelated user work. Commit scoped task changes before reporting completion,
unless explicitly asked to leave them uncommitted.

Merging a task branch requires approval. Approval such as "can be merged"
authorizes the complete verified integration workflow, including publication
to `origin/develop`, issue closure, and cleanup, unless narrower limits are given.
It does not authorize unrelated changes or a PR.

## Engineering and UI

Follow [engineering guidelines](docs/engineering_guidelines.md) and nearby
architecture. Use `fvm` for Flutter/Dart. Repository content must be in English
except localization resources. Prefer the simplest solution satisfying approved
requirements; do not add speculative abstractions, metadata, or features.

Before UI changes, inspect comparable screens. Reuse Kurumi components and
follow the [UI style guide](docs/ui_style_guide.md) as a proposed baseline
until #136 is accepted; preserve approved behavior. Keep action labels short
and context-aware: prefer "Import" over "Import to Local Library" and "Save"
over "Save File" when the context is already clear. Qualify only to avoid ambiguity.
Use `context.t` for localized UI strings.

## Verification and devices

Follow [scope-appropriate verification](docs/engineering_guidelines.md#scope-appropriate-verification).
Before integrating into `develop`, require a complete local test-suite pass on
the final combined candidate. Reuse an existing pass only while that candidate
remains valid. Report incomplete or unrun checks without claiming readiness.

Use an emulator only for necessary device/UI integration. Follow
[Android emulator coordination](docs/android_emulator.md) and use Maestro MCP.
Read only needed entries from ignored `.test_credentials`; never commit or expose
credentials in logs, screenshots, issues, responses, or fixtures.

Report significant decisions, changes, checks actually performed, and limitations.
