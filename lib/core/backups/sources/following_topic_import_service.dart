// Package imports:
import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';

// Project imports:
import '../export_import/import/collection_import_action.dart';
import '../export_import/models/import_action.dart';
import '../../configs/config/types.dart';
import '../../search/following_topics/types.dart';
import '../../search/following_topics/src/types/following_mirror_state.dart';
import 'following_topic_backup_data.dart';
import '../../groups/folder_tree.dart';

import 'package:uuid/uuid.dart';

import 'search_backup_profile.dart';
import '../export_import/import/search_runtime_snapshot.dart';

class FollowingTopicImportResult extends Equatable {
  const FollowingTopicImportResult({
    required this.importedCount,
    required this.alreadyExistedCount,
    required this.skippedProfileCount,
    this.resolvedIds = const {},
  });

  final int importedCount;
  final int alreadyExistedCount;
  final int skippedProfileCount;
  final Map<String, String> resolvedIds;

  @override
  List<Object?> get props => [
    importedCount,
    alreadyExistedCount,
    skippedProfileCount,
    resolvedIds,
  ];
}

class FollowingTopicImportPreview extends Equatable {
  FollowingTopicImportPreview({required Set<String> unmatchedRecordIds})
    : unmatchedRecordIds = Set.unmodifiable(unmatchedRecordIds);

  final Set<String> unmatchedRecordIds;

  @override
  List<Object?> get props => [unmatchedRecordIds];
}

class FollowingTopicImportService {
  const FollowingTopicImportService({
    required this.repository,
    this.importFolderName = 'Imported Searches',
    this.clock = const Clock(),
  });

  final FollowingTopicRepository repository;
  final String importFolderName;
  final Clock clock;

  Future<FollowingMirrorState> _mirrors() async =>
      repository is FollowingMirrorStore
      ? (await (repository as FollowingMirrorStore).readMirrorSnapshot())
            .mirrors
      : const FollowingMirrorState.empty();

  FollowingTopicImportPreview preview(
    FollowingTopicBackupData data, {
    required List<BooruConfig> profiles,
    BackupProfileIdResolver? profileIdResolver,
    Map<String, ImportAction>? recordActions,
  }) => FollowingTopicImportPreview(
    // A valid portable source is sufficient for persistence. Availability is a
    // separate, current read-policy decision, not permission to discard data.
    unmatchedRecordIds: const {},
  );

