# Shared Pinned-Search Folders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show one pinned-search collection with shared folders and Home, while every search keeps its owning profile for navigation and refresh.

**Architecture:** Persist one global organization value containing ordered folder IDs and ordered pin IDs for each folder and Home. Keep query, profile, preview, and refresh state in `SearchSubscription`. Adapt notifier, backup, and UI consumers to the global organization contract; resolve every search action by its pin's profile ID.

**Tech Stack:** Flutter, Dart, Riverpod `AsyncNotifier` and manual providers, Hive CE, Equatable, existing backup pipeline, i18n generator, Flutter tests, Android Maestro.

**Spec:** `docs/superpowers/specs/2026-09-19-shared-pinned-search-folders-design.md`

## Global Constraints

- Named folders can contain independent pins from different profiles; folders stay single-level.
- Home is the no-folder destination, displayed as `[Home]` in pickers, with no Home heading above root cards.
- Every card shows its owning profile; opening and refreshing use that owner.
- Deleting a folder unpins every member only after a confirmation warning; cancel changes nothing.
- The current profile-folder format and old experimental folder backups need no migration.
- Hidden following-feed sources never enter Home, folders, ordering, or folder badges.
- Before restoring a backup with unmatched profile references, obtain confirmation before any selected ZIP or server-transfer source imports. Match against backup profiles when that source is selected, or current profiles otherwise. Cancel aborts the entire restore; headless import with unmatched references aborts.
- Keep user-facing copy in `packages/i18n/translations/en-US.json` and use `context.t`; run `./gen.sh` after changing translations.
- Use manually declared Riverpod providers, `Equatable` where value equality matters, and `fvm` for all Flutter/Dart commands.
- Claim `docs/work/ready/PS-018-rework-pinned-search-folder-navigation.md` before implementation and follow `docs/development_workflow.md` for branch and delivery steps.

## Review Focus

1. Two profiles have the same display name: the card footnote includes a URL so the owner is unambiguous (Task 6 widget test).
2. The organization value contains a deleted pin or the same pin twice: loading repairs stale IDs and rejects duplicate membership writes (Task 1 repository tests).
3. A folder deletion write fails after some pin writes: the folder and all member pins are restored or an explicit recoverable error is surfaced (Task 2 failure test).
4. Profiles change while an unmatched-profile restore warning is open: revalidation aborts before importing newly unmatched records (Task 5 source test).
5. A multi-source ZIP or server transfer contains an unmatched pin profile: cancel or headless preflight leaves profiles and every other selected source untouched (Task 5 orchestration tests).

---

## File Structure

- `lib/core/search/subscriptions/src/types/search_organization.dart` (new): global `SharedSearchFolder` and immutable ordered folders/Home IDs with JSON conversion. Keep the old `SearchFolder` type temporarily so intermediate tasks compile, then remove it in Task 7.
- `lib/core/search/subscriptions/src/types/search_subscription_repository.dart` and `src/data/hive/search_subscription_repository_hive.dart`: shared organization persistence and serialized destructive operations.
- `lib/core/search/subscriptions/src/providers/search_subscriptions_notifier.dart` and `search_subscription_selectors.dart`: global commands, global list selection, owner-routed refresh.
- `lib/core/search/subscriptions/src/pages/pinned_searches_page.dart`: root and folder presentation without profile groups.
- `lib/core/search/subscriptions/src/pages/search_folder_management_page.dart` (new): folder creation, rename, ordering, and destructive confirmation.
- `lib/core/search/subscriptions/src/widgets/pinned_search_card.dart`, `pin_search_folder_picker.dart`, and `move_pin_to_folder_dialog.dart` (new): owner footnote and global destination selection.
- `lib/core/backups/sources/pinned_search_backup_data.dart`, `pinned_search_backup_codec.dart`, `pinned_search_import_service.dart`, and `pinned_searches_source.dart`: global backup format, mapping, and typed preflight approval.
- `lib/core/backups/preparation/version_checking.dart`, `lib/core/backups/sources/json_source.dart`, `lib/core/backups/sources/pinned_search_import_preflight.dart` (new), `lib/core/backups/zip/bulk_backup_service.dart`, and `lib/core/backups/transfer/import/import_data_notifier.dart`: expose prepared JSON data, prepare selected sources before executing them, and pass pin approval into execution.
- `lib/core/backups/widgets/pinned_search_missing_profiles_dialog.dart` (new): localized accept/cancel warning.
- `lib/core/configs/manage/src/providers/booru_config_provider.dart` and `lib/core/backups/sources/booru_configs_source.dart`: compensate profile deletion/import using shared organization snapshots.
- `packages/i18n/translations/en-US.json` and generated i18n files: `[Home]`, Manage folders, owner and deletion copy, and restore warning.
- `docs/pinned_searches.md` and `docs/work/PS-018` at its current queue location: update architectural behavior and record verification.

