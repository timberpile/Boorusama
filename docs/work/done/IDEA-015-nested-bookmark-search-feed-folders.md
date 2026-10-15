# IDEA-015 — Hierarchical Folders for Bookmark Groups and Pinned Searches

Priority: Normal

Affected features: Bookmark Groups, Pinned Searches, folder navigation, export/import, persistence, migration

Dependencies: Existing Bookmark Group and Pinned Search infrastructure

Approved follow-up (2026-10-09): Bookmark folders and groups now use alphabetical display order instead of manual ordering. The bookmark UX refinements and verification are recorded below. Pinned Searches retain manual ordering; persistence and the original object-folder architecture remain unchanged.

## 1. Goal

Implement a consistent, arbitrarily nested folder system for organizing Bookmark Groups and Pinned Searches.

The two features may retain separate persistence implementations, but their folder behavior, navigation, terminology, and interactions should be as consistent as practical.

The primary motivation is organizing imported Bookmark Groups from other users separately from personal groups. However, the implementation should support general folder organization rather than being limited to imports.

**Important distinctions:**

- Bookmarks belong to Bookmark Groups, never directly to folders.
- Bookmark Groups belong to at most one folder.
- Independent Pinned Searches belong to at most one folder.
- Folders may contain other folders.
- Following Feeds remain without folder organization for now.
- Bookmark Groups and Pinned Searches have independent folder collections. Folders are not shared across these features.

This task replaces the previously agreed virtual-folder implementation based on `//` delimiters in names.

### Restart instruction

The user has explicitly approved abandoning the previous virtual-folder implementation.

Before starting:

1. Inspect the currently assigned task branch/worktree and identify all changes belonging to the old `//` implementation.
2. Discard those superseded implementation changes, including associated implementation-only tests.
3. Preserve unrelated work, user modifications, and the updated work-item document.
4. If the existing worktree contains unrelated changes, do not reset or delete those changes. Use a fresh isolated task worktree instead.
5. Reimplement the feature from the current local `develop` baseline according to this document.

Do not attempt to incrementally adapt the previous delimiter-based architecture unless there is an independently reusable component that does not carry over its architectural assumptions.

Follow `AGENTS.md`, `docs/development_workflow.md`, and `docs/work/README.md`. Do not modify the primary checkout. Do not merge, push, or open a PR without separate authorization.

---

## 2. Architecture

### 2.1 Parent-reference model

Use parent references rather than parent-owned child-ID arrays.

The conceptual models are:

**Folder**
- `id`: stable UUID
- `name`: display name
- `parentId`: nullable UUID of its parent folder
- `position`: ordering within its parent

**Bookmark Group**
- Existing UUID, name, and bookmark memberships
- `folderId`: nullable UUID
- Ordering position within its folder

**Independent Pinned Search**
- Existing search identity, owner profile, query, and runtime data
- `folderId`: nullable UUID in organizational persistence
- Ordering position within its folder

`null` indicates the collection's root, called Home.

The exact Dart types and persistence boundaries may follow the existing architecture. In particular, Pinned Search folder placement may remain in dedicated organization storage rather than modifying the search subscription's refresh aggregate.

**There must be only one authoritative source for an item's folder membership.** Do not maintain both writable `folderId` and `childIds[]` relationships.

Folder child lists should be derived from parent references. Cache or index these relationships in memory where appropriate.

### 2.2 Core invariants

- Each folder has exactly one parent or belongs to Home.
- Each Bookmark Group or independent Pinned Search belongs to exactly one folder or Home.
- Folders cannot be moved into themselves or their descendants.
- Folder hierarchies cannot contain cycles.
- Folder IDs must reference existing folders within the correct collection.
- A folder may be empty and must remain persisted.
- Folder names must not determine identity or hierarchy.
- Folder names should be unique case-insensitively among siblings, but identical names are allowed in different parent folders.
- Bookmark Group names may remain non-unique, as they are today.
- Folder IDs are stable across rename and move operations.
- Home is an implicit root, not a deletable folder object.
- No arbitrary maximum nesting depth should be imposed by the data model.

Use a predictable fallback or explicit error for invalid references rather than allowing malformed folder structures to crash the application. Validate imported structures before applying them.

Do not implement hierarchy through:
- `//` delimiters,
- parsing group names,
- storing full folder paths as authoritative identities,
- or adding a redundant persistent child list.

### 2.3 Ordering

Preserve manual ordering.

Folders should appear before direct child items, as currently done in Pinned Searches.

Maintain separate, stable sibling ordering for folders and items. Moving an item should update its destination ordering without unnecessarily changing unrelated entries.

Existing Pinned Search sort modes must continue functioning. Non-manual sorting should not overwrite persisted manual order.

The exact representation of ordering can be chosen to fit the existing repositories, but it should remain independent of folder names and hierarchy paths.

### 2.4 Shared implementation

Prefer reusable, type-independent folder-tree logic for:

- Parent/child traversal
- Ancestor and descendant resolution
- Cycle detection
- Recursive operations
- Folder movement
- Breadcrumb generation
- Ordering
- Hierarchy validation
- Recursive counts

Reuse UI components where practical, including folder navigation, folder cards, and the Move destination picker.

Do not force Bookmark Groups, Pinned Searches, and their different repositories into one universal persistence service merely to share implementation.

