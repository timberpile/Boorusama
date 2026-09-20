# Repository task queue

Each task or issue has its own Markdown file. Its folder determines its status:

| Folder | Meaning |
| --- | --- |
| [ready/](ready/) | Available, unclaimed work |
| [in-progress/](in-progress/) | Claimed work being handled by an agent |
| [blocked/](blocked/) | Work waiting for a documented blocker to be resolved |
| [done/](done/) | Acceptance criteria verified, with completion evidence |

List the status folders to discover tasks; there is no separate status index.
Keep the same filename throughout a task's lifecycle. Use a stable identifier
and descriptive slug for new tasks, for example `R34-001-unread-count.md`.
Existing descriptive filenames may be retained.

When asked to work through the queue, select an eligible task from `ready/`.
Choose High priority before Normal, then Low; break ties by filename. Resolve
dependencies first. If a legacy document lacks priority, treat it as Normal.
Move the file to `in-progress/` before starting and record your agent/session
and work branch. Claims are visible within a shared checkout; agents in separate
worktrees must coordinate before claiming the same task.

Record progress and verification in the task file. For blocked work, explain
what must change before it can resume. Recheck historical blockers rather than
assuming an earlier environment limitation still applies. Move completed work
to `done/` only after verifying all acceptance criteria, and update incoming links.

Task files should contain:

- Priority and affected feature or branch.
- Problem and reproduction steps, where applicable.
- Expected behavior and observable acceptance criteria.
- Relevant documentation, constraints, and dependencies.
- Agent/session and work branch when claimed.
- Progress, blockers, and completion evidence as applicable.

Consult [AGENTS.md](../../AGENTS.md) and the
[development workflow](../development_workflow.md) when implementing tasks.
Being listed in the queue does not itself authorize an agent to work outside
the user's request. GitHub issues are not required.