Do not expand the existing page with repository mutation logic. Keep storage invariants in the repository and use the notifier for commands. Keep the backup profile preflight outside the import mutation and before multi-source execution, so cancel cannot leave a partial restore. Add shared APIs alongside the old profile-folder APIs through Task 6; delete the latter only in Task 7 after every caller has moved.

---

### Task 1: Global organization value and validated persistence

**Files:**
- Create: `lib/core/search/subscriptions/src/types/search_organization.dart`
- Modify: `lib/core/search/subscriptions/types.dart`
- Modify: `lib/core/search/subscriptions/src/types/search_subscription_repository.dart`
- Modify: `lib/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart`
- Test: `test/core/search/subscriptions/search_subscription_repository_test.dart`

**Interfaces:**
- Consumes: independent `SearchSubscription` records, `feedId == null`, organization Hive box.
- Produces: `SearchOrganization({folders, homeSearchIds})`, `SharedSearchFolder({id, name, searchIds})`, `getOrganization()`, and `replaceOrganization(SearchOrganization)`. Legacy folder APIs remain available until Task 7.

- [ ] **Step 1: Add a failing repository test for global membership and order.** Seed two independent pins with different profile IDs and one feed-owned source. Replace the organization with the two independent pins in one folder, reload the repository, and assert their order and profiles are unchanged. Assert that assigning the feed source or assigning the same pin to Home and a folder throws without changing the stored organization. Seed a stale stored pin ID and assert loading drops it while appending an unlisted independent pin to Home deterministically.

```dart
final folder = SharedSearchFolder(id: 'animals', name: 'Animals', searchIds: [cat.id, dog.id]);
await repository.replaceOrganization(SearchOrganization(
  folders: [folder],
  homeSearchIds: const [],
));
expect((await repository.getOrganization()).folders.single.searchIds, [cat.id, dog.id]);
expect((await repository.getAll()).where((s) => s.feedId == null).map((s) => s.profileId), [12, 99]);
```

- [ ] **Step 2: Run the focused test and confirm it fails.** Run `fvm flutter test test/core/search/subscriptions/search_subscription_repository_test.dart`; expect the missing organization types or methods to fail compilation.
- [ ] **Step 3: Add immutable organization types and repository signatures.** `SharedSearchFolder.searchIds` and `SearchOrganization.homeSearchIds` are ordered unmodifiable lists. JSON decoding validates nullable external values explicitly. Keep folder names trimmed and reject empty names. Add these declarations to the existing repository interface; retain its older methods until Task 7.

```dart
final class SharedSearchFolder extends Equatable {
  SharedSearchFolder({required this.id, required String name, required Iterable<String> searchIds})
      : name = name.trim(), searchIds = List.unmodifiable(searchIds);
  final String id;
  final String name;
  final List<String> searchIds;
  @override
  List<Object?> get props => [id, name, searchIds];
}

final class SearchOrganization extends Equatable {
  SearchOrganization({required Iterable<SharedSearchFolder> folders, required Iterable<String> homeSearchIds})
      : folders = List.unmodifiable(folders), homeSearchIds = List.unmodifiable(homeSearchIds);
  final List<SharedSearchFolder> folders;
  final List<String> homeSearchIds;
  @override
  List<Object?> get props => [folders, homeSearchIds];
}

Future<SearchOrganization> getOrganization();
Future<void> replaceOrganization(SearchOrganization organization);
```

- [ ] **Step 4: Persist one global organization value.** Use one non-integer key in the existing organization box so feed keys remain untouched. Validate unique folder IDs, case-insensitive names, and one membership per independent pin before writing. Implement a synchronous private `_organization()` reader for use inside `_serialize`, and expose `getOrganization()` through `_read(_organization)`. On read, discard IDs whose pin no longer exists and append any unlisted independent pins to Home in `(createdAt, id)` order. Ignore old integer-key folder rows.

```dart
final stored = switch (_organizationBox?.get('search:organization')) {
  final Map json => SearchOrganization.fromJson(json),
  _ => SearchOrganization(folders: const [], homeSearchIds: const []),
};
await _organizationBox?.put('search:organization', organization.toJson());
```
- [ ] **Step 5: Format and rerun the repository test.** Run `fvm dart format` on the changed Dart files, then `fvm flutter test test/core/search/subscriptions/search_subscription_repository_test.dart`; expect PASS.
- [ ] **Step 6: Commit this independently testable persistence change.** Stage only Task 1 files and commit `feat(search): store shared pin organization`.

### Task 2: Safe deletion and profile cleanup

