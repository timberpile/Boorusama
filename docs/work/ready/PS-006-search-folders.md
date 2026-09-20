# Organize pinned searches into single-level folders

Priority: Normal
Affected feature: Pinned searches

## Expected behavior

Add profile-owned folders and Unfiled so users can organize searches without
changing their query, refresh checkpoint, previews, or NEW state. Folder
indicators use NEW if any member has NEW; the original roadmap's numeric
folder totals are superseded by PS-001.

## Dependencies and design

- [PS-001](../done/PS-001-bounded-newest-post-refresh.md) is complete.
- Settle the folder persistence/migration and ordering design before code.
- Existing pins migrate to Unfiled. No nested or cross-profile folders.
- See [folder roadmap](../../superpowers/specs/2026-09-14-pinned-searches-design.md#search-folders).

## Acceptance criteria

- [ ] Create, rename, reorder, and delete folders within the owning profile.
- [ ] Move and order searches within folders and Unfiled without losing runtime state.
- [ ] Pin dialog supports choosing a folder, Unfiled, and creating a folder.
- [ ] Deleting a folder moves its searches to Unfiled, preserving their relative order.
- [ ] Folder NEW reflects member flags and updates when a member is opened.
- [ ] Refresh Folder uses the existing refresh service, bounded concurrency,
      never-checked first, then oldest successful checkpoint, then stable ID.
- [ ] Backup/restore includes folder definitions, profile ownership, membership,
      and ordering; runtime refresh data remains excluded.
- [ ] Profile deletion and import handle folder ownership consistently with searches.

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

Folders open a separate page. Searches have manual ordering using Move up and Move down actions.
