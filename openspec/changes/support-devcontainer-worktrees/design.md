## Context

See `proposal.md` for motivation and `specs/devcontainer-worktrees/spec.md` for the behavioral contract. The current Dev Container bind-mounts only `${localWorkspaceFolder}` at `/workspace/Boorusama`, fixes `workspaceFolder` and initialization to that path, and mounts fixed named volumes over project-generated directories. A linked worktree contains a `.git` indirection to metadata under the main checkout, so mounting only the linked folder cannot reproduce the Windows host path inside Linux. Fixed generated-state volumes also make simultaneous containers unsafe.

Git supports relative worktree links for repositories that appear at different absolute paths in different environments. Dev Containers supports multiple configurations and variable substitution in workspace and named-volume mounts. Those mechanisms permit a project-local layout without generated host configuration or machine-specific paths.

## Goals / Non-Goals

**Goals:**

- Preserve the relative relationship between `.worktrees/<name>` and the main repository inside every worktree container.
- Keep the existing Android toolchain, host ADB, emulator, and USB-device workflows available.
- Allow the main checkout and multiple linked worktrees to build concurrently without sharing project-generated state.
- Fail early when a checkout is opened with the wrong container mode or incompatible Git.
- Keep developer and agent instructions short enough to remain operational documentation.

**Non-Goals:**

- Supporting arbitrary worktree locations outside `.worktrees/<name>`.
- Automatically creating, moving, removing, or pruning Git worktrees.
- Automatically deleting Docker volumes left by removed worktrees.
- Moving source code into Docker volumes or replacing worktrees with full clones.
- Adding background container orchestration beyond separate Dev Container instances.

## Decisions

### Use project-local relative worktrees

Supported worktrees live below `.worktrees/`, which is ignored by Git and ordinary repository searches. Developers enable `worktree.useRelativePaths` and create or repair worktrees with relative links. Keeping the main checkout, common Git metadata, and linked checkouts under one bind-mount root preserves their relationship on Windows, macOS, and Linux even though the absolute container path differs.

Sibling worktree directories were rejected because their common parent can expose unrelated repositories and makes the container depend on surrounding host layout. Arbitrary paths were rejected because they require host-specific mount inputs. Container-volume worktrees and separate clones were rejected because they impair host-side tools or duplicate repository state.

### Provide explicit standard and worktree configurations

Move the configuration selection into named Dev Container configurations under `.devcontainer` while retaining a shared Dockerfile and shared scripts. The standard configuration mounts and opens the main checkout. The worktree configuration assumes the opened host folder is `.worktrees/<name>`, bind-mounts `${localWorkspaceFolder}/../..` at `/workspace/Boorusama`, and opens `/workspace/Boorusama/.worktrees/${localWorkspaceFolderBasename}`.

An explicit selection is preferred over an initialization script that generates configuration or attempts conditional path discovery. It makes the active mount contract visible in the Dev Containers UI and makes an incorrect selection diagnosable.

### Derive initialization from the selected workspace

Initialization scripts must not `cd` to a fixed checkout. They derive and validate the current workspace, its Git directory, and its common Git directory before normalizing scripts or running bootstrap. Mode-specific environment values identify whether the standard or linked-worktree invariants are expected. Validation happens before any project bootstrap that could write generated files into the wrong checkout.

The development image must contain Git capable of reading and operating on relative worktree metadata. Capability validation is preferred over trusting whichever Git happens to be supplied by the base image.

### Separate generated state and share download caches

Pub, user-level Gradle, and Cargo caches remain shared named volumes because they primarily contain downloaded dependencies and their package managers coordinate access. `.dart_tool`, `build`, and `android/.gradle` use checkout-specific named volumes. The worktree configuration derives stable unique volume sources from the Dev Container workspace identity or sanitized workspace basename, while mounting them into the selected worktree path.

The standard checkout also retains its own generated volumes and does not share them with any linked worktree. Volume cleanup remains manual and documented because automatic removal during worktree deletion would be destructive and cannot be reliably coupled to Git lifecycle operations.

### Preserve host ADB behavior

Both configurations retain `ADB_SERVER_SOCKET=tcp:host.docker.internal:5037`, the host-gateway mapping, the host Android configuration mount, and the existing run wrapper. No USB device is passed directly into Docker; the host ADB server remains responsible for emulator and phone discovery.

### Separate developer and agent guidance

`README.md` receives a brief developer section with create, open, repair, remove, and optional volume-inspection commands plus the important caveats. `AGENTS.md` retains its instruction to follow `CLAUDE.md` and adds concise worktree placement, relative-link, container-selection, cache-isolation, and cleanup rules. Documentation avoids machine-specific paths, device IDs, and implementation detail not needed to operate the workflow.

## Risks / Trade-offs

- **Older Git cannot open a repository using the relative-worktree extension** → Validate the feature in the image, document the host prerequisite, and provide an actionable failure before bootstrap.
- **Developers can select the wrong Dev Container configuration** → Give configurations distinct names and validate checkout mode immediately.
- **A worktree moved outside `.worktrees/` stops resolving** → Document the fixed layout and the supported `git worktree move` or repair workflow.
- **Per-worktree volumes accumulate after worktrees are removed** → Use recognizable or inspectable volume identities and document deliberate cleanup without automating deletion.
- **Multiple containers share dependency caches concurrently** → Limit sharing to package-manager caches designed for reuse; isolate every project-generated directory known to affect Flutter and Android builds.
- **Mounting the main repository exposes sibling worktrees inside a worktree container** → Open only the selected worktree as the editor workspace, ignore `.worktrees/` in repository traversal, and avoid commands scoped to the mount root.
- **Broad destructive cleanup can affect nested worktrees** → Warn developers and agents not to run broad forced cleanup against `.worktrees/` or the repository root.

## Migration Plan

1. Add `.worktrees/` to repository ignores and introduce the named standard and worktree configurations around the shared image and scripts.
2. Update initialization to validate its declared mode and selected workspace before bootstrap.
3. Ensure the development image provides compatible Git and validate both configuration JSON files.
4. Document new creation and selection steps in `README.md` and operational constraints in `AGENTS.md`.
5. Create a disposable relative worktree and verify host Git, container Git, generated-volume isolation, Android build, and host ADB behavior; also re-verify the standard checkout.
6. Remove the disposable worktree through Git and leave Docker-volume cleanup as an explicit optional operation.

Rollback consists of restoring the single standard configuration and its fixed workspace behavior. Relative worktrees can be repaired back to absolute links with Git before disabling relative-worktree repository support if compatibility requires a full rollback.
