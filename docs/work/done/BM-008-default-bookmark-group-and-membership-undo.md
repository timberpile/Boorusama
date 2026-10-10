# BM-008 — Replace Ungrouped with a Default Group and Consistent Membership Removal

Priority: Normal  
Affected features: Bookmarks, Bookmark Groups, bulk actions, post actions, persistence, migration, export/import  
Dependencies: IDEA-015 (hierarchical Bookmark Group folders); UX-002 should build on this work

## Problem

Bookmark management currently has inconsistent semantics.

Bookmarks may exist without any group membership. These appear in the virtual `Ungrouped` collection, represented internally by a null group target.

In addition, removal behavior depends on which interface performs the operation:

- Some single-post removal actions delete the Bookmark when its last group membership is removed.
- Bulk `Remove from Group` preserves the Bookmark without memberships, placing it under Ungrouped.
- Bulk `Delete` removes the Bookmark completely, including all group memberships.
- The distinction between Remove and Delete is not immediately obvious to users.

The desired model is simpler: **every persisted Bookmark belongs to at least one real Bookmark Group.**

Introduce a permanent system group named `Default`, remove the special Ungrouped concept, and make all user-facing Bookmark operations group-specific.

## Approved Behavior

### 1. Permanent Default Group

Introduce a real Bookmark Group with the system role `Default`.

Requirements:

- Exactly one Default Group exists in every Bookmark Library.
- The Default Group has a stable UUID.
- Its system identity must not be inferred from its display name.
- It cannot be deleted.
- It cannot be renamed.
- It cannot be moved into a folder.
- It remains at the root/Home of the Bookmark Group hierarchy.
- It cannot be converted into an ordinary group.
- Other ordinary groups may have the same display name without acquiring system-group behavior.
- It supports normal Bookmark membership operations.
- It appears in the normal Bookmark Group browser and group-selection UI.
- It persists across restarts, backups, imports, and migration.

The Default Group is not merely a virtual alias for Bookmarks without memberships.

`All` remains a virtual view of the entire Bookmark Library. It is not a real group.

Remove the separate `Ungrouped` view from the user interface.

### 2. Membership Invariant

Every persisted Bookmark must belong to at least one real Bookmark Group.

A Bookmark may belong to multiple groups simultaneously.

When a new Bookmark is created:

- If no explicit target group was selected, save it in Default.
- If an explicit target group was selected, save it in that group.
- If the Bookmark already exists in Default and is subsequently added to another group, retain its Default membership.
- Never automatically remove a Bookmark from Default merely because it was added elsewhere.
- Do not create additional or hidden group memberships during ordinary Add operations.

Removing a Bookmark's final group membership permanently removes the Bookmark from the library.

This invariant must be enforced consistently, not only in the UI.

### 3. User-Facing Actions

The user-facing Bookmark Management actions are:

**Add to Group**
- Select exactly one destination group.
- Add the selected Bookmark(s) to that group.
- Preserve all existing memberships.
- Ignore already-existing memberships without duplicates.

**Remove from Group**
- Select exactly one source group.
- Remove the selected Bookmark(s) from that group.
- Preserve memberships in other groups.
- If a Bookmark has no remaining memberships, permanently delete it.
- Removing a Bookmark from Default is explicitly allowed.
- Removing a Bookmark from Default does not affect any other groups.

Do not provide a general user-facing `Delete from All Groups` or `Delete Bookmark Everywhere` operation.

Users who wish to remove a Bookmark completely can remove its remaining group memberships. If it belongs to several groups, this must be done explicitly per group, unless an ordinary group deletion or folder deletion removes those memberships as part of its established behavior.

Keep internal deletion APIs where needed for migrations, maintenance, backup replacement, and other legitimate repository operations. Removing the global Delete UI must not break internal data-management infrastructure.

### 4. Consistency Across Single and Multiple Posts

The exact same membership semantics must apply when actions originate from:

- A single post's Bookmark controls
- The Post Viewer
- The Bookmark Group grid
- Multi-selection actions
- The `All` view
- Default and ordinary Group views
- Bookmark Group pickers and management dialogs
- Other existing Bookmark action entry points

There should be no difference in whether an orphaned Bookmark is deleted based on which UI invoked Remove.

For example:

