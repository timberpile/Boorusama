# Design a pinned-search list that can show every profile

Priority: Low
Affected feature: Pinned-search presentation

## Expected outcome

Evaluate the user's possible future change: one Pinned Searches view displaying
searches from all profiles. This is a design task first, not authorization to
implement cross-profile feeds, folders, or merged post results.

## Dependencies and scope

- Build on [PS-005](PS-005-engine-refresh-adapters.md) capability behavior.
- Keep subscriptions, queries, authentication, post identities, and folders
  owned by their original profiles.
- Keep the navigation entry in its current side-menu section and position.
- Resolve interaction with the unsupported-current-profile message before implementation.

## Acceptance criteria

- [ ] Propose profile grouping/filtering and clear owning-profile labels.
- [ ] Specify opening a pin with its owning profile, including profile-switch behavior.
- [ ] Specify Refresh All scope, navigation NEW scope, and unsupported/deleted-profile handling.
- [ ] Specify how profile-scoped folders appear without becoming cross-profile folders.
- [ ] Record tradeoffs and a reviewable design; create an implementation task once the design is approved.
- [ ] No aggregation of posts across boorus or change to profile-scoped storage is implied.

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

Not started.

## User decisions — 2026-09-17

Group searches by profile using collapsible groups. Investigate architecture feasibility and implement if straightforward; retain profile ownership.
