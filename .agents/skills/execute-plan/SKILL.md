---
name: execute-plan
description: Directly implement an existing Boorusama plan or sufficiently detailed design when execution is requested.
---

# Execute a plan

Read the plan once and referenced design/specification when needed. Inspect files
as they become relevant. Adapt obsolete mechanics to current code, preserving
intended behavior; resolve material architecture/product deviations with the user.

Implement dependencies continuously in the existing task worktree; batch related
mechanical changes. Do not ask to continue after each task or automatically
create subagents, reviewers, a progress ledger, another worktree, or per-task
commits. Commit only when explicitly requested.

Apply `AGENTS.md` verification as work progresses. Compare the final diff and
behavior with the intended end state. Report results and meaningful deviations,
without a task-by-task transcript unless requested.