**Files:**
- Modify: `lib/core/search/subscriptions/src/types/search_subscription_repository.dart`
- Modify: `lib/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart`
- Modify: `lib/core/configs/manage/src/providers/booru_config_provider.dart`
- Modify: `lib/core/backups/sources/booru_configs_source.dart`
- Test: `test/core/search/subscriptions/search_subscription_repository_test.dart`
- Test: `test/booru_config_notifier_test.dart`

**Interfaces:**
- Consumes: `getOrganization()` and `replaceOrganization()` from Task 1.
- Produces: `deleteSharedFolderAndPins(String folderId)`, profile removal that prunes only owned pin IDs, and compensation that restores the organization snapshot.

- [ ] **Step 1: Write failing deletion and profile tests.** Put pins from profiles 12 and 99 in one folder. Delete profile 12 and assert profile 99's pin and folder remain. Delete that folder and assert its remaining pin is deleted, while an unrelated Home pin remains. Inject a storage write failure and assert no silent partial deletion.

```dart
await repository.deleteForProfile(12);
expect((await repository.getOrganization()).folders.single.searchIds, [dog.id]);
await repository.deleteSharedFolderAndPins('animals');
expect((await repository.getAll()).where((s) => s.id == dog.id), isEmpty);
```

- [ ] **Step 2: Run those focused tests and confirm the old owner-based logic fails.** Run `fvm flutter test test/core/search/subscriptions/search_subscription_repository_test.dart test/booru_config_notifier_test.dart`.
- [ ] **Step 3: Implement serialized destructive operations.** `deleteSharedFolderAndPins` snapshots the folder and member pin objects, removes the member pins and folder, and restores both on an ordinary write error. Single-pin `delete` and `deleteForProfile` remove only affected IDs from Home and folders; keep empty folders. The config and backup profile-compensation paths snapshot/restore the whole shared organization instead of filtering folders by `profileId`.

```dart
final previousOrganization = _organization();
final memberIds = previousOrganization.folders
    .singleWhere((folder) => folder.id == folderId)
    .searchIds;
final previousPins = {
  for (final id in memberIds)
    if (_box.get(id) case final pin?) id: pin,
};
try {
  await _box.deleteAll(memberIds);
  final next = SearchOrganization(
    folders: previousOrganization.folders.where((f) => f.id != folderId),
    homeSearchIds: previousOrganization.homeSearchIds,
  );
  await _organizationBox!.put('search:organization', next.toJson());
} catch (_) {
  await _box.putAll(previousPins);
  await _organizationBox!.put('search:organization', previousOrganization.toJson());
  rethrow;
}
```
- [ ] **Step 4: Format, run the focused tests, and commit.** Run `fvm dart format` on changed Dart files, rerun both test files, then commit only Task 2 files as `feat(search): clean shared folders on deletion`.

### Task 3: Global notifier commands, selectors, and refresh

**Files:**
- Modify: `lib/core/search/subscriptions/src/providers/search_subscriptions_notifier.dart`
- Modify: `lib/core/search/subscriptions/src/providers/search_subscription_selectors.dart`
- Test: `test/core/search/subscriptions/search_folder_test.dart`
- Test: `test/core/search/subscriptions/following_feed_test.dart`
- Test: `test/core/search/subscriptions/search_subscriptions_notifier_test.dart`

**Interfaces:**
- Consumes: Task 1 organization APIs and Task 2 `deleteSharedFolderAndPins`.
- Produces: `organizedPinnedSearchesProvider(String? folderId)`, `Future<SharedSearchFolder> createSharedFolder(String name)`, `Future<SharedSearchFolder> createSharedFolderAndMovePin(String searchId, String name)`, `Future<void> movePinToSharedFolder(String searchId, String? folderId)`, `reorderSharedPins`, `refreshSharedFolder`, and `deleteSharedFolderAndPins` notifier commands. Existing profile-folder commands remain until Task 7.

- [ ] **Step 1: Write failing command tests.** Test two profiles in the same folder, moving one pin to Home, cross-profile Move up/down, folder NEW aggregation, and Refresh Folder requests using each owner. Test that hidden feed sources are excluded even if they share a profile. A failed Create folder from move leaves the pin in its original destination.

```dart
final folder = await notifier.createSharedFolder('Animals');
await notifier.movePinToSharedFolder(cat.id, folder.id);
await notifier.movePinToSharedFolder(dog.id, folder.id);
expect(harness.container.read(organizedPinnedSearchesProvider(folder.id)).requireValue.map((s) => s.id), [cat.id, dog.id]);
```

