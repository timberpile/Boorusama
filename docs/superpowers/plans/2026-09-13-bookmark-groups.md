# Bookmark Groups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reintroduce the complete bookmark-group experience with GUID-based sharing and drop-in import compatibility for old bookmark-group backups.

**Architecture:** Keep existing bookmark records in the `favorites` Hive box and store each GUID-identified group with its bookmark keys in one new Hive box. Publish bookmarks, groups, and membership indexes through one manually declared AsyncNotifier, while focused services own mutations and import planning. Preserve the old UI behavior and JSON shape, adding only an optional group `id` for shared merge/replace semantics.

**Tech Stack:** Flutter, Dart, Riverpod Notifier/AsyncNotifier, Hive CE, Equatable, Kurumi, slang i18n, flutter_test

**Spec:** `docs/superpowers/specs/2026-09-13-bookmark-groups-design.md`

## Global Constraints

- Existing bookmark objects remain unchanged in the top-level backup `data` array.
- The top-level `groups` array retains `name` and `bookmarkIds`; `id` is optional for legacy input and emitted for new exports.
- A missing group ID creates a new GUID group; a malformed or repeated supplied GUID invalidates the import.
- Duplicate group display names are valid; GUID is the only identity.
- Use manually declared Notifier/AsyncNotifier providers without Riverpod code generation.
- Put business rules in state classes or dedicated services, never UI widgets.
- Add every user-facing string to i18n and access it through `context.t`.
- Use `fvm` for every Flutter and Dart command.
- Implement production behavior only after its focused test has failed for the expected reason.

---

### Task 1: Group values and Hive persistence

**Files:**
- Create: `lib/core/bookmarks/src/types/bookmark_group.dart`
- Create: `lib/core/bookmarks/src/types/bookmark_target.dart`
- Create: `lib/core/bookmarks/src/types/bookmark_group_repository.dart`
- Create: `lib/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart`
- Create: `lib/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart`
- Modify: `lib/core/bookmarks/src/data/providers.dart`
- Modify: `lib/core/bookmarks/types.dart`
- Modify: `lib/core/hive/hive_adapters.dart`
- Modify: `lib/core/hive/hive_adapters.g.yaml`
- Regenerate: `lib/core/hive/hive_adapters.g.dart`
- Regenerate: `lib/core/hive/hive_registrar.g.dart`
- Test: `test/core/bookmarks/bookmark_group_repository_test.dart`

**Interfaces:**
- Produces: `BookmarkGroup(id, name, bookmarkIds)`, `BookmarkTarget`, `BookmarkGroupRepository`, and `bookmarkGroupRepoProvider`.
- `BookmarkGroupRepository` exposes `getGroups`, `createGroup`, `duplicateGroup`, `renameGroup`, `previewDeleteGroup`, `deleteGroup`, `replaceMemberships`, `addBookmarks`, `removeBookmarks`, `removeBookmarkFromAllGroups`, and `repair`.

- [ ] **Step 1: Write failing repository tests**

Cover generated canonical UUIDs, accepted explicit UUIDs, duplicate names, trimmed non-empty names, membership deduplication, duplicate-group membership copying, rename identity preservation, deletion previews, and stale bookmark-key repair. Use real temporary Hive boxes and one test per parameterized case.

- [ ] **Step 2: Verify the repository tests fail**

Run: `fvm flutter test test/core/bookmarks/bookmark_group_repository_test.dart`

Expected: compilation fails because the group types and repository do not exist.

- [ ] **Step 3: Implement the group domain and repository**

Use `String` canonical UUIDs, immutable `Set<int>` membership values, Equatable value equality, and a `BookmarkGroupHiveObject` with `id`, `name`, and `List<int> bookmarkIds`. Normalize on every read/write and validate supplied IDs with `Uuid.isValidUUID` before mutation.

- [ ] **Step 4: Generate adapters and format**

Run: `./gen.sh`

Run: `fvm dart format lib/core/bookmarks/src/types lib/core/bookmarks/src/data lib/core/bookmarks/types.dart lib/core/hive test/core/bookmarks/bookmark_group_repository_test.dart`

- [ ] **Step 5: Verify the repository tests pass**

