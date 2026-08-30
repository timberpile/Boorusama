## 1. Establish Compatibility and Test Coverage

- [x] 1.1 Inspect the pinned development image's Git capabilities and update the Dockerfile only if needed to guarantee relative-worktree support.
- [x] 1.2 Add failing automated checks for standard-checkout validation, linked-worktree validation, wrong-mode errors, unsupported layout errors, and unresolved common Git metadata.
- [x] 1.3 Add a configuration validation check covering every Dev Container JSON file and its referenced Dockerfile, workspace, scripts, and mount targets.

## 2. Add Worktree-Aware Container Configurations

- [x] 2.1 Add `.worktrees/` to `.gitignore` without changing unrelated ignore behavior.
- [x] 2.2 Restructure the existing configuration into a clearly named standard-checkout Dev Container while preserving its Android toolchain, shared dependency caches, host Android settings, and ADB connection.
- [x] 2.3 Add the linked-worktree Dev Container configuration that mounts the common repository root, opens only `.worktrees/<name>`, and preserves the existing Android and ADB environment.
- [x] 2.4 Give the main checkout and every linked worktree distinct `.dart_tool`, `build`, and `android/.gradle` volume identities while retaining shared Pub, user Gradle, and Cargo caches.

## 3. Validate and Bootstrap the Selected Checkout

- [x] 3.1 Implement checkout-mode validation that resolves the working tree, private Git directory, and common Git directory before bootstrap and reports actionable configuration-selection errors.
- [x] 3.2 Add a relative-worktree capability check that fails before bootstrap when container Git cannot operate on the repository format.
- [x] 3.3 Update post-create initialization to operate from the selected workspace instead of `/workspace/Boorusama`, retaining Windows bind-mount stat handling and script normalization.
- [x] 3.4 Run the workspace-validation and configuration tests and cover any newly discovered failure cases.

## 4. Document the Supported Workflow

- [x] 4.1 Add a concise `README.md` section covering relative-worktree setup, creation, container selection, repair, removal, optional volume inspection, and the placement, Git-version, and destructive-cleanup caveats.
- [x] 4.2 Extend `AGENTS.md` concisely with the `.worktrees/<name>` convention, relative-link requirement, container selection, generated-cache isolation, and safe-cleanup rules while preserving its `CLAUDE.md` routing.
- [x] 4.3 Review both documentation updates for machine-specific paths, fixed device identifiers, duplicated implementation detail, and commands that could remove unrelated worktrees or volumes.

## 5. Verify Concurrent Development

- [x] 5.1 Create a disposable relative worktree and verify that host Git and container Git resolve the same checkout and common repository metadata.
- [x] 5.2 Open or build the main checkout and two linked-worktree configurations and verify their generated volumes are distinct while dependency caches are shared.
- [x] 5.3 Run the canonical Android debug build from a linked-worktree container and re-run it from the standard container.
- [x] 5.4 Verify the linked-worktree run script can target a host-connected emulator or USB device through the existing ADB server integration.
- [x] 5.5 Remove the disposable worktree through Git, confirm no other checkout or volume was automatically deleted, and run strict OpenSpec validation.
