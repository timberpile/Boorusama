# Show pinned searches in collapsible profile groups

Priority: Low
Affected feature: Pinned-search presentation

## Expected outcome

Display independent searches from all profiles in collapsible groups, keeping
queries, folders, authentication, and results owned by their original profiles.
The user authorized implementation after an architecture feasibility check.

## Dependencies and scope

- Build on [PS-005](../done/PS-005-engine-refresh-adapters.md) capability behavior.
- Keep subscriptions, queries, authentication, post identities, and folders
  owned by their original profiles.
- Keep the navigation entry in its current side-menu section and position.
- Resolve interaction with the unsupported-current-profile message before implementation.

## Acceptance criteria

- [x] Propose profile grouping/filtering and clear owning-profile labels.
- [x] Specify opening a pin with its owning profile, including profile-switch behavior.
- [x] Specify Refresh All scope, navigation NEW scope, and unsupported/deleted-profile handling.
- [x] Specify how profile-scoped folders appear without becoming cross-profile folders.
- [x] Record architecture feasibility and implement the approved grouping without cross-profile result aggregation.
- [x] No aggregation of posts across boorus or change to profile-scoped storage is implied.

## Constraints and verification

Use the existing profile repositories and engine query composition. NEW means
observed matching uploads after the checkpoint; metadata edits to old posts do
not trigger it. Preserve PS-001's bounded snapshots and failure behavior; do
not restore exact counts or exhaustive pagination. Keep the side-menu section
and desktop tab positions stable. Add localized text through i18n.

Test observable behavior and persistence where relevant. Validate Android UI
with Maestro. Update [subsystem documentation](../../pinned_searches.md) and
record completion evidence here before moving the task to `done/`.

## Completion evidence

Agent: Codex (/root). Branch: `feature/chronological-pinned-search-support`.

Architecture feasibility: profile-scoped selectors and explicit profile/folder
pages already exist, so grouping is a presentation change rather than a storage
or engine migration. Groups preserve independent expansion state; opening a
search/feed activates the owning profile. Root Refresh All visits supported
profiles; navigation NEW covers independent pins across existing profiles.
Unsupported groups explain support; removed profiles are omitted.

Verified all 1,090 tests and clean static analysis; dev APK built. Android
Maestro verified both existing profile groups, independent collapse state,
opening the other profile's exact stored query, ownership switching to
safebooru.donmai.us, and clearing only that pin's NEW state. Unsupported-profile
explanations are protected by deterministic widget tests.

## User decisions — 2026-09-17

Group searches by profile using collapsible groups. Investigate architecture feasibility and implement if straightforward; retain profile ownership.
