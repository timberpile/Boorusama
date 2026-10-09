// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../export_import/import/collection_import_action.dart';
import '../export_import/models/import_action.dart';
import '../../configs/config/types.dart';
import '../../search/subscriptions/types.dart';
import 'pinned_search_backup_data.dart';
import '../../groups/folder_tree.dart';
import 'package:uuid/uuid.dart';
import 'search_backup_profile.dart';
import '../export_import/import/search_runtime_snapshot.dart';

class PinnedSearchImportResult extends Equatable {
  const PinnedSearchImportResult({
    required this.importedCount,
    required this.alreadyExistedCount,
    required this.skippedProfileCount,
  });

  final int importedCount;
  final int alreadyExistedCount;
  final int skippedProfileCount;

  @override
  List<Object?> get props => [
    importedCount,
    alreadyExistedCount,
    skippedProfileCount,
  ];
}

class PinnedSearchImportPreview extends Equatable {
  PinnedSearchImportPreview({required Set<String> unmatchedRecordIds})
    : unmatchedRecordIds = Set.unmodifiable(unmatchedRecordIds);

  final Set<String> unmatchedRecordIds;

  @override
  List<Object?> get props => [unmatchedRecordIds];
}

class UnmatchedPinnedSearchProfilesException implements Exception {
  const UnmatchedPinnedSearchProfilesException(this.recordIds);

  final Set<String> recordIds;
}

class PinnedSearchImportService {
  const PinnedSearchImportService({
    required this.repository,
    this.importFolderName = 'Imported Searches',
  });

  final SearchSubscriptionRepository repository;
  final String importFolderName;

  PinnedSearchImportPreview preview(
    PinnedSearchBackupData data, {
    required List<BooruConfig> profiles,
    BackupProfileIdResolver? profileIdResolver,
    Map<String, ImportAction>? recordActions,
  }) => PinnedSearchImportPreview(
    unmatchedRecordIds: {
      for (final record in data.records)
        if (recordActions?[record.id] != ImportAction.skip &&
            resolveBackupProfileId(
                  record.profile,
                  profiles,
                  resolver: profileIdResolver,
                ) ==
                null)
          record.id,
    },
  );