| Initial memberships | Operation | Result |
| --- | --- | --- |
| Default | Add to Artists | Default, Artists |
| Default + Artists | Remove from Default | Artists |
| Default + Artists | Remove from Artists | Default |
| Artists + Favorites | Remove from Artists | Favorites |
| Artists | Remove from Artists | Bookmark deleted |
| Default | Remove from Default | Bookmark deleted |

When invoking Remove from an `All` view or another context without an implicit source group, require an explicit group selection rather than deleting all memberships.

For bulk actions involving posts with different memberships, only remove memberships that actually exist in the selected source group.

Do not silently apply Remove to unrelated groups.

### 5. No Routine Destructive Confirmation Dialog

Removing the last membership will frequently occur during normal Bookmark management.

**Do not show a confirmation dialog every time a Bookmark loses its final membership.**

The action should execute directly and provide feedback through an Undo Snackbar.

This applies to both single and bulk removal operations.

The Snackbar should communicate the result accurately.

Examples:

- `Removed from Artists · Undo`
- `Bookmark deleted · Undo`
- `12 removed, 4 bookmarks deleted · Undo`

The final phrasing should use the existing localization conventions.

For bulk operations, show one aggregate message rather than one Snackbar per Bookmark.

Avoid double confirmations and unnecessary interruption of the user's normal workflow.

### 6. Reliable Undo

Undo must restore the state affected by the preceding membership removal.

If Remove only changed membership:
- Restore the removed membership.

If Remove deleted a Bookmark because its last membership disappeared:
- Restore the Bookmark's complete stored snapshot.
- Restore its previous group membership.
- Preserve its canonical post identity and relevant Bookmark metadata.

For bulk removal:
- Undo the entire successful operation as one logical unit.
- Restore only memberships actually removed by that operation.
- Restore Bookmarks actually deleted by that operation.

Requirements:

- Use the existing serialized Bookmark mutation infrastructure.
- Preserve consistency if another Bookmark operation occurs while the Snackbar is visible.
- Avoid overwriting unrelated changes made after the removal.
- Do not resurrect a deleted group or restore a membership to a group that no longer exists without an explicitly safe resolution strategy.
- Handle failed Undo operations with appropriate user feedback.
- Avoid leaving orphaned Bookmark records when the Snackbar expires or the app restarts.
- Do not depend on an in-memory state that can corrupt the persisted library if the app terminates.

The implementer may choose between immediate persisted mutation with a reversible snapshot and another robust design, provided these requirements are met.

The implementation should not introduce a general-purpose undo framework beyond the needs of this feature.

### 7. Group and Folder Deletion

Preserve the already approved semantics for deleting Bookmark Groups and hierarchical folders.

Deleting an ordinary Bookmark Group:
- Deletes the group.
- Removes its memberships.
- Deletes Bookmarks that are no longer members of any surviving group.
- Preserves Bookmarks with surviving memberships elsewhere.

Deleting a Bookmark folder:
- Recursively deletes descendant folders and groups.
- Applies the same orphan-cleanup semantics across the complete operation.
- Preserves Bookmarks still referenced by surviving groups, including Default.

The Default Group cannot be included in ordinary group or folder deletion because it is a protected Home-level system group.

Retain the explicit confirmation dialogs for deleting entire groups or folder subtrees.

The lightweight removal Undo Snackbar does not replace the existing safety checks for these larger destructive operations.

Coordinate these behaviors with IDEA-015 rather than implementing competing recursive deletion logic.

---

## Data Model and Migration

### 8. System Group Identity

A system group must have a reliable, stable identity independent of its name.

Choose a representation compatible with the existing UUID-based group repository, such as a reserved UUID and explicit system-role semantics.

Requirements:

- Detect the Default Group by identity/role, not name comparison.
- Prevent duplication of the system role.
- Prevent deletion, rename, or relocation at the service/repository level, not just through hidden UI buttons.
- Preserve compatibility with ordinary, non-unique group names.
- Ensure an existing ordinary group called `Default` is not silently converted into the system group.
- Keep the system group distinguishable in backup and import logic.

### 9. Existing Local Data Migration

Migrate the current flat Bookmark model safely.

Currently, group memberships are stored in Bookmark Groups, while `Ungrouped` is represented by the absence of any membership.