- [ ] **Step 2: Run the three focused test files and confirm failure.** Run `fvm flutter test test/core/search/subscriptions/search_folder_test.dart test/core/search/subscriptions/following_feed_test.dart test/core/search/subscriptions/search_subscriptions_notifier_test.dart`.
- [ ] **Step 3: Add global organization commands beside the old ones.** State holds `SearchOrganization`. The selector maps ordered IDs to independent pins across all configured profiles. `createSharedFolderAndMovePin` writes one organization value; `reorderSharedPins` changes ordered IDs, not per-profile subscription positions. `refreshSharedFolder` sorts members with `compareSearchRefreshPriority` and calls `refresh(id)` for each, which already resolves the owning profile and uses the request gate.

```dart
final byId = {
  for (final pin in state.subscriptions)
    if (pin.feedId == null) pin.id: pin,
};
final ids = folderId == null
    ? state.organization.homeSearchIds
    : state.organization.folders.singleWhere((f) => f.id == folderId).searchIds;
return List.unmodifiable([for (final id in ids) if (byId[id] case final pin?) pin]);
```
- [ ] **Step 4: Format, rerun focused tests, and commit.** Commit Task 3 files as `feat(search): manage mixed-profile folders` after focused tests pass.

### Task 4: Global folder backup format and restore mapping

**Files:**
- Modify: `lib/core/backups/sources/pinned_search_backup_data.dart`
- Modify: `lib/core/backups/sources/pinned_search_backup_codec.dart`
- Modify: `lib/core/backups/sources/pinned_search_import_service.dart`
- Modify: `lib/core/backups/sources/pinned_searches_source.dart`
- Test: `test/core/backups/pinned_search_backup_codec_test.dart`
- Test: `test/core/backups/pinned_search_import_service_test.dart`

**Interfaces:**
- Consumes: global `SearchOrganization` and profile identity resolution.
- Produces: global folder records without `profile`, ordered `homeSearchIds`, `PinnedSearchImportPreview.unmatchedRecordIds`, `UnmatchedPinnedSearchProfilesException`, `preview(PinnedSearchBackupData data, {required List<BooruConfig> profiles})`, and `apply(PinnedSearchBackupData data, {required List<BooruConfig> profiles, bool allowMissingProfiles = false})`.

- [ ] **Step 1: Write failing backup tests.** Round-trip one folder containing pins from profiles 12 and 99, Home order, and an empty folder. Reject duplicate membership, unknown member IDs, and feed-owned IDs. Restore to changed local profile IDs, preserving order and idempotency. Pin-only restore appends new pins to Home without moving existing pins.

```dart
final data = PinnedSearchBackupData(
  records: [catRecord, dogRecord],
  homeSearchIds: const [],
  folders: [PinnedSearchFolderBackupRecord(
    id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    name: 'Animals',
    position: 0,
    searchIds: [catRecord.id, dogRecord.id],
  )],
);
expect(codec.parse(ExportDataPayload.legacy(data: codec.encode(data))), data);
```

- [ ] **Step 2: Run the two backup test files and confirm failure.** Run `fvm flutter test test/core/backups/pinned_search_backup_codec_test.dart test/core/backups/pinned_search_import_service_test.dart`.
- [ ] **Step 3: Implement global backup rows.** Bump the pinned-search backup version from 3 to 4. Folder rows have no profile field; one organization row stores Home order. Parse the organization kind before the current UUID-for-every-row check, because this row has no ID. Validate references against independent pin rows. Keep legacy pin-only rows; old experimental profile-folder rows need no migration. Export folder and Home order from `getOrganization()`.

```dart
final folderRow = {
  'kind': 'folder',
  'id': folder.id,
  'name': folder.name,
  'position': position,
  'searchIds': folder.searchIds,
};
final homeRow = {'kind': 'organization', 'homeSearchIds': data.homeSearchIds};
```

- [ ] **Step 4: Split preview from mutation.** `preview(data, profiles: profiles)` resolves profile references without writing and returns unmatched pin/feed IDs. `apply` rechecks them before its first write; it rejects unmatched profiles unless `allowMissingProfiles` is true. After importing or matching pins, map backed-up IDs to saved IDs, then build folder/Home membership. Preserve existing destinations for pins absent from imported organization data.

```dart
final preview = service.preview(data, profiles: profiles);
if (preview.unmatchedRecordIds.isNotEmpty && !allowMissingProfiles) {
  throw UnmatchedPinnedSearchProfilesException(preview.unmatchedRecordIds);
}
final importedByBackupId = <String, String>{};
for (final record in data.records) {
  final profile = _resolveProfile(record.profile, profiles);
  if (profile == null) continue;
  final saved = await repository.findByQuery(profile.id, record.query) ??
      await repository.create(
        profileId: profile.id,
        query: record.query,
        name: record.name,
        id: record.id,
      );
  importedByBackupId[record.id] = saved.id;
}
```