The desired consistency is primarily behavioral and visual.

---

## 3. Folder UX

### 3.1 Navigation

Both Bookmark Groups and Pinned Searches should use the same conceptual navigation model:

- Home displays root folders and root items.
- Opening a folder displays its direct subfolders and direct items.
- Users can navigate back or use breadcrumbs to navigate to ancestors.
- The current folder is reflected in the AppBar title.
- Navigation must work at arbitrary nesting depths.
- Returning to a previous level should preserve relevant navigation and scroll state where practical.

For Bookmark Groups, retain the existing All and Ungrouped special views at Home. They are not folders, cannot be moved, and cannot be deleted.

For Pinned Searches, Home retains its existing meaning as the root of the independent search collection.

### 3.2 Folder operations

Support:

- Create Folder
- Rename
- Move
- Delete

Use **Move**, not `Move to Folder`, in action menus.

Create Folder creates a folder within the currently opened folder. Creating a folder from Home creates a root folder.

Rename changes only the folder's display name, not any child identities.

Move opens a hierarchical destination picker containing Home and eligible folders.

Moving a folder moves its entire subtree by changing its parent reference. Moving a group/search changes only that item's folder assignment.

Disallow selecting the moved folder or one of its descendants as its destination.

### 3.3 Multi-selection

Support selecting multiple sibling items and moving them together.

Ideally, the selection system should support both folders and leaf items. Moving a selected folder implicitly moves all descendants; selecting both a parent and its descendant must not result in duplicate operations.

Recursive bulk operations should use the same descendant resolution and serialized mutation infrastructure.

Do not add a dedicated recursive-operation framework if existing repository/service operations can be composed safely.

The operation should be planned and validated as a unit before persistence changes.

### 3.4 Delete Folder

There is exactly **one** folder deletion action: `Delete`.

Deleting a folder recursively deletes:

- The selected folder
- All descendant folders
- All leaf items contained anywhere in the subtree

Do not implement separate `Remove Folder`, `Delete Contents`, or `Move Contents to Parent` actions.

Users who want to preserve content must move it elsewhere before deleting its folder.

Before deletion, show a clear confirmation with the actual consequences.

For Bookmark Groups, include:
- Number of folders deleted, including the selected folder
- Number of Bookmark Groups deleted
- Number of unique Bookmarks that will be permanently deleted because they will no longer belong to any surviving group

Example:

**Delete "Cookie"?**

This will permanently delete 4 folders, 12 bookmark groups, and 356 bookmarks that are not in any other group.

For Pinned Searches, include:
- Number of folders deleted
- Number of independent Pinned Searches deleted

Use localized strings.

Cancel must perform no mutations.

Deletion must not begin before confirmation.

### 3.5 Bookmark deletion semantics

Preserve the existing Bookmark Group deletion behavior exactly.

Deleting a group removes its memberships. Bookmarks that no longer belong to any remaining group are permanently deleted. Bookmarks that still belong to another group are preserved.

Deleting a folder must have the same final effect as deleting all contained Bookmark Groups using the existing group deletion rules.

For correctness and performance, implement this as one coordinated operation:

1. Resolve the complete folder subtree.
2. Determine all affected Bookmark Groups.
3. Calculate the final memberships after removing these groups.
4. Identify orphaned Bookmarks.
5. Display the resulting counts in the confirmation.
6. After confirmation, delete the groups, orphaned Bookmarks, and folders through a serialized mutation.
7. Preserve rollback/compensation behavior if any step fails.

Revalidate the deletion preview if the relevant collection changed while confirmation was open.

Avoid repeatedly reloading the complete Bookmark Library after each deleted group.

Preserve the existing active Bookmark Group target behavior: if the active group is deleted, clear the reference safely.

### 3.6 Pinned Search behavior

Migrating folder organization must not change the meaning of an independent Pinned Search.

Preserve:
- Search UUIDs
- Queries and optional names
- Owning profile IDs
- Cached previews
- NEW status
- Refresh checkpoints
- Automatic refresh behavior
- Read state
- Existing search navigation

Folder-level NEW indicators, last-post information, cached previews, and refresh operations must work recursively with descendant searches.

Continue using cached information for folder presentation. Opening a folder must not trigger additional post requests merely to build its previews.

Refresh Folder should include all eligible descendant independent searches, using the existing refresh coordination, rate limiting, and deduplication.

Feed-internal/hidden search sources must remain separate from independent Pinned Searches and must never appear as movable folder items.

Deleting an independent Pinned Search folder must not unintentionally delete Following Feeds or their internal source records.

### 3.7 Other interaction points

Update places that currently assume a flat collection.

In particular:

- Bookmark Group overview
- Bookmark Group creation and duplication
- Bookmark Group picker used by bookmarking actions
- Active Bookmark Group selection
- Pinned Search overview and folder pages
- Pin creation and folder selection
- Edit and Move actions
- Sorting and reordering
- Empty states
- Search/filter controls where already supported

Creating a new group or pin inside a folder should default to that folder. Existing navigation or actions that create an item from outside the folder browser may default to Home unless a destination is explicitly selected.

A Pinned Search edited without changing its folder must retain its placement.

Folder paths are presentation information. They should never replace the UUID identity of a group or pin.