Run: `fvm flutter test test/core/bookmarks/bookmark_group_repository_test.dart`

- [ ] **Step 6: Commit**

Run: `git add lib/core/bookmarks lib/core/hive test/core/bookmarks/bookmark_group_repository_test.dart`

Run: `git commit -m "feat(bookmarks): add group persistence"`

### Task 2: Library snapshot, selectors, and mutation service

**Files:**
- Create: `lib/core/bookmarks/src/types/bookmark_library_state.dart`
- Create: `lib/core/bookmarks/src/services/bookmark_library_service.dart`
- Create: `lib/core/bookmarks/src/providers/bookmark_library_provider.dart`
- Create: `lib/core/bookmarks/src/providers/bookmark_group_selectors.dart`
- Modify: `lib/core/bookmarks/src/providers/bookmark_provider.dart`
- Modify: `lib/core/bookmarks/providers.dart`
- Test: `test/core/bookmarks/bookmark_library_state_test.dart`
- Test: `test/core/bookmarks/bookmark_library_service_test.dart`

**Interfaces:**
- Produces: `BookmarkLibraryState`, pure filter/preview/button/bulk selectors, `BookmarkLibraryService`, and `bookmarkLibraryProvider` as `AsyncNotifierProvider<BookmarkLibraryNotifier, BookmarkLibraryState>`.
- Preserves existing `bookmarkProvider` consumers through a thin compatibility projection while call sites migrate.

- [ ] **Step 1: Write failing selector tests**

Cover `All`, `No Group`, named GUID filtering, current sort modes, first-four previews, active-target membership, total named membership counts, and mixed bulk aggregate counts.

- [ ] **Step 2: Verify selector tests fail**

Run: `fvm flutter test test/core/bookmarks/bookmark_library_state_test.dart`

- [ ] **Step 3: Implement immutable state and pure selectors**

Build membership indexes once per snapshot. Keep `BookmarkTarget.ungrouped` separate from `BookmarkView.all`, and fall back to ungrouped when the persisted GUID is absent.

- [ ] **Step 4: Write failing mutation-service tests**

Cover creating missing bookmarks before membership, adding existing bookmarks without duplication, single-post final-membership deletion, bulk final-membership preservation, complete deletion and cache cleanup, group deletion orphan rules, serialized concurrent mutations, rollback, and post-failure repair. Stub only repositories, settings persistence, UUID generation, and the external image cache.

- [ ] **Step 5: Verify mutation-service tests fail**

Run: `fvm flutter test test/core/bookmarks/bookmark_library_service_test.dart`

- [ ] **Step 6: Implement the service and AsyncNotifier**

The service returns typed result values with counts. The notifier queues mutations, awaits the service, reloads one snapshot, and never converts repository failures into silent success callbacks.

- [ ] **Step 7: Format and verify focused tests**

Run: `fvm dart format lib/core/bookmarks test/core/bookmarks`

Run: `fvm flutter test test/core/bookmarks/bookmark_library_state_test.dart test/core/bookmarks/bookmark_library_service_test.dart`

- [ ] **Step 8: Commit**

Run: `git add lib/core/bookmarks test/core/bookmarks`

Run: `git commit -m "feat(bookmarks): add group-aware library state"`

### Task 3: Persisted active target and group management actions

**Files:**
- Modify: `lib/core/settings/src/types/settings.dart`
- Modify: `lib/core/bookmarks/src/providers/bookmark_library_provider.dart`
- Create: `lib/core/bookmarks/src/widgets/bookmark_group_name_dialog.dart`
- Create: `lib/core/bookmarks/src/widgets/bookmark_group_actions.dart`
- Modify: `packages/i18n/translations/en-US.json`
- Regenerate: `packages/i18n/lib/src/gen/strings.g.dart`
- Regenerate: `packages/i18n/lib/src/gen/languages.g.dart`
- Test: `test/core/bookmarks/bookmark_active_target_test.dart`
- Test: `test/core/bookmarks/bookmark_group_actions_test.dart`

**Interfaces:**
- Consumes: group repository and library notifier from Tasks 1-2.
- Produces: persisted `String? activeBookmarkGroupId`, create/duplicate/rename/delete actions, and localized dialogs.

- [ ] **Step 1: Write failing active-target and action tests**

