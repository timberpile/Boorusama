# DEV-001: Keep local develop history linear

- Priority: High
- Affected branch: `develop`
- Agent/session: Codex `/root`
- Work branch: `repair/linear-develop`

## Problem

Local feature and fix commits were combined on `develop` with a merge commit.
GitHub rejects that history because `develop` requires linear history.

## Expected behavior

Ordinary local changes on `develop` form a single-parent chain from
`origin/develop`. Repository instructions explain how to detect accidental
merge commits before pushing. The documented upstream synchronization remains
the only merge-commit exception because it must preserve upstream ancestry.

## Acceptance criteria

- The current unpushed content is preserved in an equivalent linear history.
- No ordinary outgoing `develop` commit has more than one parent.
- Repository instructions require linear local feature, fix, and direct-commit
  integration and provide a pre-push verification command.
- The repaired `develop` branch is accepted by `origin` without force-pushing.

## Dependencies

None.

## Completion evidence

- The original merged tip and the repaired pre-documentation tip both had tree
  `9318b0091d66c6db5b0afcdfa7a15e96b16ca7ec`.
- `git rev-list --min-parents=2 ba5ff87db..65f21a2f8` produced no commits.
- `AGENTS.md` and `docs/development_workflow.md` document the local linear
  history rule and its verification command.
- A normal push advanced `origin/develop` from `ba5ff87db` to `65f21a2f8`.