Migration must:

1. Ensure the Default Group exists.
2. Identify existing Bookmarks with no group membership.
3. Add those Bookmarks to Default.
4. Preserve all other Bookmark memberships.
5. Preserve existing ordinary group UUIDs and names.
6. Preserve Bookmark metadata, identities, and timestamps.
7. Replace the old null/ungrouped active target with Default where applicable.
8. Remove the separate Ungrouped view and related user-facing terminology.
9. Leave `All` as the aggregate view.

The migration must be idempotent and must not delete existing Bookmarks.

Handle interrupted migrations and repeated application safely.

Any app settings, UI state, or saved references targeting the old Ungrouped collection must resolve to the new Default Group.

### 10. Integration with Hierarchical Folders

IDEA-015 introduces persistent folders with parent references and group `folderId` references.

The Default Group:
- Always belongs to Home.
- Has no movable folder assignment.
- Is excluded from recursive folder deletion.
- Is shown alongside other root-level groups.
- Can still be targeted by normal Bookmark membership actions.

Coordinate changes to `BookmarkGroup`, its Hive persistence, repository interfaces, selectors, and browser with the IDEA-015 implementer.

**Do not develop conflicting schema migrations in parallel without coordination.**

Prefer implementing this after the updated IDEA-015 architecture is integrated, or coordinate a single compatible persistence change with its owner.

### 11. Export and Import

The existing `.bsexport` functionality must remain valid.

Extend the new folder-aware Bookmark backup schema to represent the Default Group's system role.

Requirements:

- Full backups preserve Default membership alongside ordinary groups and folder structure.
- Full Bookmark category Replace restores a valid library with exactly one Default Group.
- Existing compatible version-4 exports without a Default Group remain importable.
- Legacy imported Bookmarks without group memberships are assigned to Default.
- Legacy ordinary groups named `Default` remain ordinary groups.
- Group UUID collisions must not create duplicate system groups.
- Custom imports must not introduce a second Default Group.
- Imported ordinary groups retain the established Update, Merge, Merge into, Copy, and Skip semantics.
- Updating or merging an ordinary group must not implicitly remove Default membership.
- Incoming Default-group members in a custom import should merge into the recipient's Default Group rather than replacing unrelated existing Default memberships.
- System Default must not be treated as an ordinary group eligible for copying into a new folder.
- Normal Copy operations for ordinary groups retain the automatic import-wrapper behavior from IDEA-015.
- The import preflight and projected change summary must reflect the actual resulting memberships and deletions.
- Rollback must restore both system-group and ordinary-group membership state.

Do not add complicated Default Group configuration to the import dialog.

Update export selection presentation so users understand that Default is a real group, while `All` remains a virtual aggregate view.

Coordinate backup schema changes with IDEA-015 to avoid unnecessary incompatible format changes.

### 12. Repository and UI Updates

Review and update all code that assumes `groupId == null` means a valid persistent Ungrouped target.

Relevant areas include:

- `lib/core/bookmarks/src/types/bookmark_target.dart`
- `lib/core/bookmarks/src/types/bookmark_view.dart`
- `lib/core/bookmarks/src/types/bookmark_group.dart`
- `lib/core/bookmarks/src/types/bookmark_library_state.dart`
- `lib/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart`
- `lib/core/bookmarks/src/services/bookmark_library_service.dart`
- `lib/core/bookmarks/src/providers/bookmark_provider.dart`
- `lib/core/bookmarks/src/widgets/bookmark_multi_selection.dart`
- `lib/core/bookmarks/src/widgets/bookmark_context_menu_section.dart`
- `lib/core/bookmarks/src/widgets/bookmark_group_picker.dart`
- `lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart`
- Bookmark Post Viewer actions and mutation handling
- Bookmark import/export sources and codecs
- Localization and settings references

Reuse existing logic where possible.

Do not scatter special-case checks for a display name of `Default` throughout widgets.

---

## Acceptance Criteria