Cover default ungrouped, persistence, missing-GUID fallback, `All` leaving the target unchanged, browser creation leaving it unchanged, assignment creation activating it, empty deletion without confirmation, non-empty confirmation counts, and orphan deletion.

- [ ] **Step 2: Verify tests fail**

Run: `fvm flutter test test/core/bookmarks/bookmark_active_target_test.dart test/core/bookmarks/bookmark_group_actions_test.dart`

- [ ] **Step 3: Implement settings and group actions**

Keep constructors/factories at class tops. Dialogs return values only; the notifier/service performs all mutations. Never render raw exceptions as user copy.

- [ ] **Step 4: Add localized strings, generate, format, and test**

Run: `./gen.sh`

Run: `fvm dart format lib/core/settings/src/types/settings.dart lib/core/bookmarks test/core/bookmarks`

Run: `fvm flutter test test/core/bookmarks/bookmark_active_target_test.dart test/core/bookmarks/bookmark_group_actions_test.dart`

- [ ] **Step 5: Commit**

Run: `git add lib/core/settings lib/core/bookmarks packages/i18n test/core/bookmarks`

Run: `git commit -m "feat(bookmarks): add group management"`

### Task 4: Legacy-compatible backup codec and export scopes

**Files:**
- Create: `lib/core/backups/sources/bookmark_backup_data.dart`
- Create: `lib/core/backups/sources/bookmark_backup_codec.dart`
- Modify: `lib/core/backups/types/types.dart`
- Modify: `lib/core/backups/utils/data_converter.dart`
- Modify: `lib/core/backups/sources/json_source.dart`
- Modify: `lib/core/backups/types/backup_data_source.dart`
- Test: `test/core/backups/bookmark_backup_codec_test.dart`
- Test: `test/core/backups/bookmark_export_scope_test.dart`
- Test fixture: `test/core/backups/fixtures/legacy_bookmark_groups.json`

**Interfaces:**
- Produces: optional `ExportDataPayload.extraFields`, `BookmarkBackupData`, `BookmarkGroupBackup`, `BookmarkExportScope`, and `BookmarkBackupCodec`.
- The fixture preserves the exact old shape: top-level `groups`, group `name`, and group `bookmarkIds`, with no group `id`.

- [ ] **Step 1: Add a legacy JSON fixture and failing golden tests**

Assert that old group files parse without conversion, top-level extra fields survive decoding, bookmarks map unchanged, missing IDs remain explicitly legacy, valid IDs canonicalize, malformed IDs fail, repeated supplied IDs fail, bad nullable field types fail, missing bookmark references remain parseable, and encode emits IDs for new groups.

- [ ] **Step 2: Verify codec tests fail**

Run: `fvm flutter test test/core/backups/bookmark_backup_codec_test.dart`

- [ ] **Step 3: Extend the generic envelope and implement the codec**

Preserve unknown top-level fields in `extraFields`. Keep the standard `data` handler contract and allow bookmark sources to encode `groups` beside it. Include debug-only field paths in invalid-format exceptions.

- [ ] **Step 4: Write failing export-scope tests**

Cover all bookmarks, overlapping selected groups, omitted unselected memberships, ungrouped selection, empty selected groups, and each bookmark appearing once.

- [ ] **Step 5: Implement scope selection data logic and verify**

Run: `fvm dart format lib/core/backups test/core/backups`

Run: `fvm flutter test test/core/backups/bookmark_backup_codec_test.dart test/core/backups/bookmark_export_scope_test.dart`

- [ ] **Step 6: Commit**

Run: `git add lib/core/backups test/core/backups`

Run: `git commit -m "feat(backups): preserve bookmark groups"`

### Task 5: Import planning, conflict decisions, and application

**Files:**
- Create: `lib/core/backups/sources/bookmark_import_plan.dart`
- Create: `lib/core/backups/sources/bookmark_import_planner.dart`
- Create: `lib/core/backups/sources/bookmark_import_service.dart`
- Create: `lib/core/backups/widgets/bookmark_group_conflict_dialog.dart`
- Test: `test/core/backups/bookmark_import_planner_test.dart`
- Test: `test/core/backups/bookmark_import_service_test.dart`
- Test: `test/core/backups/bookmark_group_conflict_dialog_test.dart`