  Future<FollowingTopicImportResult> replace(
    FollowingTopicBackupData data, {
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

  Future<FollowingTopicImportResult> _replace(
    FollowingTopicBackupData data, {
    required List<BooruConfig> profiles,
    BackupProfileIdResolver? profileIdResolver,
  }) async {
    final previousOrganization = await repository.getOrganization();
    final mirrors = await _mirrors();
    final folderIds = previousOrganization.folders
        .map((folder) => folder.id)
        .toSet();
    final internalIds = {
      for (final feed in await repository.getFeeds())
        if (!folderIds.contains(feed.id)) ...feed.sourceIds,
    };
    final result = await apply(
      data,
      profiles: profiles,
      profileIdResolver: profileIdResolver,
      restoreHierarchy: true,
    );
    // The importer assigns a separate destination to each source record.
    // Resolving again by query would collapse independent duplicate topics.
    final importedByBackupId = result.resolvedIds;
    final retainedIds = {
      ...internalIds,
      ...importedByBackupId.values,
      ...mirrors.owners.keys,
    };
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
    final imported = TopicOrganization(
      folders: [
        for (final folder in folders)
          TopicFolder(
            id: folder.id,
            name: folder.name,
            parentId: folder.parentId,
            position: folder.position,
            searchIds: mapped(folder.searchIds),
            feedEnabled: folder.feedEnabled,
            feedMaxPosts: folder.feedMaxPosts,
          ),
      ],
      homeSearchIds: mapped(data.homeSearchIds),
    );
    await repository.replaceOrganization(
      TopicOrganization(
        folders: [
          ...previousOrganization.folders.where(
            (folder) => mirrors.isReceived(folder.id),
          ),
          ...imported.folders,
        ],
        placements: [
          ...previousOrganization.placements.where(
            (p) =>
                mirrors.isReceived(p.itemId) || internalIds.contains(p.itemId),
          ),
          ...imported.placements,
        ],
      ),
    );
    return result;
  }

  /// Call inside the existing serialized import mutation/transaction.
  Future<FollowingTopicImportResult> apply(
    FollowingTopicBackupData data, {
    required List<BooruConfig> profiles,
    // Retained for source compatibility; missing profiles no longer drop Topics.
    bool allowMissingProfiles = false,
    Map<String, CollectionImportAction>? folderActions,
    Map<String, ImportAction>? recordActions,
    BackupProfileIdResolver? profileIdResolver,
    bool restoreHierarchy = false,
  }) async {
    final mirrors = await _mirrors();
    if (data.records.any((record) => mirrors.isReceived(record.id)) ||
        data.folders.any((folder) => mirrors.isReceived(folder.id)) ||
        (folderActions?.values.any(
              (action) => mirrors.isReceived(action.targetId ?? ''),
            ) ??
            false)) {
      throw const FollowingMirrorReadOnly();
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
    final usedDestinationIds = <String>{};
    final ordered = data.records.indexed.toList()
      ..sort((left, right) {
        final byPosition = left.$2.position.compareTo(right.$2.position);
        return byPosition != 0 ? byPosition : left.$1.compareTo(right.$1);
      });
    final mapped = [
      for (final (_, record) in ordered)
        (
          record: record,
          profileId: profileIdResolver == null
              ? resolveBackupProfile(record.profile, profiles)?.id
              : profileIdResolver(record.profile),
        ),
    ];
    var imported = 0;
    var existing = 0;
    try {
      for (final (:record, :profileId) in mapped) {
        if (recordActions?[record.id] == ImportAction.skip ||
            followingTopicFolderSkipped(data, record.id, folderActions ?? {})) {
          continue;
        }
        final byId = await repository.getById(record.id);
        final current = await repository.getAll();
        final saved = findMatchingTopicForImport(
          record: record,
          data: data,
          profileId: profileId,
          searches: current.where(
            (topic) => !mirrors.isReceived(topic.id),
          ),
          organization: await repository.getOrganization(),
          usedIds: usedDestinationIds,
          folderActions: folderActions ?? {},
          restoreHierarchy: restoreHierarchy,
          importFolderName: importFolderName,
        );
        if (saved != null) {
          usedDestinationIds.add(saved.id);
          importedByBackupId[record.id] = saved.id;
          if (restoreHierarchy) {
            await repository.setAutoUpdate(
              [saved.id],
              record.autoUpdateEnabled,
            );
          }
          existing++;
          continue;
        }
        final FollowingTopic created;
        if (profileId == null) {
          final occupiedIds = {for (final topic in current) topic.id};
          String unusedUuid(Set<String> occupied) {
            var id = const Uuid().v4();
            while (occupied.contains(id)) {
              id = const Uuid().v4();
            }
            return id;
          }

          final id = byId == null ? record.id : unusedUuid(occupiedIds);
          final namespace = unusedUuid({
            ...occupiedIds,
            id,
            for (final topic in current) topic.profileId,
            for (final profile in profiles) profile.id,
            for (final incoming in data.records) incoming.profile.id,
          });
          created = profilelessFollowingTopicForImport(
            record: record,
            id: id,
            namespace: namespace,
            createdAt: clock.now().toUtc(),
          );
          // This namespace is new and empty. Never use aggregate restoration to
          // attach provenance to an existing profile bucket: that would reset
          // unrelated runtime/history state. Register ownership before writing
          // so outer import rollback also covers a partially failed restore.
          createdIds.add(id);
          await repository.restoreForProfile(namespace, [created]);
        } else {
          created = await repository.create(
            profileId: profileId,
            query: record.query,
            queryStructure: record.queryStructure,
            name: record.name,
            id: byId == null ? record.id : null,
          );
          createdIds.add(created.id);
        }
        importedByBackupId[record.id] = created.id;
        usedDestinationIds.add(created.id);
        if (!record.autoUpdateEnabled) {
          await repository.setAutoUpdate([created.id], false);
        }
        imported++;
      }
      if (!restoreHierarchy) {
        await repository.replaceOrganization(
          planFollowingTopicFolderImport(
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
    return FollowingTopicImportResult(
      importedCount: imported,
      alreadyExistedCount: existing,
      skippedProfileCount: 0,
      resolvedIds: Map.unmodifiable(importedByBackupId),
    );
  }
}

/// Pure construction shared with package change previews. The namespace is a
/// receiver-local storage key, not a saved profile or imported access grant.
FollowingTopic profilelessFollowingTopicForImport({
  required FollowingTopicBackupRecord record,
  required String id,
  required String namespace,
  required DateTime createdAt,
}) {
  if (normalizeSearchIdentity(record.query).isEmpty) {
    throw const FormatException('Followed topic queries cannot be empty.');
  }
  return FollowingTopic(
    id: id,
    profileId: namespace,
    localSource: FollowingTopicSource(
      booruType: record.profile.booruType,
      url: normalizeBackupProfileUrl(record.profile.url),
      importedProfileId: record.profile.id,
      importedProfileName: record.profile.name,
    ),
    query: record.query.trim(),
    queryStructure: record.queryStructure,
    name: record.name,
    position: record.position,
    createdAt: createdAt,
    previews: const [],
    recentPostIdentities: const [],
    unreadCount: 0,
    autoUpdateEnabled: record.autoUpdateEnabled,
  );
}

bool followingTopicMatchesImportSource(
  FollowingTopic topic,
  BackupProfileReference reference,
  String? profileId,
) {
  final source = topic.localSource;
  if (source?.isImported ?? false) {
    return source!.importedProfileId == reference.id &&
        source.matches(
          reference.booruType,
          normalizeBackupProfileUrl(reference.url),
        );
  }
  return profileId != null &&
      topic.profileId == profileId &&
      (source == null ||
          source.matches(
            reference.booruType,
            normalizeBackupProfileUrl(reference.url),
          ));
}

/// Shared by import execution and its review projection. Independent source
/// records get independent destinations, and explicit copies always stay copies.
FollowingTopic? findMatchingTopicForImport({
  required FollowingTopicBackupRecord record,
  required FollowingTopicBackupData data,
  required String? profileId,
  required Iterable<FollowingTopic> searches,
  required TopicOrganization organization,
  required Set<String> usedIds,
  Map<String, CollectionImportAction> folderActions = const {},
  bool restoreHierarchy = false,
  String importFolderName = 'Imported Searches',
}) {
  final incomingTree = FolderTree(
    data.folders.map(
      (folder) => CollectionFolder(
        id: folder.id,
        name: folder.name,
        parentId: folder.parentId,
        position: folder.position,
      ),
    ),
  );
  final incomingFolder =
      data.folders
          .where((folder) => folder.searchIds.contains(record.id))
          .firstOrNull
          ?.id ??
      record.folderId;
  final path =
      incomingFolder != null && incomingTree.byId.containsKey(incomingFolder)
      ? incomingTree.ancestors(incomingFolder)
      : <CollectionFolder>[];
  final copyRequested =
      folderActions[incomingFolder]?.action == ImportAction.copy ||
      path.any(
        (folder) => folderActions[folder.id]?.action == ImportAction.copy,
      );
  if (copyRequested) return null;
  final folderAction = folderActions[incomingFolder];
  final destination = folderAction?.action == ImportAction.mergeIntoTarget
      ? folderAction?.targetId
      : incomingFolder;
  final previousImportPath = data.folders.isEmpty
      ? null
      : [importFolderName, ...path.map((folder) => folder.name)].join(' / ');
  final placements = {
    for (final placement in organization.placements)
      placement.itemId: placement.folderId,
  };
  final matching = searches
      .where(
        (search) =>
            !usedIds.contains(search.id) &&
            placements.containsKey(search.id) &&
            followingTopicMatchesImportSource(
              search,
              record.profile,
              profileId,
            ) &&
            normalizeSearchIdentity(search.query) ==
                normalizeSearchIdentity(record.query) &&
            (restoreHierarchy ||
                search.id == record.id ||
                placements[search.id] == destination ||
                (previousImportPath != null &&
                    organization.tree.path(placements[search.id]) ==
                        previousImportPath)),
      )
      .toList();
  return matching.where((search) => search.id == record.id).firstOrNull ??
      matching.firstOrNull;
}

TopicOrganization planFollowingTopicFolderImport({
  required TopicOrganization current,
  required FollowingTopicBackupData data,
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
    return TopicOrganization(
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
        (() {
          final updated = data.folders.singleWhere((r) => r.id == f.id);
          return f.copyWith(
            name: updated.name,
            feedEnabled: updated.feedEnabled,
            feedMaxPosts: updated.feedMaxPosts,
          );
        })()
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
  final currentById = {
    for (final f in currentFolders) f.id: f,
  };
  final importedById = {for (final f in data.folders) f.id: f};
  final copiedFrom = {
    for (final entry
        in hierarchy?.folderIds.entries ?? const <MapEntry<String, String>>[])
      entry.value: entry.key,
  };
  final organization = TopicOrganization(
    folders: [
      for (final f in folders)
        TopicFolder(
          id: f.id,
          name: f.name,
          parentId: f.parentId,
          position: f.position,
          feedEnabled:
              currentById[f.id]?.feedEnabled ??
              importedById[copiedFrom[f.id]]?.feedEnabled ??
              false,
          feedMaxPosts:
              currentById[f.id]?.feedMaxPosts ??
              importedById[copiedFrom[f.id]]?.feedMaxPosts ??
              topicFeedRetention,
        ),
    ],
    placements: placements,
  );
  organization.tree.validatePlacements(organization.placements);
  return organization;
}

bool followingTopicFolderSkipped(
  FollowingTopicBackupData data,
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