- [x] Every persisted Bookmark belongs to at least one group.
- [x] Exactly one permanent Default Group exists.
- [x] Default cannot be renamed, deleted, or moved.
- [x] Default is visible and usable like a normal Bookmark Group for membership operations.
- [x] Ungrouped is no longer a separate virtual collection.
- [x] Old Ungrouped Bookmarks migrate to Default without data loss.
- [x] New Bookmarks without an explicit group target go to Default.
- [x] Adding a Bookmark to another group never implicitly removes it from Default.
- [x] Add and Remove operate on exactly one selected group.
- [x] Removing the last membership deletes the Bookmark.
- [x] No user-facing global Delete-from-all-groups action remains.
- [x] Single-post and multi-post removal produce identical membership results.
- [x] No routine confirmation appears when removing the last membership.
- [x] A localized Undo Snackbar appears after successful removal.
- [x] Undo reliably restores deleted Bookmarks and removed memberships.
- [x] Bulk Undo is one logical operation.
- [x] Ordinary group and folder deletion retain established orphan-cleanup behavior.
- [x] Import/export preserves the system-group invariant and remains backward compatible.
- [x] No duplicate Default Groups are created by restore or custom import.
- [x] Relevant Bookmark selectors, viewers, and actions use the new semantics.
- [x] Existing unrelated Bookmark functionality remains intact.

## Verification

Add automated tests covering:

- Migration of Ungrouped Bookmarks
- Idempotent migration and restart persistence
- Default Group protection against rename, move, and delete
- Duplicate ordinary names, including `Default`
- New Bookmark creation in Default and explicit target groups
- Adding to multiple groups without implicit membership removal
- Single and bulk Remove from one group
- Last-membership deletion
- Mixed bulk selections where only some selected Bookmarks lose their final membership
- Undo of a normal membership removal
- Undo of a final-membership deletion
- Bulk Undo
- Undo after intervening mutations
- Undo failure and stale group references
- Group and folder deletion with surviving Default membership
- Import/export and Full Replace
- Legacy version-4 import
- Imported Default membership without duplicate system groups
- Mixed-profile Bookmark collections
- UI behavior with no confirmation dialog on ordinary Remove

Use real repository/service-level tests for data integrity and focused widget tests for Undo behavior.

For UI verification, test a single Bookmark, multiple Bookmarks, and a Bookmark that belongs to several groups.

Use `fvm dart format`, focused tests, appropriate analyzer checks, and broader regression tests for the affected Bookmark and import subsystems.

## Relevant Documentation

- `docs/bookmark_groups.md`
- `docs/pinned_searches.md`
- `docs/work/done/IDEA-015-nested-bookmark-search-feed-folders.md` (updated parent-reference design)
- `docs/work/done/BM-005-preserve-group-name-on-import-update.md`
- `AGENTS.md`
- `docs/work/README.md`
- `docs/development_workflow.md`
- `docs/engineering_guidelines.md`

## Implementation Instructions

This work item requires an isolated task branch/worktree.

Check active worktree claims before starting. Coordinate schema and UI changes with the folder work item.

Follow the relevant project-local agent skills in `AGENTS.md`. Do not modify the user's primary checkout.

Record the implementation branch, worktree, progress, tests, migration evidence, and any limitations in this ticket.

Do not integrate into `develop`, push, or open a PR without explicit authorization.

## Definition of Done

Bookmark membership management uses one consistent model: Bookmarks belong to at least one real group, Default is the protected fallback group, Add/Remove always target an individual group, and removing the final membership deletes the Bookmark.

Ordinary removal is fast and reversible through Undo rather than being interrupted by confirmation dialogs.

Existing Bookmark data, hierarchical groups, import/export, and viewer behavior remain correct.
## Implementation record

- Agent: Codex, 2026-10-09.
- Branch: `agent/bm-008-default-group`.
- Worktree: `/home/timber/code/Boorusama/.worktrees/bm-008-default-group`.
- Base: `f4972eb54`; IDEA-015 parent-reference folders are integrated.
- Implemented reserved system UUID `00000000-0000-0000-0000-000000000000`,
  with explicit model role derived from identity. No Hive adapter migration or
  backup version bump is needed: version 5 adds optional `systemRole: default`.
- Library loading repairs stale references, creates Default, and assigns only
  records without memberships. Null settings and legacy viewer/template
  references resolve to Default. Existing explicit memberships stay unchanged.