**Interfaces:**
- Produces: immutable plan/conflict values, `BookmarkGroupConflictChoice.merge`, `.replace`, `.cancel`, and an apply-to-remaining flag.
- The planner maps exported bookmark IDs through imported `Bookmark.uniqueId`; the service consumes only a fully resolved plan.

- [ ] **Step 1: Write failing planner tests**

Cover fresh GUID groups, fresh generated IDs for every legacy import, GUID-only conflict detection, duplicate names remaining independent, ignored missing references, existing bookmark reuse, new bookmark planning, and cancellation producing no executable plan.

- [ ] **Step 2: Verify planner tests fail**

Run: `fvm flutter test test/core/backups/bookmark_import_planner_test.dart`

- [ ] **Step 3: Implement planning and conflict resolution models**

Collect all choices before applying writes. Apply-to-remaining affects only later conflicts and carries the selected Merge or Replace action.

- [ ] **Step 4: Write failing service and dialog tests**

Cover additive Merge with imported-name precedence, exact Replace with bookmark preservation, idempotent re-import, existing/missing bookmark counts, rollback after a write failure, one dialog per conflict, apply-to-remaining skipping later dialogs, and Cancel abandoning all writes.

- [ ] **Step 5: Implement the import service and dialog**

Keep UI conflict collection separate from data mutation. Return localized-safe operation results rather than raw exception text.

- [ ] **Step 6: Format and verify focused tests**

Run: `fvm dart format lib/core/backups test/core/backups`

Run: `fvm flutter test test/core/backups/bookmark_import_planner_test.dart test/core/backups/bookmark_import_service_test.dart test/core/backups/bookmark_group_conflict_dialog_test.dart`

- [ ] **Step 7: Commit**

Run: `git add lib/core/backups test/core/backups`

Run: `git commit -m "feat(backups): resolve shared bookmark groups"`

### Task 6: Backup source integration and direct-operation feedback

**Files:**
- Modify: `lib/core/backups/sources/bookmarks_source.dart`
- Create: `lib/core/backups/widgets/bookmark_export_scope_dialog.dart`
- Create: `lib/core/backups/sources/bookmark_backup_messages.dart`
- Modify: `lib/core/backups/widgets/backup_restore_tile.dart`
- Modify: `lib/core/backups/transfer/import/transfer_data_dialog.dart`
- Modify: `packages/i18n/translations/en-US.json`
- Test: `test/core/backups/bookmark_export_scope_dialog_test.dart`
- Test: `test/core/backups/bookmark_backup_messages_test.dart`

**Interfaces:**
- Consumes: codec, planner, importer, and library state.
- Produces: selected-scope direct file/clipboard export, unfiltered ZIP export, conflict-aware direct/ZIP import, and bookmark-specific count messages.

- [ ] **Step 1: Write failing dialog and message tests**

Cover default All selection, cancellation, named and ungrouped selection, export counts including zero, import totals, already-existing suffixes, and unchanged generic messages for other sources and ZIP summaries.

- [ ] **Step 2: Verify tests fail**

Run: `fvm flutter test test/core/backups/bookmark_export_scope_dialog_test.dart test/core/backups/bookmark_backup_messages_test.dart`

- [ ] **Step 3: Integrate backup options/results and bookmark source**

Direct export invokes scope selection before the destination picker or clipboard write. Import never shows scope selection. Bulk ZIP operations pass no scope and always use the entire library.

- [ ] **Step 4: Localize, generate, format, and verify**

Run: `./gen.sh`

Run: `fvm dart format lib/core/backups test/core/backups`

Run: `fvm flutter test test/core/backups`

- [ ] **Step 5: Commit**

Run: `git add lib/core/backups packages/i18n test/core/backups`

Run: `git commit -m "feat(backups): add bookmark export scopes"`

### Task 7: Group browser and filtered bookmark routes

**Files:**
- Create: `lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart`
- Modify: `lib/core/bookmarks/src/pages/bookmark_page.dart`
- Modify: `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart`
- Modify: `lib/core/bookmarks/src/widgets/bookmark_appbar.dart`
- Modify: `lib/core/bookmarks/src/routes/routes.dart`
- Modify: `lib/core/bookmarks/src/routes/route_utils.dart`
- Test: `test/core/bookmarks/bookmark_group_browser_test.dart`