```dart
class UnmatchedPinnedSearchProfilesException implements Exception {
  const UnmatchedPinnedSearchProfilesException(this.recordIds);
  final Set<String> recordIds;
}
```
- [ ] **Step 5: Format, rerun focused tests, and commit.** Commit Task 4 files as `feat(backup): preserve shared pin folders`.

### Task 5: Confirm unmatched profiles before any restore source writes

**Files:**
- Create: `lib/core/backups/widgets/pinned_search_missing_profiles_dialog.dart`
- Modify: `lib/core/backups/preparation/version_checking.dart`
- Modify: `lib/core/backups/sources/json_source.dart`
- Modify: `lib/core/backups/sources/pinned_searches_source.dart`
- Create: `lib/core/backups/sources/pinned_search_import_preflight.dart`
- Modify: `lib/core/backups/zip/bulk_backup_service.dart`
- Modify: `lib/core/backups/transfer/import/import_data_notifier.dart`
- Modify: `packages/i18n/translations/en-US.json`
- Test: `test/core/backups/pinned_searches_source_test.dart`
- Test: `test/core/backups/server_import_context_test.dart`

**Interfaces:**
- Consumes: `PinnedSearchImportPreview` and `apply(PinnedSearchBackupData data, {required List<BooruConfig> profiles, bool allowMissingProfiles = false})` from Task 4.
- Produces: `PinnedSearchImportApproval` containing the accepted unmatched record IDs; `PinnedSearchesBackupSource.confirmImportPreview(data, projectedProfilesGetter, context)`; `ImportPreparation.preparedData` and optional `executeImport(approval: ...)`; two-phase ZIP and server import.

- [ ] **Step 1: Write failing standalone and multi-source tests.** With one matched and one unmatched pin, cancel or dismiss the warning and assert pin, feed, and organization snapshots are unchanged. Accept and assert only matched records import. Null context with unmatched records throws `ImportCancelledException` before writes. For a ZIP containing profiles, another source, and pins, make the projected profile set leave one pin unmatched; cancel or run headlessly and assert **all** sources, including profiles, remain unchanged. Accept and assert the projected backup profiles import and the unmatched pin is skipped. Test a ZIP without its profiles source selected: match against current profiles. Repeat the cancel/no-writes case for selected server-transfer tasks. Change current profiles while a standalone warning is open and assert it aborts before writes.

```dart
final beforeProfiles = await configRepository.getAll();
final beforePins = await searchRepository.getAll();
final beforeOrg = await searchRepository.getOrganization();
await expectLater(
  bulkService.importFromZip(zipPath, context),
  throwsA(isA<ImportCancelledException>()),
);
expect(await configRepository.getAll(), beforeProfiles);
expect(await searchRepository.getAll(), beforePins);
expect(await searchRepository.getOrganization(), beforeOrg);
```

- [ ] **Step 2: Run the focused backup tests and confirm failure.** Run `fvm flutter test test/core/backups/pinned_searches_source_test.dart test/core/backups/server_import_context_test.dart`; expect the ZIP and server cancel cases to fail because current loops execute earlier sources first.
- [ ] **Step 3: Expose prepared JSON data and an optional approval.** `ImportPreparation` keeps its existing zero-argument execution path for SQLite and other sources. Add `Object? preparedData` and an optional approved executor; `executeImport(approval: value)` calls that executor only when provided, and rejects a non-null approval if no approved executor exists. `ImportPreparationBuilder<T>` records the parsed `T` and wires an optional approved executor. `JsonBackupSource<T>` gains an optional `approvedResultExecutor` for the pinned source only; all existing `resultExecutor` calls keep their behavior.

```dart
class ImportPreparation {
  const ImportPreparation({
    required this.versionCheck,
    required Future<void> Function() executeImport,
    this.preparedData,
    this.executeApprovedImport,
    this.restartApp,
  }) : _executeImport = executeImport;
  final Object? preparedData;
  final Future<void> Function(Object approval)? executeApprovedImport;
  final Future<void> Function() _executeImport;
  final Future<void> Function()? restartApp;

  Future<void> executeImport({bool deferRestart = false, Object? approval}) async {
    if (approval case final value?) {
      final approved = executeApprovedImport;
      if (approved == null) throw StateError('This source does not accept an import approval');
      await approved(value);
    } else {
      await _executeImport();
    }
    if (!deferRestart) await restartApp?.call();
  }
}
```

```dart
// Optional ImportPreparationBuilder<T>.prepare parameter:
Future<void> Function(T parsed, BuildContext? context, Object approval)? approvedExecutor;

return ImportPreparation(
  versionCheck: finalContext.versionCheck ?? const VersionCheckInfo(
    result: VersionCheckResult.compatible,
    currentVersion: null,
    importVersion: null,
  ),
  preparedData: finalContext.parsedData,
  executeImport: () => executor(finalContext.parsedData, uiContext),
  executeApprovedImport: approvedExecutor == null
      ? null
      : (approval) => approvedExecutor(finalContext.parsedData, uiContext, approval),
  restartApp: restartApp,
);
```