---

## 4. Persistence and Migration

### 4.1 Bookmark Groups

Extend the existing Bookmark Group persistence with a nullable folder assignment.

Introduce persistent folder definitions for the Bookmark Group collection.

Migrate existing data without altering:
- Bookmark identities
- Group UUIDs
- Group names
- Group memberships
- Active Bookmark Group settings
- Bookmark ordering/sorting behavior

All previously existing Bookmark Groups initially belong to Home.

Existing locally stored names containing `//` must remain literal names. Do not reinterpret them as folder paths.

The migration must be backward compatible with previously persisted flat Bookmark Groups.

### 4.2 Pinned Searches

Migrate the existing `SearchOrganization` / `SharedSearchFolder` architecture to the parent-reference model.

Currently, folders contain `searchIds[]`, and Home contains `homeSearchIds[]`.

The new organization representation should use:
- Persistent folders with optional `parentId`
- One authoritative folder assignment per independent search
- Stable ordering within Home or each folder

Migration requirements:

- Preserve every existing folder UUID and name.
- Existing folders initially receive `parentId = null`.
- Preserve current folder/search membership.
- Preserve Home assignments.
- Preserve manual ordering.
- Preserve empty folders.
- Preserve all SearchSubscription runtime data.
- Do not move, recreate, refresh, or reset existing searches during migration.
- Do not modify Following Feed organization or internal sources.

Avoid requiring every SearchSubscription runtime aggregate to be rewritten merely to change its organizational placement if a separate organization record is the cleaner solution.

The migration must be idempotent and survive interruption/restart.

### 4.3 Integrity and transactions

Centralize hierarchy validation.

At minimum, detect:
- Duplicate folder IDs
- Missing parents
- Cycles
- Invalid cross-collection references
- Duplicate item assignments
- Invalid/missing destination folders
- Invalid sibling folder names

All multi-record operations, including moves, recursive deletion, migration, and import, must preserve a consistent final state.

Use the existing serialized mutation and rollback/compensation patterns rather than introducing unrelated storage infrastructure.

Do not silently discard user data when a hierarchy cannot be repaired safely.

---

## 5. Export Format

### 5.1 General rule

**Always export the relevant folder structure.**

Do not introduce separate export modes with or without folder metadata.

Folder definitions are normal collection metadata in `.bsexport`.

For Bookmark Groups, the extended conceptual structure is:

- `folders`: folder records containing UUID, name, parent UUID, and ordering
- `groups`: existing group records with added optional `folderId` and ordering
- `data`: existing Bookmarks/post snapshots, unchanged in meaning

For Pinned Searches, extend the existing Pinned Search backup organization representation to support nested folders and parent-based placement.

Do not merge the Bookmark and Pinned Search backup sources.

### 5.2 Full exports

A full export includes:
- Every folder, including empty folders
- Every group/search belonging to the exported source
- Complete parent relationships
- Ordering
- Existing source-specific data

The exported hierarchy must be sufficient to restore the complete organization.

### 5.3 Selective exports

A custom Bookmark Group export includes:

- The selected Bookmark Groups
- The Bookmarks required by those groups
- Their folder assignments
- The ancestor folders needed to reconstruct their original paths

Do not include unrelated sibling groups merely because they share a folder.

Selecting a folder in a hierarchical export-selection UI should select all descendant groups.

For explicitly selected empty folders, preserve them if supported by the selection UI. Otherwise, a custom export may omit unused, unselected empty folders.

The source hierarchy should remain recognizable even when only a subset of groups is exported.

### 5.4 Compatibility

The current Bookmark backup schema is version 4.

Introduce a properly versioned schema extension, preserving support for the existing version-4 format.

Older compatible backups without folder information must import as flat collections with all items in Home.

Do not weaken existing bookmark identity validation or resurrect unsupported legacy schemas.

Validate incoming folder IDs, parent references, and item assignments before applying changes.

A malformed folder tree must not produce partial imports.

Update the corresponding Pinned Search backup schema/codec with appropriate backward compatibility for existing exports.

---

## 6. Bookmark Import Semantics

**Keep the current import UI as simple as possible.**

The existing Import Flow already supports source-level and per-group actions. Do not introduce separate folder conflict dialogs, folder mapping forms, or a complex destination configurator.

Folder handling should be derived automatically from the chosen group actions.

### 6.1 Existing per-group actions

| Action | Group behavior | Folder behavior |
| --- | --- | --- |
| Update | Replace the existing group's memberships | Preserve local folder |
| Merge | Add imported memberships to the existing group | Preserve local folder |
| Merge into | Add imported Bookmarks to another selected local group | Preserve target group's local folder |
| Copy | Create a new Bookmark Group | Reconstruct imported hierarchy under an automatic import folder |
| Skip | Do not import the group | Do nothing |

Do not add a per-group Replace action. The current individual-group Update behavior should remain unchanged.

In particular, Update, Merge, and Merge into must not rename or relocate existing local groups because of folder information in the export.

### 6.2 Automatic import folder for copied groups

When an import creates one or more Bookmark Groups using Copy, automatically create one top-level container folder for those copies.

Suggested default name: `Imported Groups`.

Avoid naming collisions by assigning a distinct name such as `Imported Groups (2)` when necessary. Do not automatically merge with an existing folder merely because its name matches.