**Interfaces:**
- Consumes: library snapshot/selectors and group actions.
- Produces: `/bookmarks` browser and `/bookmarks/group` content route keyed by `BookmarkView`/GUID.

- [ ] **Step 1: Write failing browser and route tests**

Cover opening the browser first, `All`/`No Group`/named cards, responsive columns, transparent empty previews, sorted first-four images, browser creation staying put, target activation rules, filtered content, and selected group title.

- [ ] **Step 2: Verify tests fail**

Run: `fvm flutter test test/core/bookmarks/bookmark_group_browser_test.dart`

- [ ] **Step 3: Implement browser, routes, and snapshot-backed listing**

Reuse the existing bookmark image configuration and grid components. Remove repository reads from the scroll-view fetcher; filter the shared snapshot instead.

- [ ] **Step 4: Format and verify**

Run: `fvm dart format lib/core/bookmarks test/core/bookmarks/bookmark_group_browser_test.dart`

Run: `fvm flutter test test/core/bookmarks/bookmark_group_browser_test.dart`

- [ ] **Step 5: Commit**

Run: `git add lib/core/bookmarks test/core/bookmarks/bookmark_group_browser_test.dart`

Run: `git commit -m "feat(bookmarks): add group browser"`

### Task 8: Single-post controls and anchored group pickers

**Files:**
- Create: `lib/core/bookmarks/src/widgets/bookmark_group_picker.dart`
- Create: `lib/core/bookmarks/src/widgets/bookmark_active_target_badge.dart`
- Modify: `lib/core/posts/details_parts/src/toolbars/bookmark_post_button.dart`
- Modify: `lib/core/posts/listing/src/widgets/general_post_context_menu.dart`
- Modify: `lib/boorus/danbooru/posts/post/src/context_menu.dart`
- Modify: `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart`
- Modify: `packages/kurumi/lib/src/components/context_menu.dart`
- Modify: `packages/kurumi/lib/src/components/popup_menu.dart`
- Test: `test/core/bookmarks/bookmark_group_picker_test.dart`
- Test: `test/core/bookmarks/bookmark_button_state_test.dart`

**Interfaces:**
- Consumes: active target, membership selectors, group actions, and library notifier.
- Produces: tap toggle, long-press anchored picker, membership badge/count, nested thumbnail-context picker, Back row, and create-while-assigning.

- [ ] **Step 1: Write failing button and picker tests**

Cover every empty/filled/count combination, compact versus labeled layout, full composite hit target, active badge styling, allowed `No Group` cases, membership toggles, single-post final-membership deletion, picker closure, Back restoring the parent menu, and stable navigation context for create.

- [ ] **Step 2: Verify tests fail**

Run: `fvm flutter test test/core/bookmarks/bookmark_group_picker_test.dart test/core/bookmarks/bookmark_button_state_test.dart`

- [ ] **Step 3: Implement reusable picker and integrate all post surfaces**

Keep popup presentation in Kurumi and bookmark behavior in bookmark widgets/services. The context menu exposes no separate complete-delete action.

- [ ] **Step 4: Localize, generate, format, and verify**

Run: `./gen.sh`

Run: `fvm dart format lib/core/bookmarks lib/core/posts lib/boorus/danbooru/posts packages/kurumi/lib test/core/bookmarks`

Run: `fvm flutter test test/core/bookmarks/bookmark_group_picker_test.dart test/core/bookmarks/bookmark_button_state_test.dart`

- [ ] **Step 5: Commit**

Run: `git add lib/core/bookmarks lib/core/posts lib/boorus/danbooru/posts packages/kurumi packages/i18n test/core/bookmarks`

Run: `git commit -m "feat(bookmarks): add group-aware post actions"`

### Task 9: Bulk bookmark management

