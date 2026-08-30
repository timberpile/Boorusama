## Why

The Android development container currently assumes that the opened folder is the repository's main checkout. A linked Git worktree only mounts its own files, leaving the shared Git metadata unreachable or referenced through Windows paths that are invalid inside Linux, so developers cannot reliably use isolated worktrees and containers for concurrent feature work.

## What Changes

- Add a supported project-local worktree layout under `.worktrees/<name>` using Git relative worktree links.
- Provide separate standard-checkout and linked-worktree Dev Container configurations backed by the same Android toolchain image.
- Mount the common repository and open only the selected linked worktree when using the worktree configuration.
- Share dependency download caches while isolating `.dart_tool`, Flutter build output, and Android project state for each checkout.
- Validate the selected checkout, relative Git metadata, and required Git compatibility during container initialization, with actionable failures for an incorrect configuration.
- Preserve emulator and USB-device debugging through the existing host ADB integration.
- Document the normal developer workflow and caveats in `README.md`, with concise operational rules for coding agents in `AGENTS.md`.

## Capabilities

### New Capabilities

- `devcontainer-worktrees`: Reliable creation and use of project-local Git worktrees in isolated Android development containers.

### Modified Capabilities

None.

## Impact

- Affects `.devcontainer` configuration and initialization scripts, `.gitignore`, `README.md`, and `AGENTS.md`.
- Requires Git versions that support relative worktree links on the host and in the development image.
- Changes Dev Container selection from one implicit configuration to an explicit choice between standard and worktree configurations.
- Adds per-checkout Docker volumes for generated build state; dependency caches remain shared.