Only create this wrapper folder when at least one group is actually being copied.

Within the wrapper, reconstruct the required source hierarchy for copied groups.

Example incoming organization:

- Cookie
  - Anime
    - Group A
  - Manga
    - Group B
- Another Person
  - Group C
- Group D (Home)

If all four groups are copied, the resulting local organization is:

- Imported Groups
  - Cookie
    - Anime
      - Group A
    - Manga
      - Group B
  - Another Person
    - Group C
  - Group D

Only the wrapper is new to the hierarchy; the paths below it mirror the source.

### 6.3 Mixed import actions

Consider the same input with these actions:

- Group A: Copy
- Group B: Update
- Group C: Copy
- Group D: Skip

The importer must create:

- Imported Groups
  - Cookie
    - Anime
      - Group A
  - Another Person
    - Group C

Group B updates its existing local group in its existing local folder.

Group D is skipped.

Do not create:
- Cookie/Manga solely because Group B was updated
- Any folder solely needed by skipped groups
- Empty unused ancestors
- A second wrapper for the same import transaction

This must work with arbitrarily many groups across unrelated source trees.

### 6.4 Identity and folder mapping

Use the existing imported group UUID / selected import action logic to determine whether a group is copied, updated, merged, or skipped.

For copied groups:
- Preserve the imported display name.
- Allocate a new group UUID when required to avoid local collisions.
- Create fresh local folder identities beneath the wrapper.
- Reconstruct source ancestor relationships by exported folder UUIDs.
- Reuse the same newly created ancestor folder for multiple copied groups from the same source branch.
- Never match unrelated local folders by display name.
- Preserve relative order within the copied hierarchy.

For existing groups:
- Preserve their local group identity and folder assignment.
- Do not create their source folders unless needed by some other copied group.

The wrapper and reconstructed folders must participate in the same import transaction and rollback as the copied groups.

If the user cancels or the import fails, no temporary import folder may remain.

A repeated import that performs only Update/Merge/Skip must not create another import folder.

An explicit new Copy operation in a later import may create a new independent wrapper and fresh group copies.

### 6.5 Import UI

Do not add folder action dropdowns for Bookmark Groups.

Continue using the existing item action selector:
- Update
- Merge
- Merge into
- Copy
- Skip

It is acceptable to show a concise, non-interactive summary in the existing import preview, for example:

`2 groups will be copied into Imported Groups.`

The user can reorganize groups after import using Move.

The existing import-change preview should correctly account for folder creation and show the resulting changes without requiring another screen.

Do not introduce a mandatory folder configuration step.

### 6.6 Full Bookmark category Replace

This is separate from per-group Update.

When the user selects **Replace for the entire Bookmark category**, restore the complete exported Bookmark collection and its folder structure.

This is particularly important for:
- Restoring a personal full backup
- Migrating to a new device
- Recovering app data

Required behavior:

- Replace existing Bookmark data and Bookmark Groups according to the current category-Replace semantics.
- Replace the Bookmark folder organization with the exported organization.
- Preserve the exported hierarchy, including empty folders and ordering.
- Do not create an `Imported Groups` wrapper.
- Do not merge the exported folders into the previous local hierarchy.
- Do not affect Pinned Search folders or Following Feeds.
- Restore safely from rollback data if any part of the operation fails.

For an older compatible backup with no folder metadata, the resulting replaced collection is flat in Home.

Ensure that the package transaction's rollback snapshot also includes the previous local folder structure.

### 6.7 Existing import infrastructure

Integrate this with the current:
- `ImportFlowNotifier`
- `ImportPlanner`
- `BookmarkImportPlanner`
- `BookmarkImportService`
- `BookmarkBackupCodec`
- Import preflight/projector
- Import change preview
- Durable package transaction/rollback system

Do not implement a separate second Bookmark import workflow.

Preserve profile resolution, canonical bookmark identity, group conflict handling, existing Merge into target selection, and the completed import fixes.

---

## 7. Pinned Search Import/Export

Pinned Searches must use the same hierarchical folder concepts.

Preserve the existing distinction between:
- Independent Pinned Searches
- Feed-owned internal search sources
- Shared folders
- Home

Extend Pinned Search exports to retain:
- Folder UUIDs
- Parent relationships
- Search placements
- Ordering
- Existing independent search definitions

A full Pinned Search category Replace should restore the exported independent-search hierarchy, while preserving whatever feed-internal source handling the existing implementation requires.

For ordinary imports:
- Existing independent searches should not be moved merely because the incoming package contains a different folder location.
- Newly created searches should inherit the relevant exported hierarchy.
- Imported folder identities must be mapped safely and must not accidentally collide with unrelated local folders.
- Avoid introducing new complex folder mapping UI.

The existing Pinned Search import currently supports its own folder-related actions. Inspect and adapt these carefully rather than assuming the Bookmark Group import planner can replace them directly.

Preserve the existing import deduplication and profile resolution behavior.

Keep the normal Pinned Search import experience as close to the existing implementation as possible.

Where appropriate, use the same automatic import-wrapper principle for newly created independent searches, using a collection-specific name such as `Imported Searches`.

Do not silently reorganize existing searches or modify Following Feeds.

---

