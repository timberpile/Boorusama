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

- [x] Create, rename, reorder, and delete folders within the owning profile.
- [x] Move and order searches within folders and Unfiled without losing runtime state.
- [x] Pin dialog supports choosing a folder, Unfiled, and creating a folder.
- [x] Deleting a folder moves its searches to Unfiled, preserving their relative order.
- [x] Folder NEW reflects member flags and updates when a member is opened.
- [x] Refresh Folder uses the existing refresh service, bounded concurrency,
      never-checked first, then oldest successful checkpoint, then stable ID.
- [x] Backup/restore includes folder definitions, profile ownership, membership,
      and ordering; runtime refresh data remains excluded.
- [x] Profile deletion and import handle folder ownership consistently with searches.

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

## Completion — 2026-09-17

Agent: Codex (/root). Branch: `feature/chronological-pinned-search-support`.
209 folder/subscription/backup/profile-operation tests passed and analysis was
clean. Three focused folder tests passed after fixing dialog controller lifetime,
including a regression test for closing text input safely. Android APK built.
Maestro verified folder creation, moving the user's Safebooru pin into a folder,
opening that separate page, and deleting the folder returning the pin to Unfiled.
Temporary test folders were removed. Search ordering is manual via up/down.

Folders are JSON rows in one Hive value per profile in `pinned_search_folders`.
A membership move rewrites one profile value atomically; refresh aggregates
remain independent. Repository mutation serialization covers both stores.
Profile deletion/import compensation restores folders as well as search aggregates;
these operations are not crash-atomic across boxes. Backup version 2 adds folder
rows, including empty folders; version 1 search-only payloads remain supported.