- [ ] **Step 4: Add the localized confirmation and source approval.** `confirmImportPreview` calls its asynchronous projected-profile getter before and after the dialog, previews both sets, returns empty approval when all match, and otherwise shows a warning with the skipped count. Cancel, dismissal, unmounted/null context, or a changed unmatched set before return throws `ImportCancelledException`. The normal standalone executor passes the current-profile getter and obtains approval before entering `runSerializedMutation`. The approved executor re-reads actual profiles at execution, compares the unmatched IDs with the approval, and calls `apply(... allowMissingProfiles: true)` only when they agree. It never opens a second dialog. Include feed records in unmatched counts, and use `context.t` for copy. Define the approval in `pinned_search_import_preflight.dart` so both orchestrators can use it.

```dart
final projected = importService.preview(
  data,
  profiles: await projectedProfilesGetter(),
);
if (projected.unmatchedRecordIds.isNotEmpty) {
  if (context == null || !context.mounted) throw const ImportCancelledException();
  final accepted = await showPinnedSearchMissingProfilesDialog(
    context,
    projected.unmatchedRecordIds.length,
  );
  if (accepted != true) throw const ImportCancelledException();
}
final latest = importService.preview(
  data,
  profiles: await projectedProfilesGetter(),
);
if (!const SetEquality<String>().equals(
  projected.unmatchedRecordIds,
  latest.unmatchedRecordIds,
)) throw const ImportCancelledException();
return PinnedSearchImportApproval(projected.unmatchedRecordIds);
```

- [ ] **Step 5: Add a shared preflight helper.** In `pinned_search_import_preflight.dart`, define `PinnedSearchImportApproval` and `preflightPinnedSearches`. It receives prepared sources, selected IDs, the pin source, a current-profile getter, and UI context. With no prepared pin source it returns null. With a selected but unprepared profiles source it aborts before writes. Otherwise it uses the selected profile backup's parsed data or the current profiles and calls `confirmImportPreview` exactly once. Keep this helper read-only.

```dart
final class PinnedSearchImportApproval {
  PinnedSearchImportApproval(Iterable<String> unmatchedRecordIds)
      : unmatchedRecordIds = Set.unmodifiable(unmatchedRecordIds);
  final Set<String> unmatchedRecordIds;
}

Future<PinnedSearchImportApproval?> preflightPinnedSearches({
  required Map<String, ImportPreparation> prepared,
  required Set<String> selectedIds,
  required PinnedSearchesBackupSource pinnedSource,
  required Future<List<BooruConfig>> Function() currentProfiles,
  required BuildContext? context,
}) async {
  final pinData = prepared['pinned_searches']?.preparedData;
  if (pinData is! PinnedSearchBackupData) return null;
  Future<List<BooruConfig>> projectedProfiles;
  if (selectedIds.contains('profiles')) {
    final profileData = prepared['profiles']?.preparedData;
    if (profileData is! List<BooruConfig>) {
      throw StateError('Selected profiles could not be prepared');
    }
    projectedProfiles = () async => profileData;
  } else {
    projectedProfiles = currentProfiles;
  }
  return pinnedSource.confirmImportPreview(pinData, projectedProfiles, context);
}
```

- [ ] **Step 6: Prepare every selected ZIP source before executing any.** Retain priority order. Store each successful `ImportPreparation`, its source ID, and restart callback. Remove the current blanket null-UI skip during preparation; pass nullable context to each source so unmatched pin preflight can reject a headless restore before writes. Call `preflightPinnedSearches` before the execution loop, then pass its approval only to the pin preparation. If the user cancels, rethrow `ImportCancelledException` before any `executeImport` call. If profile execution later fails, stop rather than executing pins against the wrong profile set. Preserve per-source results for unrelated preparation failures.

```dart
final approval = await preflightPinnedSearches(
  prepared: preparedById,
  selectedIds: sourcesToProcess.toSet(),
  pinnedSource: registry.getSource('pinned_searches')! as PinnedSearchesBackupSource,
  currentProfiles: () => ref.read(booruConfigRepoProvider).getAll(),
  context: uiContext,
);
for (final entry in preparedInPriorityOrder) {
  await entry.preparation.executeImport(
    deferRestart: true,
    approval: entry.sourceId == 'pinned_searches' ? approval : null,
  );
}
```

