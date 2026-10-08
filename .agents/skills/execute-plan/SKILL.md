---
name: execute-plan
description: Directly implement an existing Boorusama plan or sufficiently detailed design when execution is requested.
---

# Execute a plan

Read the plan once and referenced design/specification when needed. Inspect files
as they become relevant. Adapt obsolete mechanics to current code, preserving
intended behavior; resolve material architecture/product deviations with the user.

Implement dependencies continuously in the checkout permitted by the
[development workflow](../../../docs/development_workflow.md#isolation-and-small-changes)
(normally the existing task worktree); batch related mechanical changes.
Do not ask to continue after each task or automatically
create subagents, reviewers, a progress ledger, another worktree, or per-task
commits. Before presenting work for review, commit all task changes and confirm the worktree has no uncommitted
changes, including untracked task files. Record any pending verification in the
committed documentation. Integration and publication remain subject to
the [development workflow](../../../docs/development_workflow.md) authorization rules.

Apply `AGENTS.md` verification as work progresses. Compare the final diff and
behavior with the intended end state. Report results and meaningful deviations,
without a task-by-task transcript unless requested.