## 8. UI and Functional Consistency

Bookmark Groups and Pinned Searches should share these conventions:

| Feature | Bookmark Groups | Pinned Searches |
| --- | --- | --- |
| Home/root | Yes | Yes |
| Nested folders | Yes | Yes |
| Empty folders | Yes | Yes |
| Create Folder | Yes | Yes |
| Rename Folder | Yes | Yes |
| Move | Yes | Yes |
| Multi-select Move | Yes | Yes |
| Recursive Delete Folder | Yes | Yes |
| Breadcrumbs | Yes | Yes |
| Manual sibling order | Yes | Yes |
| Folder-level cached summaries | Where applicable | Yes |
| Hierarchy-aware export | Yes | Yes |
| Full hierarchy restore | Yes | Yes |

Keep feature-specific behavior where necessary.

For example:
- Bookmark Group deletion applies bookmark orphan-cleanup rules.
- Pinned Search deletion removes independent subscriptions.
- Pinned Search folders aggregate NEW/refresh information.
- Bookmark Group contents are Bookmark posts.
- Search and filtering capabilities may differ.

Do not add folder support to Following Feeds in this task.

---

## 9. Testing and Verification

### 9.1 Folder model

Add focused tests for:

- Root folders
- Arbitrary nesting
- Empty folders
- Folder creation and rename
- Moving items
- Moving entire subtrees
- Moving multiple selected items
- Moving to Home
- Cycle prevention
- Invalid parent references
- Duplicate folder names under different parents
- Sibling name collisions
- Stable UUIDs and ordering
- Deep hierarchies
- Persistence across app restart

### 9.2 Bookmark Groups

Verify:

- Existing flat groups migrate to Home.
- Existing memberships remain unchanged.
- Duplicate group names continue working.
- Groups cannot be confused with folders.
- Creating a group within a folder assigns that folder.
- Group and folder pickers work with nesting.
- Group deletion retains existing orphan-cleanup behavior.
- Recursive folder deletion deletes all descendant groups.
- A Bookmark belonging to a surviving outside group remains.
- A Bookmark belonging only to deleted groups is deleted exactly once.
- Cancellation changes nothing.
- Active group references remain valid or are cleared when deleted.
- Failures do not leave a partially deleted collection.

### 9.3 Pinned Searches

Verify:

- Existing folder organization migrates without losing data.
- Search UUIDs and profile associations remain unchanged.
- Manual ordering is preserved.
- Queries, preview caches, checkpoints, and NEW state are preserved.
- Folder navigation works recursively.
- Folder refresh includes descendant independent searches.
- Folder summaries aggregate descendant data correctly.
- Folder rendering does not introduce additional post requests.
- Recursive deletion does not affect unrelated searches or Following Feeds.
- Search editing retains folder placement.
- Profile switching/navigation still works.

### 9.4 Export/Import

Cover at least these scenarios:

1. Full Bookmark backup with multiple folder levels and empty folders.
2. Full Bookmark category Replace restoring the exact hierarchy.
3. Legacy version-4 Bookmark backup imported into Home.
4. Selective export of one group nested several levels deep.
5. Selective export without unrelated sibling groups.
6. Copy of groups from multiple unrelated folder trees.
7. Mixed Copy, Update, Merge, Merge into, and Skip in one import.
8. Updating an existing group without changing its folder.
9. Merge into a group located in a different local folder.
10. Import with only Update/Merge/Skip creating no wrapper.
11. Copied groups creating exactly one import wrapper.
12. UUID collisions for groups and folders.
13. Identical names in unrelated folder branches.
14. Repeated imports and explicit new Copies.
15. Malformed or cyclic exported folder relationships.
16. Cancelled import leaving no folder changes.
17. Failed import restoring the previous folder structure and memberships.
18. Pinned Search full backup/restore with nested folders.
19. Pinned Search import preserving existing search placement.
20. Pinned Search migration preserving feed-internal sources and refresh state.

The import preflight and projected change summary must agree with what the transaction actually applies.

Use integration tests around the real import planner/service/transaction boundaries rather than only testing pure folder-tree helpers.

### 9.5 UI verification

Exercise on Android using Maestro where device testing is appropriate:

- Root and nested folder navigation
- Create, Rename, Move, Delete
- Multi-selection and moving items
- Deep nesting
- Delete confirmation
- Bookmark Group picker
- Pinned Search navigation and refresh
- Export and import of nested groups
- Narrow screen widths
- Enlarged system text
- Empty folders and empty collections

Ensure that long paths and folder names do not cause layout overflow.

Follow the repository's emulator leasing procedure before device operations.

Run relevant focused tests and analyzer checks. Since the work spans persistence, migration, backup transactions, and two subsystems, also run the full test suite before declaring completion.

---

## 10. Implementation Approach

Suggested execution order:

### Phase 1 — Inspect and design

- Discard the superseded task implementation safely.
- Inspect current local `develop`.
- Read the existing Bookmark Group, Pinned Search, and import architecture.
- Identify migration and backup compatibility requirements.
- Choose the shared folder-tree abstraction and persistence boundaries.
- Keep the design aligned with the decisions above.

### Phase 2 — Core folder model

- Implement folder entities and parent-reference relationships.
- Implement traversal, validation, ordering, and Move operations.
- Add focused model tests.