  Future<PinnedSearchImportResult> replace(
    PinnedSearchBackupData data, {
    required List<BooruConfig> profiles,
    BackupProfileIdResolver? profileIdResolver,
  }) async {
    final snapshots = SearchRuntimeSnapshotService(repository);
    final previous = await snapshots.capture();
    try {
      return await _replace(
        data,
        profiles: profiles,
        profileIdResolver: profileIdResolver,
      );
    } catch (error, stack) {
      await snapshots.restore(previous);
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<PinnedSearchImportResult> _replace(
    PinnedSearchBackupData data, {
    required List<BooruConfig> profiles,
    BackupProfileIdResolver? profileIdResolver,
  }) async {
    final previousOrganization = await repository.getOrganization();
    final internalIds = {
      for (final feed in await repository.getFeeds()) ...feed.sourceIds,
    };
    final result = await apply(
      data,
      profiles: profiles,
      profileIdResolver: profileIdResolver,
      restoreHierarchy: true,
    );
    final importedByBackupId = <String, String>{};
    for (final record in data.records) {
      final profileId = resolveBackupProfileId(
        record.profile,
        profiles,
        resolver: profileIdResolver,
      );
      if (profileId == null) continue;
      final saved = await repository.findByQuery(profileId, record.query);
      if (saved != null && !internalIds.contains(saved.id)) {
        importedByBackupId[record.id] = saved.id;
      }
    }
    final retainedIds = {...internalIds, ...importedByBackupId.values};
    for (final search in await repository.getAll()) {
      if (!retainedIds.contains(search.id)) await repository.delete(search.id);
    }

    final assigned = <String>{};
    List<String> mapped(Iterable<String> ids) => [
      for (final id in ids)
        if (importedByBackupId[id] case final savedId?)
          if (assigned.add(savedId)) savedId,
    ];

    final folders = data.folders.toList()
      ..sort((left, right) => left.position.compareTo(right.position));
    await repository.replaceOrganization(
      SearchOrganization(
        folders: [
          for (final folder in folders)
            SharedSearchFolder(
              id: folder.id,
              name: folder.name,
              parentId: folder.parentId,
              position: folder.position,
              searchIds: mapped(folder.searchIds),
            ),
        ],
        homeSearchIds: [
          ...previousOrganization.homeSearchIds.where(internalIds.contains),
          ...mapped(data.homeSearchIds),
        ],
      ),
    );
    return result;
  }

  Future<PinnedSearchImportResult> apply(
    PinnedSearchBackupData data, {
    required List<BooruConfig> profiles,
    bool allowMissingProfiles = false,
    Map<String, CollectionImportAction>? folderActions,
    Map<String, ImportAction>? recordActions,
    BackupProfileIdResolver? profileIdResolver,
    bool restoreHierarchy = false,
  }) async {
    final unmatched = preview(
      data,
      profiles: profiles,
      profileIdResolver: profileIdResolver,
      recordActions: recordActions,
    ).unmatchedRecordIds;
    if (unmatched.isNotEmpty && !allowMissingProfiles) {
      throw UnmatchedPinnedSearchProfilesException(unmatched);
    }
    FolderTree([
      for (final f in data.folders)
        CollectionFolder(
          id: f.id,
          name: f.name,
          parentId: f.parentId,
          position: f.position,
        ),
    ]);
    final previousOrganization = await repository.getOrganization();
    final createdIds = <String>[];
    final importedByBackupId = <String, String>{};
    final ordered = data.records.indexed.toList()
      ..sort((left, right) {
        final byPosition = left.$2.position.compareTo(right.$2.position);
        return byPosition != 0 ? byPosition : left.$1.compareTo(right.$1);
      });
    final mapped = [
      for (final (_, record) in ordered)
        (
          record: record,
          profileId: resolveBackupProfileId(
            record.profile,
            profiles,
            resolver: profileIdResolver,
          ),
        ),
    ];
    var imported = 0;
    var existing = 0;
    var skipped = 0;
    try {
      for (final (:record, :profileId) in mapped) {
        if (recordActions?[record.id] == ImportAction.skip ||
            pinnedSearchFolderSkipped(data, record.id, folderActions ?? {})) {
          continue;
        }
        if (profileId == null) {
          skipped++;
          continue;
        }
        final byId = await repository.getById(record.id);
        final byQuery = await repository.findByQuery(profileId, record.query);
        final saved = byQuery;
        if (saved != null) {
          importedByBackupId[record.id] = saved.id;
          existing++;
          continue;
        }
        final created = await repository.create(
          profileId: profileId,
          query: record.query,
          queryStructure: record.queryStructure,
          name: record.name,
          id: byId == null ? record.id : null,
        );
        importedByBackupId[record.id] = created.id;
        createdIds.add(created.id);
        imported++;
      }
      if (!restoreHierarchy) {
        await repository.replaceOrganization(
          planPinnedSearchFolderImport(
            current: previousOrganization,
            data: data,
            importedByBackupId: importedByBackupId,
            createdIds: createdIds.toSet(),
            folderActions: folderActions ?? {},
            wrapperName: importFolderName,
            newId: () => const Uuid().v4(),
          ),
        );
      }
    } catch (error, stack) {
      for (final id in createdIds) {
        await repository.delete(id);
      }
      await repository.replaceOrganization(previousOrganization);
      Error.throwWithStackTrace(error, stack);
    }
    return PinnedSearchImportResult(
      importedCount: imported,
      alreadyExistedCount: existing,
      skippedProfileCount: skipped,
    );
  }
}

SearchOrganization planPinnedSearchFolderImport({
  required SearchOrganization current,
  required PinnedSearchBackupData data,
  required Map<String, String> importedByBackupId,
  required Set<String> createdIds,
  required Map<String, CollectionImportAction> folderActions,
  required String wrapperName,
  required String Function() newId,
}) {
  final assignedCopies = <String>{};
  final uniqueImported = {
    for (final e in importedByBackupId.entries)
      if (assignedCopies.add(e.value)) e.key: e.value,
  };
  final locations = {
    for (final f in data.folders)
      for (final (i, id) in f.searchIds.indexed)
        id: FolderPlacement(itemId: id, folderId: f.id, position: i),
    for (final (i, id) in data.homeSearchIds.indexed)
      id: FolderPlacement(itemId: id, position: i),
  };
  final sourceFolders = [
    for (final f in data.folders)
      CollectionFolder(
        id: f.id,
        name: f.name,
        parentId: f.parentId,
        position: f.position,
      ),
  ];
  final sourceTree = FolderTree(sourceFolders);
  if (sourceFolders.isEmpty) {
    var position = current.placements
        .where((p) => p.folderId == null)
        .fold(0, (next, p) => p.position >= next ? p.position + 1 : next);
    final ordered = uniqueImported.entries.toList()
      ..sort(
        (a, b) =>
            (locations[a.key]?.position ??
                    data.records.indexWhere((r) => r.id == a.key))
                .compareTo(
                  locations[b.key]?.position ??
                      data.records.indexWhere((r) => r.id == b.key),
                ),
      );
    return SearchOrganization(
      folders: current.folders,
      placements: [
        ...current.placements,
        for (final entry in ordered)
          if (createdIds.contains(entry.value))
            FolderPlacement(itemId: entry.value, position: position++),
      ],
    );
  }

  String? targetFolder(String sourceId) {
    final folderId = locations[sourceId]?.folderId;
    final action = folderActions[folderId];
    final target = switch (action?.action) {
      ImportAction.mergeIntoTarget => action?.targetId,
      ImportAction.update || ImportAction.merge
          when current.tree.byId.containsKey(folderId) =>
        folderId,
      _ => null,
    };
    if (action?.action == ImportAction.mergeIntoTarget &&
        (target == null || !current.tree.byId.containsKey(target))) {
      throw StateError('Missing folder target');
    }
    return target;
  }

  final copies = uniqueImported.entries
      .where((e) => createdIds.contains(e.value))
      .toList();
  final reconstructed = copies
      .where((e) => targetFolder(e.key) == null)
      .toList();
  final requestedCopies = {
    for (final f in data.folders)
      if (folderActions[f.id]?.action == ImportAction.copy &&
          !sourceTree
              .ancestors(f.id)
              .any((a) => folderActions[a.id]?.action == ImportAction.skip))
        f.id,
  };
  final currentFolders = [
    for (final f in current.folders)
      if (folderActions[f.id]?.action == ImportAction.update)
        SharedSearchFolder(
          id: f.id,
          name: data.folders.singleWhere((r) => r.id == f.id).name,
          parentId: f.parentId,
          position: f.position,
        )
      else
        f,
  ];
  final requiredPaths = [
    for (final e in reconstructed) locations[e.key]?.folderId,
    ...requestedCopies,
  ];
  final hierarchy = requiredPaths.isEmpty
      ? null
      : planFolderHierarchyCopy(
          current: currentFolders,
          incoming: sourceFolders,
          itemFolders: requiredPaths,
          wrapperName: wrapperName,
          newId: newId,
        );
  final placements = [...current.placements];
  for (final entry in copies) {
    final source = locations[entry.key];
    final target = targetFolder(entry.key);
    final destination =
        target ??
        (source?.folderId == null
            ? hierarchy!.wrapperId
            : hierarchy!.folderIds[source!.folderId]);
    final position = target == null
        ? source?.position ?? placements.length
        : placements
              .where((p) => p.folderId == target)
              .fold(0, (n, p) => p.position >= n ? p.position + 1 : n);
    placements.add(
      FolderPlacement(
        itemId: entry.value,
        folderId: destination,
        position: position,
      ),
    );
  }
  final folders = hierarchy?.folders ?? currentFolders;
  final organization = SearchOrganization(
    folders: [
      for (final f in folders)
        SharedSearchFolder(
          id: f.id,
          name: f.name,
          parentId: f.parentId,
          position: f.position,
        ),
    ],
    placements: placements,
  );
  organization.tree.validatePlacements(organization.placements);
  return organization;
}

bool pinnedSearchFolderSkipped(
  PinnedSearchBackupData data,
  String searchId,
  Map<String, CollectionImportAction> actions,
) {
  final folder = data.folders
      .where((f) => f.searchIds.contains(searchId))
      .firstOrNull;
  if (folder == null) return false;
  final tree = FolderTree([
    for (final f in data.folders)
      CollectionFolder(
        id: f.id,
        name: f.name,
        parentId: f.parentId,
        position: f.position,
      ),
  ]);
  return tree
      .ancestors(folder.id)
      .any((f) => actions[f.id]?.action == ImportAction.skip);
}