- Single and bulk removal persist immediately and delete records losing their
  final membership. One localized Snackbar offers serialized snapshot Undo.
  Undo retains newer snapshots and other memberships, rejects stale/deleted
  source groups or superseding removals, and rolls back failed restoration.
- Default is protected in repository and folder APIs and shown as a localized
  normal group. Global bookmark Delete UI is removed. All-view removal opens a
  source-group selector. Viewer lists stay stable until the route closes.
- Full Replace restores one Default; custom Default imports merge only and do
  not create import-wrapper copies. Ordinary group modes and folder orphan
  cleanup remain intact. Legacy version-4 exports remain supported.

### Automated verification

- Real Hive/service tests cover idempotent migration and reopening storage,
  protected identity, ordinary duplicate names, explicit membership, final
  removal, mixed bulk Undo, metadata preservation, intervening mutations,
  failed restoration, missing groups, and surviving Default folder membership.
- Widget checks cover immediate viewer toggles, explicit source selection from
  All, removal without confirmation, one aggregate Undo action, successful and
  failed Undo feedback, 320-pixel width, 1.8 text scaling, and keyboard insets.
- Backup tests cover system-role validation, legacy v4, full Replace, custom
  merge-only Default behavior, rollback, previews, and legacy export templates.
- Changed Dart files formatted with `fvm dart format`. Affected-scope analysis
  reports no errors or warnings; informational lints remain.
- Complete local application suite passed during implementation validation
  (3,024 tests before the final All-view regression). Every package/CLI suite
  passed: booru_clients, boorusama_cli, cache_manager, coreutils, dtext,
  extended_image, filename_generator, flutter_sqlite3_migration, foundation,
  i18n_cli, kurumi, retriable.
- Repository tooling passed: `.github/scripts/test-pull-request-policy.sh`,
  `.github/scripts/test-android-release-scripts.sh`, and
  `python3 -m unittest discover -s scripts/tests` (30 tests).
- Final commit gate repeats the complete application, all package/CLI, and
  tooling suites after the last code and documentation edit. Final application
  log: `/tmp/bm008-final-app.log`; package results:
  `/tmp/bm008-package-results.json`. Commit proceeds only if every suite passes.

### Limitations and delivery

No emulator, physical device, installed-APK upgrade, or live production-data
migration was exercised. Migration/restart evidence comes from real Hive tests;
UI constraints and Undo feedback were exercised with widget tests. Generated
localization outputs were regenerated locally and remain ignored as usual.

The user authorized local integration into `develop` after testing the result.
Integration uses one squash commit and preserves the user's detached primary
checkout. Remote publication and PR creation remain unauthorized and unperformed.

### Follow-up: Home card placement

- User clarified that All and Default must share the top row above the divider;
  ordinary groups and folders belong below it. Default had been included in the
  alphabetical ordinary-group grid. The Home browser now renders the real
  Default group beside All and excludes it from that lower grid by identity.
- Regression reproduces the old placement before the fix and verifies the two
  top cards, divider, ordinary groups named Default below the divider, and
  disabled shortcuts during bulk selection. Layout is exercised at narrow
  width and enlarged text. The complete local suites are repeated after the
  final edit before committing this follow-up. Device checks remain unperformed.

### Follow-up: simple Default UUID

- User requested the valid nil UUID `00000000-0000-0000-0000-000000000000`
  as Default's permanent identity. The pinned UUID validator accepts it.
- The previous Default identity never went live. Per user instruction, there is
  no migration or compatibility alias for that development-only UUID. Existing
  Ungrouped-to-Default migration remains unchanged.
- Existing real repository, service, backup codec, and import tests use the
  shared Default identity and verify nil through those paths. The complete
  local suites are repeated after the final edit before committing.

### Merge validation: cache test synchronization

Full application runs exposed existing timing failures in
`progressive_common_cache_test.dart` and `progressive_non_admitted_cache_test.dart`:
fixed delays could expire before request setup or image decoding, and asynchronous
cache bookkeeping could recreate files during fixture cleanup. At the user's
request, these fixtures now wait for requests, decode counts, and painted pixels,
with bounded timeouts, and drain their tracked cache reads, writes, and usage
updates before deleting temporary directories. Pixel, fetch-count, decoded-stream
identity, and listener-release assertions remain in place. Production image and
cache behavior is unchanged.