- [ ] **Step 7: Apply the same preflight to server transfer.** `ImportDataNotifier.startImport` first prepares all selected tasks and stores their preparations without executing any. It calls `preflightPinnedSearches`, then runs the prepared tasks in source-priority order. On cancel, mark the transfer canceled and execute none. If selected profiles cannot prepare or fail execution, abort dependent pin execution. Keep the selected task status UI accurate; existing `server_import_context_test.dart` protects context behavior.

```dart
final prepared = <String, ImportPreparation>{};
final orderedTasks = selectedTasks.toList()
  ..sort((a, b) => registry.getSource(a.id)!.priority.compareTo(registry.getSource(b.id)!.priority));
for (final task in orderedTasks) {
  final source = registry.getSource(task.id)!;
  prepared[task.id] = await source.capabilities.server.prepareImport(serverUrl, uiContext);
}
final approval = await preflightPinnedSearches(
  prepared: prepared,
  selectedIds: orderedTasks.map((task) => task.id).toSet(),
  pinnedSource: registry.getSource('pinned_searches')! as PinnedSearchesBackupSource,
  currentProfiles: () => ref.read(booruConfigRepoProvider).getAll(),
  context: uiContext,
);
for (final task in orderedTasks) {
  await prepared[task.id]!.executeImport(
    deferRestart: true,
    approval: task.id == 'pinned_searches' ? approval : null,
  );
}
```

- [ ] **Step 8: Generate strings, format, rerun focused tests, and commit.** Run `./gen.sh`, `fvm dart format` on changed Dart files, and both focused backup test files. Stage only Task 5 source, translation, and generated files; commit `feat(backup): preflight skipped pin profiles`.

### Task 6: Ungrouped root, profile footnotes, and folder manager

**Files:**
- Modify: `lib/core/search/subscriptions/src/pages/pinned_searches_page.dart`
- Create: `lib/core/search/subscriptions/src/pages/search_folder_management_page.dart`
- Modify: `lib/core/search/subscriptions/src/widgets/pinned_search_card.dart`
- Modify: `packages/i18n/translations/en-US.json`
- Test: `test/core/search/subscriptions/all_profile_pinned_searches_test.dart`
- Test: `test/core/search/subscriptions/pinned_searches_page_test.dart`
- Test: `test/core/search/subscriptions/search_folder_test.dart`

**Interfaces:**
- Consumes: `organizedPinnedSearchesProvider`, global notifier folder commands, and profile config lookup.
- Produces: one root collection, folder pages without `profileId`, owner footnotes, and Manage folders page.

- [ ] **Step 1: Write failing widget tests.** Assert all Home pins are visible without profile headers or an Unfiled heading; named folders appear first. Test a named profile, an unnamed profile using URL, and duplicate profile names using URL disambiguation. Assert opening a pin switches to its owner. In Manage folders, create/rename/reorder, cancel Delete, then confirm Delete and assert member pins are gone while unrelated Home pins remain.

```dart
expect(find.text('Cats'), findsOneWidget);
expect(find.text('Other search'), findsOneWidget);
expect(find.text('Unfiled'), findsNothing);
expect(find.byTooltip('Manage folders'), findsOneWidget);
```

- [ ] **Step 2: Run the three widget test files and confirm failure.** Run `fvm flutter test test/core/search/subscriptions/all_profile_pinned_searches_test.dart test/core/search/subscriptions/pinned_searches_page_test.dart test/core/search/subscriptions/search_folder_test.dart`.
- [ ] **Step 3: Build the root and manager screens.** Root reads all independent pins through the global selector; folder rows render before Home cards. Remove `ExpansionTile` profile groups and the per-profile management shortcut. `PinnedSearchCard` receives an owner caption computed from profile name and URL. The app-bar button opens `SearchFolderManagementPage`. Its Delete dialog names the folder, counts members, warns about unpinning, and calls `deleteSharedFolderAndPins` only on confirmation. Retain folder NEW/Refresh and root Refresh All behavior.

```dart
final configs = ref.watch(booruConfigProvider);
final nameCounts = <String, int>{};
for (final config in configs) {
  nameCounts.update(config.name, (count) => count + 1, ifAbsent: () => 1);
}
final config = configs.singleWhere((candidate) => candidate.id == subscription.profileId);
final ownerCaption = config.name.isEmpty
    ? config.url
    : nameCounts[config.name] == 1
        ? config.name
        : '${config.name} · ${config.url}';
if (confirmed == true) {
  await ref.read(searchSubscriptionsProvider.notifier)
      .deleteSharedFolderAndPins(folder.id);
}
```
- [ ] **Step 4: Generate strings, format, rerun widget tests, and commit.** Run `./gen.sh`, `fvm dart format` on changed Dart files, and the three test files. Commit Task 6 files as `feat(search): show shared folders and pin owners`.

### Task 7: Global pin and Move to folder pickers