### Phase 3 — Bookmark Group migration and UX

- Persist Bookmark folders and group assignments.
- Migrate existing flat groups.
- Implement the nested browser and navigation.
- Update group creation, selection, and movement.
- Implement recursive Delete Folder with existing Bookmark deletion semantics.

### Phase 4 — Pinned Search migration and UX

- Migrate SearchOrganization.
- Preserve existing search state and ordering.
- Adapt existing folder UI and repository operations.
- Extend cached folder aggregations and refresh across descendants.

### Phase 5 — Export/import

- Extend Bookmark backup format and selective export.
- Update Bookmark import planning and transactions.
- Implement automatic copy-wrapper behavior.
- Extend Pinned Search backup and import.
- Add backward compatibility and rollback coverage.

### Phase 6 — Verification

- Focused tests
- Import/restore integration tests
- Persistence migration tests
- Targeted analysis and formatting
- Full Flutter suite
- Android UI verification
- Documentation updates
- Final review of regressions and unexpected scope changes

These phases are a suggested sequence, not a requirement to create separate tickets, branches, or implementation agents.

---

## 11. Relevant Code and Documentation

Review these files and their current callers before modifying them:

**Workflow**
- `AGENTS.md`
- `docs/development_workflow.md`
- `docs/engineering_guidelines.md`
- `docs/work/README.md`

**Bookmark Groups**
- `docs/bookmark_groups.md`
- `lib/core/bookmarks/src/types/bookmark_group.dart`
- `lib/core/bookmarks/src/types/bookmark_group_repository.dart`
- `lib/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart`
- `lib/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart`
- `lib/core/bookmarks/src/types/bookmark_library_state.dart`
- `lib/core/bookmarks/src/services/bookmark_library_service.dart`
- `lib/core/bookmarks/src/providers/bookmark_provider.dart`
- `lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart`
- `lib/core/bookmarks/src/widgets/bookmark_group_picker.dart`

**Pinned Searches**
- `docs/pinned_searches.md`
- `lib/core/search/subscriptions/src/types/search_organization.dart`
- `lib/core/search/subscriptions/src/providers/search_subscriptions_notifier.dart`
- `lib/core/search/subscriptions/src/providers/search_subscription_selectors.dart`
- `lib/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart`
- `lib/core/search/subscriptions/src/pages/pinned_searches_page.dart`
- `lib/core/search/subscriptions/src/widgets/pinned_search_folder_card.dart`

**Export/Import**
- `lib/core/backups/sources/bookmark_backup_data.dart`
- `lib/core/backups/sources/bookmark_backup_codec.dart`
- `lib/core/backups/sources/bookmark_import_planner.dart`
- `lib/core/backups/sources/bookmark_import_service.dart`
- `lib/core/backups/sources/bookmarks_source.dart`
- `lib/core/backups/sources/pinned_search_backup_data.dart`
- `lib/core/backups/sources/pinned_search_backup_codec.dart`
- `lib/core/backups/sources/pinned_search_import_service.dart`
- `lib/core/backups/export_import/import/import_flow_notifier.dart`
- `lib/core/backups/export_import/import/import_planned_change_projector.dart`
- `lib/core/backups/export_import/widgets/import_action_editor.dart`
- `lib/core/backups/export_import/models/export_selection.dart`

**Related completed work**
- `BM-005` — Preserve local group name on import update
- `DATA-001` — Unified export/import
- `DATA-011` — Bookmark Merge into target selection
- `PS-018` — Pinned Search folder navigation

Coordinate with other active work items touching the same browser, import, or UI components.

---

## 12. Explicitly Out of Scope

Do not implement:

- Folder organization for Following Feeds
- Direct Bookmark membership in folders
- A second Bookmark hierarchy independent of Bookmark Groups
- Folder sharing permissions
- Network/cloud folder synchronization
- Arbitrary aliases or multiple parents per folder
- Folder placement based on `//` or other naming conventions
- Mandatory import folder-selection dialogs
- Different export formats depending on whether folders are included
- Separate Remove Folder and Delete Folder & Contents actions
- Unrelated changes to search matching, refresh algorithms, or Bookmark identity

Do not redesign the general export/import workflow beyond what is necessary for nested folder support.

## 13. Definition of Done

The implementation is complete when:

- Existing Bookmark Groups and Pinned Searches migrate without data loss.
- Both systems support arbitrary nested folders with consistent navigation and actions.
- Folder membership uses parent references rather than path strings or authoritative child lists.
- Move, multi-selection, and recursive Delete work correctly.
- Bookmark deletion preserves existing orphan-cleanup behavior.
- Pinned Search caches, profiles, and refresh state remain intact.
- Full exports preserve folder organization.
- Full category Replace restores the exported organization.
- Per-group Update/Merge/Merge into preserve local placement.
- Copied Bookmark Groups automatically reconstruct source paths under one new import folder.
- Existing compatible backups still import correctly.
- Import cancellation and failure leave no partial folder structures.
- Relevant automated tests and Android UI checks pass.
- Documentation reflects the final architecture.
- The final implementation is isolated, reviewed, and ready for separately authorized integration.

## Final Implementation Notes

This document supersedes the prior IDEA-015 design based on virtual folder paths encoded in names.

