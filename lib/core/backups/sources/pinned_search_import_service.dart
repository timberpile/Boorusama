// Package imports:
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

// Project imports:
import '../export_import/import/collection_import_action.dart';
import '../export_import/models/import_action.dart';
import '../../configs/config/types.dart';
import '../../search/subscriptions/types.dart';
import 'pinned_search_backup_data.dart';
import 'search_backup_profile.dart';

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
  const PinnedSearchImportService({required this.repository});

  final SearchSubscriptionRepository repository;

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
    final previousOrganization = await repository.getOrganization();
    final internalIds = {
      for (final feed in await repository.getFeeds()) ...feed.sourceIds,
    };
    final result = await apply(
      data,
      profiles: profiles,
      profileIdResolver: profileIdResolver,
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
    for (final (:record, :profileId) in mapped) {
      if (recordActions?[record.id] == ImportAction.skip) continue;
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
    if (createdIds.isNotEmpty ||
        data.folders.isNotEmpty ||
        data.homeSearchIds.isNotEmpty) {
      final organization = SearchOrganization(
        folders: previousOrganization.folders,
        homeSearchIds: [...previousOrganization.homeSearchIds, ...createdIds],
      );
      final assigned = <String>{};
      List<String> mappedIds(Iterable<String> ids) => [
        for (final id in ids)
          if (importedByBackupId[id] case final savedId?)
            if (assigned.add(savedId)) savedId,
      ];
      final home = mappedIds(data.homeSearchIds);
      final orderedFolders = data.folders.toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      final importedFolders = <SharedSearchFolder>[];
      final matchedFolderIds = <String>{};
      for (final record in orderedFolders) {
        final existingFolder =
            organization.folders.firstWhereOrNull(
              (folder) => folder.id == record.id,
            ) ??
            organization.folders.firstWhereOrNull(
              (folder) =>
                  folder.name.toLowerCase() == record.name.toLowerCase(),
            );
        final folderId = existingFolder?.id ?? record.id;
        matchedFolderIds.add(folderId);
        final importedIndex = importedFolders.indexWhere(
          (folder) => folder.id == folderId,
        );
        final members = mappedIds(record.searchIds);
        final folder = SharedSearchFolder(
          id: folderId,
          name: existingFolder?.name ?? record.name,
          searchIds: [
            if (importedIndex >= 0) ...importedFolders[importedIndex].searchIds,
            ...members,
          ],
        );
        if (importedIndex >= 0) {
          importedFolders[importedIndex] = folder;
        } else {
          importedFolders.add(folder);
        }
      }
      await repository.replaceOrganization(
        folderActions == null
            ? SearchOrganization(
                folders: [
                  for (final folder in importedFolders)
                    SharedSearchFolder(
                      id: folder.id,
                      name: folder.name,
                      searchIds: [
                        ...folder.searchIds,
                        ...?organization.folders
                            .firstWhereOrNull(
                              (local) => local.id == folder.id,
                            )
                            ?.searchIds
                            .where((id) => !assigned.contains(id)),
                      ],
                    ),
                  for (final folder in organization.folders)
                    if (!matchedFolderIds.contains(folder.id))
                      SharedSearchFolder(
                        id: folder.id,
                        name: folder.name,
                        searchIds: folder.searchIds.where(
                          (id) => !assigned.contains(id),
                        ),
                      ),
                ],
                homeSearchIds: [
                  ...home,
                  ...organization.homeSearchIds.where(
                    (id) => !assigned.contains(id),
                  ),
                ],
              )
            : _applyFolderActions(
                current: previousOrganization,
                imported: data,
                importedByBackupId: importedByBackupId,
                actions: folderActions,
                createdIds: createdIds,
              ),
      );
    }
    return PinnedSearchImportResult(
      importedCount: imported,
      alreadyExistedCount: existing,
      skippedProfileCount: skipped,
    );
  }
}

SearchOrganization _applyFolderActions({
  required SearchOrganization current,
  required PinnedSearchBackupData imported,
  required Map<String, String> importedByBackupId,
  required Map<String, CollectionImportAction> actions,
  required List<String> createdIds,
}) {
  final folders = current.folders.toList();
  final importedAssigned = <String>{};
  List<String> mapped(Iterable<String> ids) => [
    for (final id in ids)
      if (importedByBackupId[id] case final localId?)
        if (importedAssigned.add(localId)) localId,
  ];

  final home = mapped(imported.homeSearchIds);
  final ordered = imported.folders.toList()
    ..sort((left, right) => left.position.compareTo(right.position));
  final operations = <({int position, SharedSearchFolder folder})>[];
  final removedIds = <String>{};
  for (final record in ordered) {
    final resolution = actions[record.id];
    if (resolution == null || resolution.action == ImportAction.skip) continue;
    final members = mapped(record.searchIds);
    final matchingIndex = folders.indexWhere(
      (folder) => folder.id == record.id,
    );
    final targetId = switch (resolution.action) {
      ImportAction.mergeIntoTarget => resolution.targetId,
      ImportAction.copy =>
        resolution.destinationId ?? (matchingIndex < 0 ? record.id : null),
      _ => record.id,
    };
    if (targetId == null) throw StateError('Folder target is unresolved.');
    final targetIndex = folders.indexWhere((folder) => folder.id == targetId);
    final target = targetIndex < 0 ? null : folders[targetIndex];
    final folder = switch (resolution.action) {
      ImportAction.update || ImportAction.replace => SharedSearchFolder(
        id: targetId,
        name: record.name,
        searchIds: members,
      ),
      ImportAction.merge || ImportAction.mergeIntoTarget => SharedSearchFolder(
        id: targetId,
        name: target?.name ?? record.name,
        searchIds: _orderedUnion(target?.searchIds ?? const [], members),
      ),
      ImportAction.copy => SharedSearchFolder(
        id: targetId,
        name: record.name,
        searchIds: members,
      ),
      _ => throw StateError('Folder action is not applicable.'),
    };
    if (targetIndex >= 0) removedIds.add(targetId);
    operations.add((position: record.position, folder: folder));
  }

  final placed = {
    ...home,
    for (final operation in operations) ...operation.folder.searchIds,
  };
  final remaining = [
    for (final folder in folders)
      if (!removedIds.contains(folder.id))
        SharedSearchFolder(
          id: folder.id,
          name: folder.name,
          searchIds: folder.searchIds.where((id) => !placed.contains(id)),
        ),
  ];
  for (final operation in operations) {
    remaining.insert(
      operation.position.clamp(0, remaining.length),
      operation.folder,
    );
  }
  final organized = {
    ...home,
    for (final folder in remaining) ...folder.searchIds,
  };
  final unassignedCreated = createdIds.where((id) => !organized.contains(id));
  return SearchOrganization(
    folders: remaining,
    homeSearchIds: [
      ...home,
      ...current.homeSearchIds.where((id) => !placed.contains(id)),
      ...unassignedCreated,
    ],
  );
}

List<String> _orderedUnion(Iterable<String> first, Iterable<String> second) {
  final seen = <String>{};
  return [
    for (final id in [...first, ...second])
      if (seen.add(id)) id,
  ];
}
