## Purpose

Enable developers and coding agents to use concurrent, project-local Git worktrees with isolated and correctly mounted Android development containers.

## ADDED Requirements

### Requirement: Standard and worktree container modes
The project SHALL provide distinguishable development-container configurations for the main checkout and for linked worktrees, and both configurations SHALL use the same Android build toolchain.

#### Scenario: Open the main checkout
- **WHEN** a developer opens the repository's main checkout with the standard configuration
- **THEN** the container opens the main checkout as its workspace and supports the existing Android development commands

#### Scenario: Open a linked worktree
- **WHEN** a developer opens `.worktrees/<name>` with the worktree configuration
- **THEN** the container opens that linked worktree as its workspace while retaining access to the repository's shared Git metadata

### Requirement: Portable worktree metadata
Supported linked worktrees MUST live at `.worktrees/<name>` and MUST use Git relative worktree links so that Git resolves the checkout on both the host and at its corresponding container path.

#### Scenario: Resolve Git on host and in container
- **WHEN** a supported linked worktree is created with relative worktree links and opened in its container
- **THEN** Git resolves the same working tree and common repository from both environments without machine-specific absolute paths

#### Scenario: Unsupported worktree placement
- **WHEN** the worktree configuration is used for a checkout outside the supported `.worktrees/<name>` layout
- **THEN** initialization stops with instructions explaining the required layout

### Requirement: Concurrent generated-state isolation
Each main or linked checkout SHALL use isolated `.dart_tool`, Flutter `build`, and Android project `.gradle` storage, while dependency download caches MAY be shared between checkout containers.

#### Scenario: Two feature containers run concurrently
- **WHEN** two linked worktrees are opened in separate containers
- **THEN** generated state from either checkout is not mounted into the other checkout

#### Scenario: Dependency cache reuse
- **WHEN** separate checkout containers request an already downloaded Pub, Gradle, or Cargo dependency
- **THEN** they can reuse the shared dependency cache without sharing project-generated state

### Requirement: Configuration misuse and compatibility checks
Container initialization MUST validate the checkout mode, resolve the worktree-specific and common Git directories, and verify that container Git supports relative worktree metadata before project bootstrap runs.

#### Scenario: Wrong configuration selected
- **WHEN** a developer selects the standard configuration for a linked worktree or the worktree configuration for the main checkout
- **THEN** initialization stops before project bootstrap and identifies the correct configuration to use

#### Scenario: Incompatible Git installation
- **WHEN** container Git cannot read the repository's relative-worktree format
- **THEN** initialization stops with an actionable compatibility error

#### Scenario: Valid configuration selected
- **WHEN** all checkout and compatibility checks pass
- **THEN** initialization bootstraps the selected checkout rather than a fixed repository path

### Requirement: Android device debugging parity
Both container modes SHALL retain the existing host ADB integration for Android emulators and USB-connected devices.

#### Scenario: Run from a linked worktree
- **WHEN** a host emulator or phone is visible through the configured host ADB server and the developer runs the Android attachment script in a linked-worktree container
- **THEN** Flutter can target that device using the same workflow as the standard container

### Requirement: Worktree operating guidance
The repository SHALL document the supported worktree lifecycle and caveats for developers and SHALL provide concise safety and configuration-selection instructions for coding agents.

#### Scenario: Developer follows the README
- **WHEN** a developer needs to create, open, repair, remove, or clean up a supported worktree
- **THEN** `README.md` provides concise commands and warns about Git compatibility, fixed placement, generated volumes, and destructive cleanup

#### Scenario: Agent begins isolated feature work
- **WHEN** a coding agent reads `AGENTS.md`
- **THEN** it is instructed to use `.worktrees/<name>`, relative worktree metadata, the worktree container configuration, isolated generated caches, and safe cleanup practices

### Requirement: Conservative worktree cleanup
Removing a linked worktree MUST NOT automatically delete its associated Docker volumes or other worktrees.

#### Scenario: Remove completed worktree
- **WHEN** a developer removes a linked worktree with Git
- **THEN** the checkout is removed without automatic deletion of Docker volumes, and documentation explains how obsolete volumes can be identified for deliberate cleanup
