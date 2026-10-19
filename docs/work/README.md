# Legacy repository task queue

These rules apply only to existing, unmigrated repository work items. New tracked
tasks use [GitHub Issues](../issue_workflow.md); ordinary changes still need no
ticket. Do not create new local ticket numbers or mirror a GitHub issue here.
This preparation does not migrate, move, or close any existing work item.
Begun, blocked, and completed tasks stay in this workflow. Migration of genuinely
unstarted tasks is a separate, explicitly requested operation; check actual work
and claims across branches/worktrees rather than trusting the `ready/` folder.
Keep any existing `active/` records until their individual state is reconciled.
Work items always require a dedicated task branch/worktree; the small-change
exception in the [development workflow](../development_workflow.md#isolation-and-small-changes)
does not apply.

Each legacy task has its own Markdown file. Its folder determines its status:

| Folder | Meaning |
| --- | --- |
| [ready/](ready/) | Available, unclaimed work |
| [in-progress/](in-progress/) | Claimed work being handled by an agent |
| [blocked/](blocked/) | Work waiting for a documented blocker to be resolved |
| [done/](done/) | Acceptance criteria verified, with completion evidence |

List the status folders to discover tasks; there is no separate status index.
Keep the same filename throughout a legacy task's lifecycle. Legacy numbers are
not GitHub issue numbers. Preserve existing branches and links; do not rename
or duplicate running tasks to make them resemble new issues.

When asked to work through the queue, select an eligible task from `ready/`.
Choose High priority before Normal, then Low; break ties by filename. Resolve
dependencies first. If a legacy document lacks priority, treat it as Normal.
Before implementation, move the file to `in-progress/` in the task's isolated
worktree and record the agent/session, branch, and worktree. One agent may claim
and implement the ticket directly; delegation and separate reviewer agents are
optional. Check related tickets and existing claims across active worktrees
before claiming: a claim in one checkout is not automatically visible in another.
Coordinate conflicting claims; do not take over someone else's claim without
coordination. Keep the implementation within the requested ticket's scope.

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
- Dedicated worktree, plus implementer/session if delegated.
- Progress, blockers, and completion evidence as applicable.

Follow [AGENTS.md](../../AGENTS.md) for isolation and workflow selection. Read
the relevant [development workflow](../development_workflow.md) sections only
for integration, publication, releases, or upstream synchronization.
Being listed in the queue does not itself authorize an agent to work outside
the user's request. Existing tasks have one source of status: this queue until
explicitly migrated, never a second GitHub issue in parallel.