**Files:**
- Create: `lib/core/bookmarks/src/widgets/bookmark_multi_selection.dart`
- Modify: `lib/core/posts/listing/src/widgets/default_multi_selection_actions.dart`
- Modify: `lib/core/widgets/multi_select_button.dart`
- Modify: `lib/core/widgets/multi_selection_action_bar.dart`
- Modify: `lib/core/posts/listing/src/widgets/post_grid.dart`
- Modify: `lib/core/posts/listing/src/widgets/post_grid_controller.dart`
- Modify: `lib/core/posts/listing/src/_internal/raw_post_grid.dart`
- Modify: `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart`
- Test: `test/core/bookmarks/bookmark_multi_selection_test.dart`

**Interfaces:**
- Produces: `Bookmarks` action with exactly Add to group, Remove from group, and Delete; aggregate group rows; preserved selection after add/remove; and explicit removal outcomes.

- [ ] **Step 1: Write failing bulk workflow tests**

Cover exact menu actions, mixed aggregate counts, additive named/ungrouped behavior, removal limited to actual memberships, moved-to-No-Group count, confirmed complete deletion, cancellation, selection preservation, and removal of items that leave the current filtered view.

- [ ] **Step 2: Verify tests fail**

Run: `fvm flutter test test/core/bookmarks/bookmark_multi_selection_test.dart`

- [ ] **Step 3: Implement the bulk workflow and minimal selection API hooks**

Do not place bookmark rules in generic post-grid classes. Add only the callbacks/control needed to keep visible selected items selected across consecutive operations.

- [ ] **Step 4: Localize, generate, format, and verify**

Run: `./gen.sh`

Run: `fvm dart format lib/core/bookmarks lib/core/posts/listing lib/core/widgets test/core/bookmarks/bookmark_multi_selection_test.dart`

Run: `fvm flutter test test/core/bookmarks/bookmark_multi_selection_test.dart`

- [ ] **Step 5: Commit**

Run: `git add lib/core/bookmarks lib/core/posts/listing lib/core/widgets packages/i18n test/core/bookmarks/bookmark_multi_selection_test.dart`

Run: `git commit -m "feat(bookmarks): add bulk group management"`

### Task 10: Integration verification and project knowledge

**Files:**
- Create: `docs/bookmark_groups.md`
- Modify: `docs/development_workflow.md`
- Modify: any feature files required by integration findings

**Interfaces:**
- Documents: data invariants, GUID import semantics, backup compatibility contract, and the new-worktree CLI bootstrap requirement.

- [ ] **Step 1: Document non-obvious architecture and tooling knowledge**

Record that bookmark IDs in backups are file-local, GUIDs alone identify shared groups, legacy groups always receive new GUIDs, Merge/Replace names come from the import, and a fresh worktree needs `fvm dart pub get` in `packages/boorusama_cli` before `./gen.sh`.

- [ ] **Step 2: Regenerate and format all changed Dart files**

Run: `./gen.sh`

Run: `fvm dart format lib packages test`

- [ ] **Step 3: Run static analysis**

Run: `fvm flutter analyze`

Expected: no new warnings or errors.

- [ ] **Step 4: Run focused feature tests**

Run: `fvm flutter test test/core/bookmarks test/core/backups`

Expected: all bookmark/group and backup tests pass.

- [ ] **Step 5: Run the complete suite**

Run: `fvm flutter test`

Expected: all tests pass from the established 715-test baseline plus the new tests.

- [ ] **Step 6: Inspect the final diff and generated files**

Run: `git diff --check`

Run: `git status --short`

Run: `git diff --stat develop...HEAD`

Confirm no generated output, localization resource, adapter registration, or user-facing string is missing.

- [ ] **Step 7: Commit final integration adjustments**

Run: `git add docs lib packages test`

Run: `git commit -m "docs(bookmarks): document group invariants"`

- [ ] **Step 8: Push and open the pull request**

Run: `git push -u origin feature/13-bookmark-groups`

Run: `gh pr create --repo timberpile/Boorusama --base develop --head feature/13-bookmark-groups --title "Merge branch 'feature/13-bookmark-groups'" --body $'- Add GUID-based local bookmark groups across browsing, post actions, and bulk management.\n- Preserve legacy bookmark-group imports and add explicit Merge or Replace handling for shared groups and scoped exports.\n- Add focused persistence, state, import, and widget coverage.\n\nCloses #13'`

Do not enable auto-merge and do not merge without explicit user approval.