**Files:**
- Modify: `lib/core/search/subscriptions/src/widgets/pin_search_folder_picker.dart`
- Create: `lib/core/search/subscriptions/src/widgets/move_pin_to_folder_dialog.dart`
- Modify: `lib/core/search/subscriptions/src/pages/pinned_searches_page.dart`
- Modify: `lib/core/search/search/src/widgets/search_page_scaffold.dart`
- Remove: `lib/core/search/subscriptions/src/types/search_folder.dart` after all old callers are migrated
- Modify: `lib/core/search/subscriptions/src/types/search_subscription_repository.dart`
- Modify: `lib/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart`
- Modify: `lib/core/search/subscriptions/src/providers/search_subscriptions_notifier.dart`
- Modify: `lib/core/search/subscriptions/src/providers/search_subscription_selectors.dart`
- Modify: `lib/core/search/subscriptions/types.dart`
- Modify: `packages/i18n/translations/en-US.json`
- Test: `test/core/search/subscriptions/pin_search_dialog_test.dart`
- Test: `test/core/search/subscriptions/search_page_pin_action_test.dart`
- Test: `test/core/search/subscriptions/pinned_searches_page_test.dart`

**Interfaces:**
- Consumes: global folders, `createSharedFolderAndMovePin`, and `movePinToSharedFolder` from Task 3.
- Produces: `[Home]` plus every named folder in both pickers; Create folder from Move to folder.

- [ ] **Step 1: Write failing dialog tests.** From a pin owned by profile 12, choose a folder containing profile 99 pins and assert it moves there without changing owner. Choose `[Home]` and assert it leaves the folder. Create a folder from Move to folder and assert the pin lands in it. Cancel the create dialog or force a creation failure and assert its old membership remains.

```dart
await tester.tap(find.text('Move to folder'));
await settle(tester);
expect(find.text('[Home]'), findsOneWidget);
expect(find.text('Create folder'), findsOneWidget);
```

- [ ] **Step 2: Run the three dialog test files and confirm failure.** Run `fvm flutter test test/core/search/subscriptions/pin_search_dialog_test.dart test/core/search/subscriptions/search_page_pin_action_test.dart test/core/search/subscriptions/pinned_searches_page_test.dart`.
- [ ] **Step 3: Replace profile-filtered choices and remove legacy APIs.** Remove `profileId` from `PinSearchFolderPicker` and its caller. Its list comes from global organization. Extract the current inline Move dialog into `move_pin_to_folder_dialog.dart`; return a `FolderChoice` record and have the page call `movePinToSharedFolder` or `createSharedFolderAndMovePin`. A failed create shows the localized operation error and leaves the pin in its old destination. After all callers use global APIs, remove old `SearchFolder`, `getFolders`/`replaceFolders`, profile-folder notifier methods, and the old selector.

```dart
typedef FolderChoice = ({String? folderId, String? createName});

final choice = await showMovePinToFolderDialog(context, folders);
if (choice == null) return;
if (choice.createName case final name?) {
  await notifier.createSharedFolderAndMovePin(subscription.id, name);
} else {
  await notifier.movePinToSharedFolder(subscription.id, choice.folderId);
}
```
- [ ] **Step 4: Generate strings if changed, format, rerun dialog tests, and commit.** Commit Task 7 files as `feat(search): create shared folders while moving pins`.

### Task 8: Integration verification and documentation

**Files:**
- Modify: `docs/pinned_searches.md`
- Modify: `docs/work/in-progress/PS-018-rework-pinned-search-folder-navigation.md` after claiming it
- Test: focused files listed in Tasks 1–7 plus the full Flutter suite

**Interfaces:**
- Consumes: completed Tasks 1–7.
- Produces: documented current behavior and completion evidence for PS-018.

- [ ] **Step 1: Run static and automated checks.** Run `fvm dart format` on changed Dart files, `fvm flutter analyze`, and `fvm flutter test`. Record counts and any remaining failures; fix only failures caused by this feature, rerunning the focused test first.
- [ ] **Step 2: Validate Android flows with Maestro MCP.** On the available emulator, verify Home-only display, mixed-profile folder contents and footnotes, Create folder from Move to folder, owner-aware opening, folder refresh, and confirmed/canceled destructive deletion. Record observed results separately from automated checks.
- [ ] **Step 3: Update documentation and the task file.** Replace the old profile-owned folder description in `docs/pinned_searches.md`. Record verification and handover in PS-018. Move it to `docs/work/done/` only if every acceptance criterion is verified; otherwise document the remaining blocker in its queue file.
- [ ] **Step 4: Check the final diff and commit.** Run `git diff --check`, inspect staged paths, and commit only related documentation or final fixes with conventional summaries. Follow the repository PR workflow for delivery; do not merge without explicit user approval.
