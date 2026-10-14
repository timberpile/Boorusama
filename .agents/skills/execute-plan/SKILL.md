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
commits. Before presenting work for review, apply scope-appropriate verification
from `AGENTS.md`, then commit all task changes and confirm the worktree has no
uncommitted changes, including untracked task files. Broad/unclear scope needs
the full suite. Before develop integration, require a complete pass on the final
candidate; reuse a pass on that same candidate across handoffs and report-only
edits. Resolve failures and re-verify relevant changes. Record pending device or
upgrade verification in the committed documentation. Integration and publication
remain subject to the [development workflow](../../../docs/development_workflow.md) authorization rules.

Follow the engineering guide's timing-independent test guidance: controlled
clocks for timing behavior, completion signals for async work, and generous
bounded guards for real I/O. Do not rely on fixed sleeps or host-speed budgets.

Apply `AGENTS.md` verification as work progresses. Compare the final diff and
behavior with the intended end state. Report results and meaningful deviations,
without a task-by-task transcript unless requested.