The previous approach was intentionally simple, but the approved requirements now include reusable folder UX, arbitrary nesting, folder movement, stable identity, complete backup restoration, and consistent behavior across Bookmark Groups and Pinned Searches.

The parent-reference architecture is the approved replacement.

**Do not continue implementing the old `//`-based design.**

Implement the approved behavior directly, document significant technical choices, and report the completed changes, tests, migration results, and any remaining limitations before requesting integration.
## Completed implementation

Implementer: Codex, current session. Branch: `agent/idea-015-virtual-group-folders`.
Worktree: `.worktrees/idea-015-virtual-group-folders`. The superseded delimiter implementation was discarded and the updated specification preserved. Implementation started from `f9fcf27bf` and was rebased onto local develop `e5894fec0` without conflicts; current repository instructions were reread after rebase.

## Replacement implementation evidence

- Stored UUID folders and authoritative parent/item placements replace all delimiter-derived folder behavior. Names such as `Cookie//Artists` stay literal. Bookmark folders use the `bookmark_folders` Hive box and group adapter fields 3/4; independent search organization uses one version-2 record.
- Shared tree validation, breadcrumbs, and destination picker support arbitrary nesting, empty folders, sibling-name validation, subtree moves, and multi-selection. The browsers return to existing ancestor routes and fall back to Home if an open folder disappears.
- Bookmark folder deletion previews the exact subtree and unique orphans, preserves outside memberships and ungrouped bookmarks, revalidates confirmation, clears affected active targets, and compensates failed writes. Search deletion and refresh cover descendant independent searches while retaining unrelated feeds and runtime data.
- Bookmark exports use version 5 with version-4 compatibility. Pinned search exports use version 2 with version-1 compatibility; Following Feed format remains unchanged. Selective exports retain only selected descendants and their ancestor closure. Full category Replace retains exported empty folders.
- Mixed group imports retain the existing action UI and local placement. Only actual group copies reconstruct their required branches below one fresh localized import wrapper. Ordinary search imports preserve existing search placement/runtime; explicit folder actions and full Replace retain their existing UI semantics with nested organization.
- Real Hive migration/reopen, legacy binary adapter, import service/transaction, rollback, malformed hierarchy, selective export, cached state, active target, narrow-layout, breadcrumb, and selection regression tests were added.
- Automated verification: real repository/service migration and compensation tests, legacy binary adapter reads, nested export/import, malformed hierarchy, mixed selection, cached summaries, and narrow-width/enlarged-text widget checks passed. Scoped analysis reported no errors or warnings (70 informational style suggestions). The final export-state correction has a regression test and 40 passing focused export/backup tests; its scoped analysis reports no issues.
- Final full suite after rebase and the export-state correction: **2,956 passed, nine failed**; all nine failures are the unchanged baseline cases described below. Nine unchanged Following Feed timestamp/never-checked widget failures were reproduced on both the original `f9fcf27bf` baseline and the exact rebased parent `e5894fec0` (11 passing, nine failing in that file). Following Feed behavior and its failing tests were not changed by this task. Fresh generated i18n and client outputs were produced for the rebased inputs. The disposable baseline checkout and branch were removed after confirming clean state and removing only known generated artifacts.
- Final Android dev APK built successfully. Maestro on exclusively leased emulator-5554 exercised nested and empty folders, literal names, create/rename, subtree Move to Home, mixed multi-select Move, recursive deletion/cancellation, nested pin creation, recursive refresh, and doubled system text with narrow width and keyboard open. The bookmark picker displayed the full nested path and stored a post in the selected group. A bookmark-only Custom export was copied through the existing Base64 clipboard flow; Android import review showed the nested path, Copy created one fresh Imported groups wrapper with the required source ancestors, and deleting the copied hierarchy preserved the original group and its bookmark. All QA folders, searches, groups, and bookmarks were then removed; the bookmark library returned to its initial zero-bookmark state. Original display/text settings were restored and the emulator lease released. No physical device was used.
- Android export validation exposed an existing state reset when the source catalog refreshes. The export notifier now reads current descriptors on demand without reinitializing the export mode, collection selection, or credential choice; the reproduced regression passes and the device round trip succeeds.
- Delivery remains an isolated local task branch for review. No integration, publication, or remote operation was performed; the primary checkout remains untouched. The task worktree is retained with the built APK for review.

## Completed bookmark UX follow-up — 2026-10-09

