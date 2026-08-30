# Repository instructions

Read and follow the repository instructions in `CLAUDE.md`.

## Worktrees

- Put linked worktrees at `.worktrees/<name>` and create or repair them with Git relative paths.
- Use the **Worktree** dev container configuration for linked worktrees and **Standard** for the main checkout.
- Keep `.dart_tool`, `build`, and `android/.gradle` isolated per checkout; only dependency caches are shared.
- On Windows, prefer the VS Code worktree tasks for guarded creation and removal.
- Never run broad destructive cleanup against the repository root or `.worktrees/`, and do not delete worktree Docker volumes without verifying their owners.