- Replaced the bookmark browser's two creation buttons with an overflow menu containing “Add groups folder” and “Add group”. Creation uses the current folder. Folders appear first, followed by groups; both sort case-insensitively by name with UUID ties. Stored positions remain compatible but are ignored for bookmark display. Bookmark Move Up/Down actions and their unused service/provider methods were removed. Pinned Searches retain their existing manual ordering.
- All and No Group stay first at Home, separated by a subtle divider. During structural selection they are greyed out, expose disabled accessibility semantics, and ignore taps. Normal navigation resumes after selection ends.
- Bookmark Move opens in the current browser folder (the selected entries' parent). Folder taps navigate; Move here confirms the current destination, including Home. No-op destinations are disabled, and moved folder subtrees remain excluded.
- One shared hierarchical picker now serves the regular bookmark dialog, anchored menu, post context menu, modern bulk Add/Remove, and legacy bookmark-list bulk Add/Remove. It shows direct folders before direct groups, uses leaf group names, supports breadcrumbs and Back at arbitrary depth, resets scroll after navigation, and creates groups inside the displayed folder. Existing membership operations remain intact.
- For a single bookmark, folder icons show the number of descendant groups containing that bookmark. Local membership IDs are aggregated once from leaves to parents in O(folders + groups), counting each group ID once, and cached for the library snapshot. Zero badges are hidden; counts above 99 display 99+ with the complete count available to accessibility. Counts refresh when memberships change. Multi-bookmark pickers omit these badges. No network requests are used.
- This follow-up does not change folder persistence/migrations, recursive deletion, import/export contracts, Pinned Search behavior, or BM-008 Default-group migration.

Verification for this follow-up:

- **329 related tests passed**, including **27 new focused UX tests** and existing bookmark membership/repository/rollback, shared folder, backup, and Pinned Search manual-order regression coverage.
- New widget checks cover all seven picker entry points, current-folder creation, ordering and rename, mixed selection and Move, disabled special entries, deep/repeated names, recursive badge updates and accessibility, multi-bookmark badge suppression, narrow layouts, doubled text, and an open keyboard in the naming dialog.
- Changed Dart files were formatted with FVM; scoped analysis reports no errors or warnings. The two remaining informational suggestions are existing bookmark-browser lints. Generated translations were refreshed with `./gen.sh i18n`. `git diff --check` passed.
- `fvm flutter build apk --debug --flavor dev --no-pub` succeeded. No Android emulator was connected (`adb devices -l` was empty), so no Maestro or live Android validation was performed for this follow-up. Earlier device evidence above applies to the original object-folder implementation only.
- Changes remain on `agent/idea-015-virtual-group-folders` in the existing isolated worktree. No merge, publication, or remote operation was performed.

## Completed popup consistency and pinned-selection follow-up — 2026-10-09

- Added short UI consistency guidance to AGENTS.md and the engineering guidelines: inspect comparable interactions, reuse application components and established sizing/spacing, and prefer consistently styled Kurumi menus.
- Bookmark context and viewer long-press popups now share compact Kurumi menu rows through the existing hierarchical picker. Back has a divider directly below it, and Create New Group has one immediately above it at every applicable level. Viewer buttons use KurumiAnchor with the Download menu's 200-pixel content width and 8-pixel padding, with bounded scrollable height. Nested navigation, local recursive membership badges, membership indicators, and current-folder creation remain intact; the larger dialogs keep their existing presentation. The anchored active-target label uses an accessible check indicator to fit enlarged text without overflow.
- Pinned searches and folders enter selection on long-press. Taps then toggle selection; selected cards expose accessibility state, a highlighted border/background, and a check indicator. The AppBar displays the count, Move, and Cancel while hiding Sort and the regular overflow. Item action menus are hidden during selection and work normally outside it. Deselecting the last item exits selection; Cancel and a completed Move clear both selection sets. Folder navigation, Move semantics, sorting, persistence, and refresh behavior remain unchanged.
- **334 related tests passed**, including focused compact-row/divider, nested popup, 40-group scrolling, actual viewer long-press, pinned search/folder selection, mixed Move, Cancel, deselection, and AppBar checks. Narrow-width and doubled-text checks pass, as do the existing dialog/keyboard and membership regressions. Changed Dart files were formatted with FVM. Scoped analysis reports no errors or warnings and one existing informational pinned-browser lint. `git diff --check` passed.
- The dev debug APK built successfully. Read-only ADB discovery found no connected devices; no Maestro/device interaction was performed for this follow-up. No folder data-model changes, integration, publication, or release operation was performed.

## Completed pinned-search destination picker follow-up — 2026-10-09

- Pin Search and Manage Pinned Search now reuse the shared folder destination dialog instead of a dropdown of flattened paths. It starts in the saved destination, lists only direct child folders, navigates on folder taps, and confirms the current location (including Home) with Select. Breadcrumbs and Back provide parent/Home navigation. The field displays the selected folder's leaf name; cancelling navigation leaves the draft destination unchanged. The existing dialog composition applies this behavior to both creation and editing without changes to pin persistence or query/profile behavior.
- Shared destination-picker title and creation eligibility are optional; existing bookmark/pinned Move callers keep their defaults. The existing New Folder flow still names and creates a root folder after pin submission, so its action is offered at Home. Current folder ordering is retained. No folder data model or import/export changes were made.
- Six new focused widget/integration tests cover nested direct-child navigation, deep selection, saved-destination preservation, Cancel, Home with and without folders, existing New Folder results, narrow width/doubled text/keyboard, and actual search-page creation/editing into a deep folder. Existing transaction, duplicate-name, rollback, cancellation, cross-profile assignment, and refresh-failure tests were updated for explicit navigation/confirmation and still pass.
- **398 related tests passed** across bookmarks, shared folders, pinned-search browsers, destination selection, and search-page pin actions. Changed Dart files were formatted with FVM; scoped analysis reports no errors or warnings and seven existing informational redundant-argument suggestions in the search-page test. `git diff --check` passed. The dev debug APK built successfully. No live device interaction was performed. Delivery remains on the isolated task branch; no integration or publication was performed.
