import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:i18n/i18n.dart';

import '../../../groups/folder_tree.dart';
import '../../sources/following_topic_import_service.dart';
import 'collection_import_action.dart';

import '../../../bookmarks/types.dart';
import '../../../configs/config/types.dart';
import '../../../search/following_topics/types.dart';
import '../../sources/bookmark_backup_data.dart';
import '../../sources/bookmark_import_planner.dart';
import '../../sources/bookmark_unified_import.dart';
import '../../../bookmarks/src/data/stored_bookmark_codec.dart';
import '../../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../sources/topic_feed_backup_data.dart';
import '../../sources/following_topic_backup_data.dart';
import '../../sources/search_backup_profile.dart';
import '../models/import_action.dart';
import 'import_plan.dart';
import 'bookmark_profile_dependency.dart';
import 'import_change_preview.dart';
import 'import_preflight.dart';
import 'profile_dependency_planner.dart';
import 'profile_import_projection.dart';
import '../../../search/following_topics/src/compatibility/topic_storage_contract.dart';

final class BookmarkImportLocalSnapshot {
  BookmarkImportLocalSnapshot({
    Iterable<PostBookmark> bookmarks = const [],
    Iterable<Bookmark>? records,
    required Iterable<BookmarkGroup> groups,
    this.folders = const [],
    this.pools = const [],
  }) : records = records == null ? null : List.unmodifiable(records),
       bookmarks = List.unmodifiable(bookmarks),
       groups = List.unmodifiable(groups);

  final List<Bookmark>? records;
  final List<CollectionBookmark> pools;
  final List<PostBookmark> bookmarks;
  final List<BookmarkGroup> groups;
  final List<CollectionFolder> folders;
}

final class FollowingTopicImportLocalSnapshot {
  FollowingTopicImportLocalSnapshot({
    required Iterable<FollowingTopic> searches,
    required this.organization,
    required Iterable<TopicFeed> feeds,
  }) : searches = List.unmodifiable(searches),
       feeds = List.unmodifiable(feeds);

  final List<FollowingTopic> searches;
  final TopicOrganization organization;
  final List<TopicFeed> feeds;
}

final class TopicFeedImportLocalSnapshot {
  TopicFeedImportLocalSnapshot({
    required Iterable<FollowingTopic> searches,
    required Iterable<TopicFeed> feeds,
  }) : searches = List.unmodifiable(searches),
       feeds = List.unmodifiable(feeds);

  final List<FollowingTopic> searches;
  final List<TopicFeed> feeds;
}

final class ImportPlannedChangeProjector {
  const ImportPlannedChangeProjector();

  PlannedChangeSummary jsonPreview({
    required String sourceId,
    required Object? local,
    required Object? incoming,
    required ResolvedImportSource resolution,
  }) {
    final summary = scalar(
      local: local,
      incoming: incoming,
      resolution: resolution,
    );
    if (!summary.hasMutations) return summary;
    final List<ImportChangePreviewRow> rows;
    if (sourceId == 'settings') {
      Object? unwrap(Object? value) =>
          value is List && value.length == 1 ? value.single : value;
      rows = [
        for (final detail in importFieldChanges(
          unwrap(local),
          unwrap(incoming),
        ))
          ImportChangePreviewRow(
            category: sourceId,
            id: detail.key,
            kind: ImportChangeKind.changed,
            label: detail.key,
            details: [detail],
          ),
      ];
    } else if ((sourceId == 'blacklisted_tags' ||
            sourceId == 'favorite_tags') &&
        local is List &&
        incoming is List) {
      final old = {
        for (final value in local.whereType<Map>())
          value[sourceId == 'favorite_tags' ? 'name' : 'id']: value,
      };
      final next = {
        for (final value in incoming.whereType<Map>())
          value[sourceId == 'favorite_tags' ? 'name' : 'id']: value,
      };
      rows = [
        for (final id in {...old.keys, ...next.keys})
          if (!const DeepCollectionEquality().equals(old[id], next[id]))
            ImportChangePreviewRow(
              category: sourceId,
              id: id.toString(),
              kind: !old.containsKey(id)
                  ? ImportChangeKind.added
                  : !next.containsKey(id)
                  ? ImportChangeKind.removed
                  : ImportChangeKind.changed,
              label: safeImportDisplayValue(
                'name',
                (next[id] ?? old[id])?['name'] ?? id,
              ),
              previousLabel:
                  old[id]?['name'] != next[id]?['name'] &&
                      old.containsKey(id) &&
                      next.containsKey(id)
                  ? safeImportDisplayValue('name', old[id]?['name'])
                  : null,
              details: old.containsKey(id) && next.containsKey(id)
                  ? importFieldChanges(old[id], next[id])
                  : const [],
            ),
      ];
    } else {
      rows = [
        ImportChangePreviewRow(
          category: sourceId,
          id: sourceId,
          kind: ImportChangeKind.changed,
          label: sourceId,
          limit: ['search_histories', 'downloads'].contains(sourceId)
              ? ImportPreviewLimit.database
              : ImportPreviewLimit.unknown,
        ),
      ];
    }
    return PlannedChangeSummary(
      created: summary.created,
      updated: summary.updated,
      deleted: summary.deleted,
      unchanged: summary.unchanged,
      preserved: summary.preserved,
      previewRows: List.unmodifiable(
        rows.isEmpty
            ? [
                ImportChangePreviewRow(
                  category: sourceId,
                  id: sourceId,
                  kind: ImportChangeKind.changed,
                  label: sourceId,
                  limit: ImportPreviewLimit.unknown,
                ),
              ]
            : rows,
      ),
    );
  }

  PlannedChangeSummary scalar({
    required Object? local,
    required Object? incoming,
    required ResolvedImportSource resolution,
  }) {
    if (resolution.action == ImportAction.skip) {
      return const PlannedChangeSummary(preserved: 1);
    }
    return const DeepCollectionEquality().equals(local, incoming)
        ? const PlannedChangeSummary(unchanged: 1)
        : const PlannedChangeSummary(updated: 1);
  }

  PlannedChangeSummary? profiles({
    required List<BooruConfig> local,
    required List<BooruConfig> imported,
    required ResolvedImportSource resolution,
    required bool credentialsIncluded,
    List<BooruConfig> additionalProfiles = const [],
    Map<String, String> copyIds = const {},
  }) {
    final localEntities = <Object, Object?>{
      for (final profile in local) _key('profile', profile.id): profile,
    };
    if (resolution.action == ImportAction.skip) {
      return PlannedChangeSummary(preserved: localEntities.length);
    }
    final ProfileImportProjection projection;
    try {
      projection = const ProfileImportProjector().project(
        imported: imported,
        local: local,
        resolution: resolution,
        credentialsIncluded: credentialsIncluded,
        copyIds: copyIds,
      );
    } on UnresolvedProfileImportException {
      return null;
    } on ConflictingProfileIdentityException {
      return null;
    }
    final projected = projection.profiles.toList();
    final usedIds = projected.map((profile) => profile.id).toSet();
    for (final profile in additionalProfiles) {
      if (!usedIds.add(profile.id)) {
        throw StateError('Created profile ID is no longer available');
      }
      projected.add(profile);
    }
    final touched = <Object>{};
    if (resolution.action == ImportAction.replace) {
      touched.addAll(localEntities.keys);
      touched.addAll(projected.map((profile) => _key('profile', profile.id)));
    } else {
      for (final item in resolution.items) {
        if (item.action == ImportAction.skip) continue;
        final importedId = _idWithoutPrefix(item.id, 'profile:');
        final destinationId = switch (item.targetId) {
          final target? => _idWithoutPrefix(target, 'profile:'),
          null => importedId,
        };
        final projectedId = importedId;
        final actualId =
            projection.destinationIds[projectedId] ?? destinationId;
        touched.add(_key('profile', actualId));
      }
      touched.addAll(
        additionalProfiles.map((profile) => _key('profile', profile.id)),
      );
    }
    return _summarize(
      local: localEntities,
      projected: {
        for (final profile in projected) _key('profile', profile.id): profile,
      },
      touched: touched,
    );
  }

  PlannedChangeSummary? bookmarks({
    required BookmarkImportLocalSnapshot local,
    required BookmarkBackupData incoming,
    required ResolvedImportSource resolution,
    Map<ProfileReferenceKey, String> profileMappings = const {},
    StoredBookmarkCodec recordCodec = const StoredBookmarkCodec(),
  }) {
    final localData =
        (local.records == null
                ? BookmarkBackupData(
                    bookmarks: local.bookmarks,
                    pools: local.pools,
                    folders: local.folders,
                    groups: [
                      for (final g in local.groups)
                        BookmarkGroupBackup(
                          id: g.id,
                          name: g.name,
                          bookmarkIds: g.bookmarkIds.toList(),
                          addedAt: g.addedAt,
                          folderId: g.folderId,
                          parentGroupId: g.parentGroupId,
                          position: g.position,
                        ),
                    ],
                  )
                : BookmarkBackupData.unified(
                    records: local.records!,
                    folders: local.folders,
                    groups: [
                      for (final g in local.groups)
                        BookmarkGroupBackup(
                          id: g.id,
                          name: g.name,
                          bookmarkIds: g.bookmarkIds.toList(),
                          addedAt: g.addedAt,
                          folderId: g.folderId,
                          parentGroupId: g.parentGroupId,
                          position: g.position,
                        ),
                    ],
                  ))
            .asHierarchy();
    final localGroups = [
      for (final g in localData.groups)
        BookmarkGroup(
          id: g.id!,
          name: g.name,
          bookmarkIds: g.bookmarkIds.toSet(),
          addedAt: g.addedAt,
          folderId: g.folderId,
          parentGroupId: g.parentGroupId,
          position: g.position,
        ),
    ];
    final assigned = {for (final g in localGroups) ...g.bookmarkIds};
    final unassigned = localData.records
        .where((r) => !assigned.contains(r.id))
        .toList();
    final defaultIndex = localGroups.indexWhere((g) => g.isDefault);
    final oldDefault = defaultIndex < 0 ? null : localGroups[defaultIndex];
    final repairedDefault = BookmarkGroup(
      id: defaultBookmarkGroupId,
      name: 'Default',
      bookmarkIds: {
        ...?oldDefault?.bookmarkIds,
        ...unassigned.map((r) => r.id),
      },
      addedAt: {
        ...?oldDefault?.addedAt,
        for (final r in unassigned) r.id: bookmarkCreatedAt(r),
      },
      position: oldDefault?.position ?? 0,
    );
    if (defaultIndex < 0) {
      localGroups.add(repairedDefault);
    } else {
      localGroups[defaultIndex] = repairedDefault;
    }
    Map<Object, Object?> entities(
      List<Bookmark> records,
      List<BookmarkGroup> groups,
      List<CollectionFolder> folders,
    ) {
      final recordsById = {for (final r in records) r.id: r};
      final keys = {
        for (final r in records)
          r.id: bookmarkContentIdentity(r) ?? ('local', r.id),
      };
      return {
        for (final r in records)
          _key('bookmark', keys[r.id]!): _BookmarkValue.from(
            r,
            codec: recordCodec,
          ),
        for (final f in folders) _key('bookmark-folder', f.id): f,
        for (final g in groups)
          _key('bookmark-group', g.id): _BookmarkGroupValue(
            name: g.name,
            bookmarkIds: {for (final id in g.bookmarkIds) keys[id]!},
            addedAt: {
              for (final id in g.bookmarkIds)
                keys[id]!: g.addedAt[id] ?? bookmarkCreatedAt(recordsById[id]!),
            },
            folderId: g.folderId,
            parentGroupId: g.parentGroupId,
            position: g.position,
          ),
      };
    }

    final localEntities = entities(
      localData.records,
      localGroups,
      localData.folders,
    );
    if (resolution.action == ImportAction.skip)
      return PlannedChangeSummary(preserved: localEntities.length);
    final mapped = <int, Bookmark>{};
    for (final r in selectedProfileRecords(incoming, resolution)) {
      final hint =
          profileMappings[ProfileReferenceKey.fromReference(
            bookmarkRecordProfileReference(r),
          )];
      if (hint != null) mapped[r.id] = bookmarkRecordWithProfileHint(r, hint);
    }
    final data = BookmarkBackupData.unified(
      records: [for (final r in incoming.records) mapped[r.id] ?? r],
      groups: incoming.groups,
      folders: incoming.folders,
    );
    final actions = {for (final item in resolution.items) item.id: item};
    final allGrouped = {for (final g in data.groups) ...g.bookmarkIds};
    final ungrouped = actions['ungrouped']?.action;
    final chosenGroups = [
      for (final g in data.groups)
        if (resolution.action == ImportAction.replace ||
            actions['group:${g.id}']?.action != ImportAction.skip)
          g,
    ];
    final chosenIds = {
      for (final g in chosenGroups) ...g.bookmarkIds,
      if (resolution.action == ImportAction.replace ||
          (ungrouped != null && ungrouped != ImportAction.skip))
        ...data.records.map((r) => r.id).toSet().difference(allGrouped),
    };
    final selected = BookmarkBackupData.unified(
      records: data.records.where(
        (r) => allGrouped.contains(r.id) || chosenIds.contains(r.id),
      ),
      groups: data.groups,
      folders: data.folders,
    );
    final plan = const BookmarkImportPlanner().plan(
      data: selected,
      currentBookmarks: localData.records,
      currentGroups: localGroups,
    );
    var serial = 0;
    String newId() =>
        'ffffffff-ffff-4fff-8fff-${(++serial).toString().padLeft(12, '0')}';
    final resolved = plan.resolveActions({
      for (final g in plan.groups)
        g.id: g.resolveAction(
          resolution.action == ImportAction.replace
              ? ImportAction.replace
              : actions['group:${g.id}']?.action ??
                    (g.conflicts ? ImportAction.update : ImportAction.copy),
          targetId: actions['group:${g.id}']?.targetId?.replaceFirst(
            'group:',
            '',
          ),
          destinationId:
              actions['group:${g.id}']?.action == ImportAction.copy &&
                  g.conflicts
              ? newId()
              : g.id,
        ),
    });
    if (resolved.groups.any(
      (g) =>
          g.resolvedAction == ImportAction.mergeIntoTarget &&
          (g.targetId == null ||
              !localGroups.any((local) => local.id == g.targetId)),
    )) {
      return null;
    }
    final removeIds = <int>{};
    if (ungrouped == ImportAction.update) {
      final grouped = {for (final g in localGroups) ...g.bookmarkIds};
      final incomingKeys = {
        for (final r in selected.records)
          if (!allGrouped.contains(r.id)) ?bookmarkContentIdentity(r),
      };
      removeIds.addAll(
        localData.records
            .where(
              (r) =>
                  !grouped.contains(r.id) &&
                  !incomingKeys.contains(bookmarkContentIdentity(r)),
            )
            .map((r) => r.id),
      );
    }
    final prepared = BookmarkImportPreparation.prepare(
      plan: resolved,
      currentRecords: localData.records,
      currentGroups: localGroups,
      currentFolders: localData.folders,
      normalize: (r, {previous}) => r,
      replace: resolution.action == ImportAction.replace,
      removeIds: removeIds,
      importFolderName: Translations().folders.imported_groups,
      newId: newId,
    );
    final write = prepared.materialize(prepared.newIds);
    final resultRecords = <int, Bookmark>{
      if (resolution.action != ImportAction.replace)
        for (final r in localData.records)
          if (!write.removeIds.contains(r.id)) r.id: r,
      for (final r in write.records) r.id: r,
    };
    final projected = entities(
      resultRecords.values.toList(),
      write.groups,
      write.folders,
    );
    return _summarize(
      local: localEntities,
      projected: projected,
      touched: {...localEntities.keys, ...projected.keys},
    );
  }

  PlannedChangeSummary? followingTopics({
    required FollowingTopicImportLocalSnapshot local,
    required FollowingTopicBackupData incoming,
    required ResolvedImportSource resolution,
    required Map<ProfileReferenceKey, String> profileMappings,
  }) {
    final folderIds = local.organization.folders
        .map((folder) => folder.id)
        .toSet();
    final internalIds = {
      for (final feed in local.feeds)
        if (!folderIds.contains(feed.id)) ...feed.sourceIds,
    };
    final localSearches = {
      for (final search in local.searches)
        if (!internalIds.contains(search.id)) search.id: search,
    };
    final localFolders = local.organization.folders;
    final localEntities = <Object, Object?>{
      for (final entry in localSearches.entries)
        _key('following-topic', entry.key): _SearchValue.from(entry.value),
      for (final folder in localFolders)
        _key('topic-folder', folder.id): _FolderValue.from(folder),
      _key('topics-home', 'home'): _HomeValue(
        local.organization.homeSearchIds,
      ),
    };
    if (resolution.action == ImportAction.skip) {
      return PlannedChangeSummary(preserved: localEntities.length);
    }

    final items = {for (final item in resolution.items) item.id: item};
    final requiresUnmappedProfile = incoming.records.any(
      (record) =>
          (resolution.action == ImportAction.replace ||
              items['search:${record.id}']?.action != ImportAction.skip) &&
          !profileMappings.containsKey(
            ProfileReferenceKey.fromReference(record.profile),
          ),
    );
    if (requiresUnmappedProfile) return null;

    final searches = <String, FollowingTopic>{
      for (final search in local.searches) search.id: search,
    };
    var folders = localFolders.toList();
    var home = local.organization.homeSearchIds.toList();
    if (resolution.action == ImportAction.replace) {
      folders = [];
      home = home.where(internalIds.contains).toList();
    }
    final importedByBackupId = <String, String>{};
    final touched = <Object>{};
    final createdIds = <String>[];
    final orderedRecords = incoming.records.indexed.toList()
      ..sort((left, right) {
        final position = left.$2.position.compareTo(right.$2.position);
        return position != 0 ? position : left.$1.compareTo(right.$1);
      });
    for (final (_, record) in orderedRecords) {
      if (resolution.action != ImportAction.replace &&
          (items['search:${record.id}']?.action == ImportAction.skip ||
              followingTopicFolderSkipped(incoming, record.id, {
                for (final item in resolution.items)
                  if (item.id.startsWith('folder:'))
                    item.id.substring(7): CollectionImportAction(
                      itemId: item.id.substring(7),
                      action: item.action,
                    ),
              }))) {
        continue;
      }
      final profileId = _profileId(record.profile, profileMappings);
      final saved = findMatchingTopicForImport(
        record: record,
        data: incoming,
        profileId: profileId,
        searches: searches.values.where(
          (search) => !internalIds.contains(search.id),
        ),
        organization: local.organization,
        usedIds: importedByBackupId.values.toSet(),
        restoreHierarchy: resolution.action == ImportAction.replace,
        folderActions: {
          for (final item in resolution.items)
            if (item.id.startsWith('folder:'))
              item.id.substring(7): CollectionImportAction(
                itemId: item.id.substring(7),
                action: item.action,
                targetId: _optionalIdWithoutPrefix(item.targetId, 'folder:'),
              ),
        },
        importFolderName: Translations().folders.imported_searches,
      );
      if (saved != null) {
        importedByBackupId[record.id] = saved.id;
        touched.add(_key('following-topic', saved.id));
        continue;
      }
      final id = searches.containsKey(record.id)
          ? '__created__pinned-${record.id}'
          : record.id;
      final created = FollowingTopic.create(
        id: id,
        profileId: profileId,
        query: record.query,
        name: record.name,
        position: searches.values
            .where(
              (search) =>
                  search.profileId == profileId &&
                  !internalIds.contains(search.id),
            )
            .length,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
      searches[id] = created;
      importedByBackupId[record.id] = id;
      createdIds.add(id);
      touched.add(_key('following-topic', id));
    }

    if (resolution.action == ImportAction.replace) {
      final retainedIds = importedByBackupId.values.toSet();
      searches.removeWhere(
        (id, _) => !internalIds.contains(id) && !retainedIds.contains(id),
      );
      final assigned = <String>{};
      List<String> mapped(Iterable<String> ids) => [
        for (final id in ids)
          if (importedByBackupId[id] case final mapped?)
            if (assigned.add(mapped)) mapped,
      ];
      home = [
        ...home,
        ...mapped(incoming.homeSearchIds),
      ];
      folders = [
        for (final record
            in incoming.folders.toList()
              ..sort((left, right) => left.position.compareTo(right.position)))
          TopicFolder(
            id: record.id,
            name: record.name,
            parentId: record.parentId,
            position: record.position,
            searchIds: mapped(record.searchIds),
            feedEnabled: record.feedEnabled,
            feedMaxPosts: record.feedMaxPosts,
          ),
      ];
    } else {
      final folderActions = {
        for (final item in resolution.items)
          if (item.id.startsWith('folder:'))
            item.id.substring(7): CollectionImportAction(
              itemId: item.id.substring(7),
              action: item.action,
              targetId: _optionalIdWithoutPrefix(item.targetId, 'folder:'),
            ),
      };
      var nextFolderId = 0;
      final organization = planFollowingTopicFolderImport(
        current: local.organization,
        data: incoming,
        importedByBackupId: importedByBackupId,
        createdIds: createdIds.toSet(),
        folderActions: folderActions,
        wrapperName: Translations().folders.imported_searches,
        newId: () => '__created__search-folder-${nextFolderId++}',
      );
      folders = organization.folders;
      home = organization.homeSearchIds;
    }
    for (final folder in folders) {
      if (localFolders.any((value) => value.id == folder.id) ||
          incoming.folders.any((value) => value.id == folder.id)) {
        touched.add(_key('topic-folder', folder.id));
      }
    }
    final projectedSearches = {
      for (final entry in searches.entries)
        if (!internalIds.contains(entry.key)) entry.key: entry.value,
    };
    return _summarize(
      local: localEntities,
      projected: {
        for (final entry in projectedSearches.entries)
          _key('following-topic', entry.key): _SearchValue.from(
            entry.value,
            autoUpdateEnabled:
                resolution.action == ImportAction.replace ||
                    createdIds.contains(entry.key)
                ? incoming.records
                      .where(
                        (record) => importedByBackupId[record.id] == entry.key,
                      )
                      .firstOrNull
                      ?.autoUpdateEnabled
                : null,
          ),
        for (final folder in folders)
          _key('topic-folder', folder.id): _FolderValue.from(folder),
        _key('topics-home', 'home'): _HomeValue(home),
      },
      touched: resolution.action == ImportAction.replace
          ? {...localEntities.keys, ...touched}
          : touched,
    );
  }

  PlannedChangeSummary? topicFeeds({
    required TopicFeedImportLocalSnapshot local,
    required TopicFeedBackupData incoming,
    required ResolvedImportSource resolution,
    required Map<ProfileReferenceKey, String> profileMappings,
  }) {
    final originalInternalIds = {
      for (final feed in local.feeds) ...feed.sourceIds,
    };
    final localSearchById = {
      for (final search in local.searches) search.id: search,
    };
    final localEntities = <Object, Object?>{
      for (final feed in local.feeds)
        _key('feed', feed.id): _FeedValue.from(feed, localSearchById),
      for (final id in originalInternalIds)
        if (localSearchById[id] case final search?)
          _key('feed-search', id): _SearchValue.from(search),
    };
    if (resolution.action == ImportAction.skip) {
      return PlannedChangeSummary(preserved: localEntities.length);
    }

    final searches = Map.of(localSearchById);
    final feeds = {for (final feed in local.feeds) feed.id: feed};
    final touched = <Object>{};
    final items = {for (final item in resolution.items) item.id: item};
    final requiresUnmappedProfile = incoming.feeds.any((record) {
      final item = items['feed:${record.id}'];
      return (resolution.action == ImportAction.replace ||
              (item != null && item.action != ImportAction.skip)) &&
          !profileMappings.containsKey(
            ProfileReferenceKey.fromReference(record.profile),
          );
    });
    if (requiresUnmappedProfile) return null;
    final desired =
        <({int index, String profileId, TopicFeedBackupRecord record})>[];
    for (final (index, record) in incoming.feeds.indexed) {
      if (resolution.action == ImportAction.replace) {
        final profileId = _profileId(record.profile, profileMappings);
        final local = feeds[record.id];
        if (local != null && local.profileId != profileId) {
          _deleteFeed(record.id, feeds: feeds, searches: searches);
        }
        desired.add((index: index, profileId: profileId, record: record));
        continue;
      }
      final item = items['feed:${record.id}'];
      if (item == null || item.action == ImportAction.skip) continue;
      final profileId = _profileId(record.profile, profileMappings);
      final targetId = switch (item.action) {
        ImportAction.mergeIntoTarget => _optionalIdWithoutPrefix(
          item.targetId,
          'feed:',
        ),
        ImportAction.copy when feeds.containsKey(record.id) =>
          '__copy__feed-${record.id}-$index',
        _ => record.id,
      };
      if (targetId == null) throw StateError('Feed target is unresolved');
      final existing = feeds[targetId];
      final merge =
          item.action == ImportAction.merge ||
          item.action == ImportAction.mergeIntoTarget;
      final queries = merge
          ? _orderedQueryUnion(
              [
                for (final sourceId in existing?.sourceIds ?? const <String>[])
                  if (searches[sourceId] case final source?) source.query,
              ],
              record.queries,
            )
          : record.queries;
      desired.add((
        index: index,
        profileId: profileId,
        record: TopicFeedBackupRecord(
          id: targetId,
          name: merge ? existing!.name : record.name,
          position: merge ? existing!.position : record.position,
          queries: queries,
          profile: BackupProfileReference(
            id: profileId,
            booruType: record.profile.booruType,
            url: record.profile.url,
            name: record.profile.name,
          ),
        ),
      ));
    }

    final profileIds = <String>{};
    for (final item in desired) {
      profileIds.add(item.profileId);
    }
    final finalOrder = <String, List<String>>{};
    for (final profileId in profileIds) {
      final rows =
          desired
              .where(
                (item) => item.profileId == profileId,
              )
              .toList()
            ..sort((left, right) {
              final position = left.record.position.compareTo(
                right.record.position,
              );
              return position != 0
                  ? position
                  : left.index.compareTo(right.index);
            });
      final importedIds = rows.map((item) => item.record.id).toSet();
      final order = [
        for (final feed in feeds.values)
          if (feed.profileId == profileId && !importedIds.contains(feed.id))
            feed.id,
      ];
      var previousPosition = -1;
      var equalPositionOffset = 0;
      for (final row in rows) {
        equalPositionOffset = row.record.position == previousPosition
            ? equalPositionOffset + 1
            : 0;
        previousPosition = row.record.position;
        order.insert(
          (row.record.position + equalPositionOffset).clamp(0, order.length),
          row.record.id,
        );
      }
      finalOrder[profileId] = order;
    }
    for (final item in desired) {
      final retainedIds = _saveFeed(
        record: item.record,
        profileId: item.profileId,
        feeds: feeds,
        searches: searches,
      );
      touched.add(_key('feed', item.record.id));
      touched.addAll(retainedIds.map((id) => _key('feed-search', id)));
    }
    if (resolution.action == ImportAction.replace) {
      final desiredIds = desired.map((item) => item.record.id).toSet();
      for (final id in feeds.keys.toList()) {
        if (!desiredIds.contains(id)) {
          _deleteFeed(id, feeds: feeds, searches: searches);
        }
      }
    }
    for (final entry in finalOrder.entries) {
      for (final (position, id) in entry.value.indexed) {
        final feed = feeds[id];
        if (feed != null) feeds[id] = feed.copyWith(position: position);
      }
    }

    final finalInternalIds = {
      for (final feed in feeds.values) ...feed.sourceIds,
    };
    final projected = <Object, Object?>{
      for (final feed in feeds.values)
        _key('feed', feed.id): _FeedValue.from(feed, searches),
      for (final id in finalInternalIds)
        if (searches[id] case final search?)
          _key('feed-search', id): _SearchValue.from(search),
    };
    return _summarize(
      local: localEntities,
      projected: projected,
      touched: resolution.action == ImportAction.replace
          ? {...localEntities.keys, ...projected.keys}
          : touched,
    );
  }
}

Set<String> _saveFeed({
  required TopicFeedBackupRecord record,
  required String profileId,
  required Map<String, TopicFeed> feeds,
  required Map<String, FollowingTopic> searches,
}) {
  final normalized = <String>[];
  final seen = <String>{};
  for (final query in record.queries) {
    final value = normalizeSearchIdentity(query);
    if (value.isNotEmpty && seen.add(value)) normalized.add(value);
  }
  final previous = feeds[record.id];
  final internalIds = {for (final feed in feeds.values) ...feed.sourceIds};
  final internalByQuery = <String, FollowingTopic>{
    for (final search in searches.values)
      if (internalIds.contains(search.id) && search.profileId == profileId)
        normalizeSearchIdentity(search.query): search,
  };
  final retained = <FollowingTopic>[];
  for (final (position, query) in normalized.indexed) {
    final existing = internalByQuery[query];
    retained.add(
      existing ??
          FollowingTopic.create(
            id: '__created__feed-search-$profileId-${record.id}-$position',
            profileId: profileId,
            query: query,
            name: null,
            position: position,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
    );
  }
  for (final search in retained) {
    searches.putIfAbsent(search.id, () => search);
  }
  final retainedIds = retained.map((source) => source.id).toSet();
  final removedIds = previous?.sourceIds.toSet().difference(retainedIds) ?? {};
  final otherIds = {
    for (final feed in feeds.values)
      if (feed.id != record.id) ...feed.sourceIds,
  };
  removedIds.difference(otherIds).forEach(searches.remove);
  feeds[record.id] = TopicFeed(
    id: record.id,
    profileId: profileId,
    name: record.name,
    position:
        previous?.position ??
        feeds.values.where((feed) => feed.profileId == profileId).length,
    sourceIds: retained.map((source) => source.id).toList(),
  );
  return retainedIds;
}

void _deleteFeed(
  String id, {
  required Map<String, TopicFeed> feeds,
  required Map<String, FollowingTopic> searches,
}) {
  final feed = feeds.remove(id);
  if (feed == null) return;
  final referencedElsewhere = {
    for (final other in feeds.values) ...other.sourceIds,
  };
  feed.sourceIds
      .toSet()
      .difference(referencedElsewhere)
      .forEach(
        searches.remove,
      );
}

String _profileId(
  BackupProfileReference reference,
  Map<ProfileReferenceKey, String> mappings,
) {
  final id = mappings[ProfileReferenceKey.fromReference(reference)];
  if (id == null) throw StateError('Profile mapping is unresolved');
  return id;
}

// Global bookmark creation dates are compatibility metadata. Membership dates
// carry ordering semantics and must still participate in import comparisons.
bool _sameProjectedEntity(Object? before, Object? after) {
  if (identical(before, after)) return true;
  if (before is _BookmarkGroupValue && after is _BookmarkGroupValue) {
    // Equatable compares sets with nested scans. A populated default group can
    // contain the entire library; use its hash-based identity lookup instead.
    return before.name == after.name &&
        before.folderId == after.folderId &&
        before.parentGroupId == after.parentGroupId &&
        before.position == after.position &&
        const SetEquality<Object>().equals(
          before.bookmarkIds,
          after.bookmarkIds,
        ) &&
        const SetEquality<Object>().equals(before.poolIds, after.poolIds) &&
        const MapEquality<Object, DateTime>().equals(
          before.addedAt,
          after.addedAt,
        );
  }
  if (before is CollectionBookmark && after is CollectionBookmark) {
    return const DeepCollectionEquality().equals(
      before.toJson()..remove('createdAt'),
      after.toJson()..remove('createdAt'),
    );
  }
  return before == after;
}

PlannedChangeSummary _summarize({
  required Map<Object, Object?> local,
  required Map<Object, Object?> projected,
  required Set<Object> touched,
}) {
  var created = 0;
  var updated = 0;
  var deleted = 0;
  var preserved = 0;
  var unchanged = 0;
  final entitySummaries = <String, PlannedChangeSummary>{};
  final keys = {...local.keys, ...projected.keys};
  for (final key in keys) {
    final hadLocal = local.containsKey(key);
    final hasProjected = projected.containsKey(key);
    final PlannedChangeSummary change;
    if (!hadLocal) {
      created++;
      change = const PlannedChangeSummary(created: 1);
    } else if (!hasProjected) {
      deleted++;
      change = const PlannedChangeSummary(deleted: 1);
    } else if (!_sameProjectedEntity(local[key], projected[key])) {
      updated++;
      change = const PlannedChangeSummary(updated: 1);
    } else if (touched.contains(key)) {
      unchanged++;
      change = const PlannedChangeSummary(unchanged: 1);
    } else {
      preserved++;
      change = const PlannedChangeSummary(preserved: 1);
    }
    final type = (key as _EntityKey).type;
    entitySummaries[type] =
        (entitySummaries[type] ?? const PlannedChangeSummary()) + change;
  }
  return PlannedChangeSummary(
    created: created,
    updated: updated,
    deleted: deleted,
    preserved: preserved,
    unchanged: unchanged,
    entitySummaries: Map.unmodifiable(entitySummaries),
    previewRows: _previewRows(local, projected),
  );
}

List<ImportChangePreviewRow> _previewRows(
  Map<Object, Object?> local,
  Map<Object, Object?> projected,
) {
  final rows = <ImportChangePreviewRow>[];
  var metadataChanges = 0;
  for (final key in {...local.keys, ...projected.keys}.cast<_EntityKey>()) {
    final before = local[key], after = projected[key];
    if (_sameProjectedEntity(before, after)) continue;
    final kind = before == null
        ? ImportChangeKind.added
        : after == null
        ? ImportChangeKind.removed
        : ImportChangeKind.changed;
    final value = after ?? before;
    switch (value) {
      case final _BookmarkGroupValue group:
        final old = before as _BookmarkGroupValue?,
            next = after as _BookmarkGroupValue?;
        final oldMembers = <Object>{
              ...?old?.bookmarkIds,
              for (final id in old?.poolIds ?? <Object>{}) ('pool', id),
            },
            nextMembers = <Object>{
              ...?next?.bookmarkIds,
              for (final id in next?.poolIds ?? <Object>{}) ('pool', id),
            };
        rows.add(
          ImportChangePreviewRow(
            category: 'bookmarks',
            id: key.id.toString(),
            kind: kind,
            label: safeImportDisplayValue('name', group.name),
            previousLabel: old != null && next != null && old.name != next.name
                ? safeImportDisplayValue('name', old.name)
                : null,
            membershipsAdded: nextMembers.difference(oldMembers).length,
            membershipsRemoved: oldMembers.difference(nextMembers).length,
            entityChanged:
                old == null ||
                next == null ||
                old.name != next.name ||
                old.folderId != next.folderId ||
                old.position != next.position,
          ),
        );
      case final CollectionFolder folder:
        rows.add(
          ImportChangePreviewRow(
            category: 'bookmarks',
            id: key.id.toString(),
            kind: kind,
            label: safeImportDisplayValue('name', folder.name),
            isContainer: true,
            entityChanged: true,
          ),
        );
      case final CollectionBookmark _:
        if (before is CollectionBookmark && after is CollectionBookmark) {
          Map<String, Object?> metadata(CollectionBookmark pool) =>
              pool.toJson()
                ..remove('createdAt')
                ..remove('groupIds')
                ..remove('localId');
          if (!const DeepCollectionEquality().equals(
            metadata(before),
            metadata(after),
          ))
            metadataChanges++;
        }
      case final _BookmarkValue _:
        if (before != null && after != null) metadataChanges++;
      case _SearchValue() || _FolderValue() || _HomeValue():
        // Pins are emitted inside their folders, including unchanged containers.
        break;
      case final _FeedValue feed:
        rows.add(
          ImportChangePreviewRow(
            category: topicFeedsBackupSourceId,
            entityChanged:
                before is! _FeedValue ||
                after is! _FeedValue ||
                before.name != after.name ||
                before.position != after.position ||
                before.profileId != after.profileId,
            isContainer: true,
            children: _feedQueryRows(
              before as _FeedValue?,
              after as _FeedValue?,
            ),
            id: key.id.toString(),
            kind: kind,
            label: safeImportDisplayValue('name', feed.name),
            previousLabel:
                before is _FeedValue &&
                    after is _FeedValue &&
                    before.name != after.name
                ? safeImportDisplayValue('name', before.name)
                : null,
            profileId: feed.profileId,
            details: [
              if (before is _FeedValue && after is _FeedValue)
                ...importFieldChanges(
                  {'position': before.position, 'profileId': before.profileId},
                  {'position': after.position, 'profileId': after.profileId},
                ),
              ...importQueryChanges(
                before is _FeedValue ? before.queries : [],
                after is _FeedValue ? after.queries : [],
              ).where(
                (detail) =>
                    detail.presentation == ImportDetailPresentation.queryOrder,
              ),
            ],
          ),
        );
      case final BooruConfig profile:
        rows.add(
          ImportChangePreviewRow(
            category: 'profiles',
            id: key.id.toString(),
            kind: kind,
            label: safeImportDisplayValue('name', profile.name),
            previousLabel:
                before is BooruConfig &&
                    after is BooruConfig &&
                    before.name != after.name
                ? safeImportDisplayValue('name', before.name)
                : null,
            profileId: profile.id,
            details: _profileFieldChanges(
              before is BooruConfig ? before : null,
              after is BooruConfig ? after : null,
            ),
          ),
        );
      default:
        // Internal feed searches are explained by their owning feed's details.
        break;
    }
  }
  rows.addAll(_pinnedPreviewRows(local, projected));
  if (local.keys.cast<_EntityKey>().any((key) => key.type == 'bookmark') ||
      projected.keys.cast<_EntityKey>().any((key) => key.type == 'bookmark')) {
    Set<Object> ungrouped(Map<Object, Object?> values) {
      final grouped = {
        for (final group in values.values.whereType<_BookmarkGroupValue>())
          ...group.bookmarkIds,
      };
      return {
        for (final key in values.keys.cast<_EntityKey>())
          if (key.type == 'bookmark' && !grouped.contains(key.id)) key.id,
      };
    }

    final old = ungrouped(local), next = ungrouped(projected);
    final added = next.difference(old).length,
        removed = old.difference(next).length;
    if (added + removed > 0)
      rows.add(
        ImportChangePreviewRow(
          category: 'bookmarks',
          id: 'ungrouped',
          kind: ImportChangeKind.changed,
          label: '__ungrouped',
          membershipsAdded: added,
          membershipsRemoved: removed,
          entityChanged: false,
        ),
      );
  }
  if (metadataChanges > 0)
    rows.add(
      ImportChangePreviewRow(
        category: 'bookmark_metadata',
        id: 'metadata',
        kind: ImportChangeKind.changed,
        label: '__bookmark_metadata',
        limit: ImportPreviewLimit.bookmarkMetadata,
        countOverride: ImportChangeCounts(changed: metadataChanges),
      ),
    );
  return List.unmodifiable(rows);
}

List<ImportChangePreviewRow> _feedQueryRows(
  _FeedValue? before,
  _FeedValue? after,
) {
  final oldQueries = before?.queries ?? <String>[];
  final newQueries = after?.queries ?? <String>[];
  // Compare retained entries so inserting a query does not fabricate reorder changes.
  final oldCommon = oldQueries.where(newQueries.contains).toList();
  final newCommon = newQueries.where(oldQueries.contains).toList();
  return [
    for (final (index, detail) in importQueryChanges(
      before?.queries ?? [],
      after?.queries ?? [],
    ).indexed)
      if (detail.presentation == ImportDetailPresentation.query)
        ImportChangePreviewRow(
          category: 'feed_queries',
          id: '$index',
          kind: detail.kind,
          label: detail.kind == ImportChangeKind.removed
              ? detail.before
              : detail.after,
          profileId: detail.kind == ImportChangeKind.removed
              ? before?.profileId
              : after?.profileId,
        ),
    for (final query in newCommon)
      if (oldCommon.indexOf(query) != newCommon.indexOf(query) ||
          before?.profileId != after?.profileId)
        ImportChangePreviewRow(
          category: 'feed_queries',
          id: 'changed-${newCommon.indexOf(query)}',
          kind: ImportChangeKind.changed,
          label: safeImportDisplayValue('query', query),
          profileId: after?.profileId,
          details: importFieldChanges(
            {
              'position': oldQueries.indexOf(query),
              'profileId': before?.profileId,
            },
            {
              'position': newQueries.indexOf(query),
              'profileId': after?.profileId,
            },
          ),
        ),
  ];
}

List<ImportChangePreviewRow> _pinnedPreviewRows(
  Map<Object, Object?> local,
  Map<Object, Object?> projected,
) {
  Map<_EntityKey, List<String>> containers(Map<Object, Object?> values) {
    final folders = <_EntityKey, List<String>>{
      for (final key in values.keys.cast<_EntityKey>())
        if (key.type == 'topic-folder')
          if (values[key] case final _FolderValue folder) key: folder.searchIds,
    };
    final assigned = folders.values.expand((ids) => ids).toSet();
    final home = values[_key('topics-home', 'home')] as _HomeValue?;
    folders[_key('topics-home', 'home')] = [
      for (final id in home?.searchIds ?? <String>[])
        if (!assigned.contains(id)) id,
      // Legacy topics without an organization entry still belong under Home.
      for (final key in values.keys.cast<_EntityKey>())
        if (key.type == 'following-topic' &&
            !assigned.contains(key.id) &&
            !(home?.searchIds.contains(key.id) ?? false))
          key.id.toString(),
    ];
    return folders;
  }

  final oldContainers = containers(local);
  final newContainers = containers(projected);
  final rows = <ImportChangePreviewRow>[];
  for (final key in {...newContainers.keys, ...oldContainers.keys}) {
    final id = key.type == 'topics-home' ? 'home' : 'folder:${key.id}';
    final isHome = key.type == 'topics-home';
    final before = local[key];
    final after = projected[key];
    final oldIds = oldContainers[key] ?? [];
    final newIds = newContainers[key] ?? [];
    final oldCommon = oldIds.where(newIds.contains).toList();
    final newCommon = newIds.where(oldIds.contains).toList();
    final children = <ImportChangePreviewRow>[];
    for (final searchId in {...newIds, ...oldIds}) {
      final oldSearch =
          local[_key('following-topic', searchId)] as _SearchValue?;
      final newSearch =
          projected[_key('following-topic', searchId)] as _SearchValue?;
      final wasHere = oldIds.contains(searchId) && oldSearch != null;
      final isHere = newIds.contains(searchId) && newSearch != null;
      final reordered =
          wasHere &&
          isHere &&
          oldCommon.indexOf(searchId) != newCommon.indexOf(searchId);
      if ((!wasHere && !isHere) ||
          (wasHere && isHere && oldSearch == newSearch && !reordered)) {
        continue;
      }
      final kind = !wasHere
          ? ImportChangeKind.added
          : !isHere
          ? ImportChangeKind.removed
          : ImportChangeKind.changed;
      final search = isHere ? newSearch : oldSearch!;
      children.add(
        ImportChangePreviewRow(
          category: followingTopicsBackupSourceId,
          id: '$id/$searchId',
          kind: kind,
          label: safeImportDisplayValue('query', search.name ?? search.query),
          previousLabel:
              kind == ImportChangeKind.changed &&
                  (oldSearch!.name ?? oldSearch.query) !=
                      (newSearch!.name ?? newSearch.query)
              ? safeImportDisplayValue(
                  'query',
                  oldSearch.name ?? oldSearch.query,
                )
              : null,
          profileId: search.profileId,
          details: [
            if (kind == ImportChangeKind.changed)
              ...importFieldChanges(
                {
                  ..._searchJson(oldSearch!),
                  if (reordered) 'position': oldIds.indexOf(searchId),
                },
                {
                  ..._searchJson(newSearch!),
                  if (reordered) 'position': newIds.indexOf(searchId),
                },
              ),
            if (search.name != null && kind != ImportChangeKind.changed)
              ImportChangeDetail(
                key: 'query',
                before: kind == ImportChangeKind.added
                    ? '∅'
                    : safeImportDisplayValue('query', search.query),
                after: kind == ImportChangeKind.removed
                    ? '∅'
                    : safeImportDisplayValue('query', search.query),
                kind: kind,
                presentation: ImportDetailPresentation.query,
              ),
          ],
        ),
      );
    }
    if (before == after && children.isEmpty) continue;
    if (!isHome && before == null && after == null) continue;
    final folder = isHome ? null : (after ?? before) as _FolderValue?;
    final kind = isHome
        ? ImportChangeKind.changed
        : before == null
        ? ImportChangeKind.added
        : after == null
        ? ImportChangeKind.removed
        : ImportChangeKind.changed;
    rows.add(
      ImportChangePreviewRow(
        category: 'topic_folders',
        id: id,
        kind: kind,
        isContainer: true,
        label: isHome ? '__home' : safeImportDisplayValue('name', folder!.name),
        previousLabel:
            before is _FolderValue &&
                after is _FolderValue &&
                before.name != after.name
            ? safeImportDisplayValue('name', before.name)
            : null,
        // Home is implicit: count its search changes, never the container itself.
        entityChanged:
            !isHome &&
            (before is! _FolderValue ||
                after is! _FolderValue ||
                before.name != after.name ||
                before.position != after.position ||
                before.parentId != after.parentId),
        children: children,
        details: [
          if (before is _FolderValue && after is _FolderValue)
            ...importFieldChanges(
              {'position': before.position},
              {'position': after.position},
            ),
          if (!const ListEquality<String>().equals(
            oldIds.where(newIds.contains).toList(),
            newIds.where(oldIds.contains).toList(),
          ))
            ImportChangeDetail(
              key: 'queryOrder',
              before: oldIds
                  .where(newIds.contains)
                  .map((id) => _pinnedQueryLabel(id, local))
                  .join('\n'),
              after: newIds
                  .where(oldIds.contains)
                  .map((id) => _pinnedQueryLabel(id, projected))
                  .join('\n'),
              presentation: ImportDetailPresentation.queryOrder,
            ),
        ],
      ),
    );
  }
  return rows;
}

String _pinnedQueryLabel(String id, Map<Object, Object?> values) {
  final search = values[_key('following-topic', id)] as _SearchValue?;
  return safeImportDisplayValue('query', search?.name ?? search?.query);
}

List<ImportChangeDetail> _profileFieldChanges(
  BooruConfig? before,
  BooruConfig? after,
) {
  Map<String, dynamic>? json(BooruConfig? profile) {
    if (profile == null) return null;
    final data = profile.toJson()
      ..remove('id')
      ..remove('name');
    if (data['blacklistedTags'] case final Map value)
      data['blacklistedTags'] = Map.of(value)..remove('blacklistedTags');
    return data;
  }

  Set<String> rules(BooruConfig? profile) =>
      (profile?.blacklistConfigs?.blacklistedTags ?? '')
          .split('\n')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet();
  final old = rules(before), next = rules(after);
  return [
    ...importFieldChanges(json(before), json(after)),
    for (final rule in next.difference(old))
      ImportChangeDetail(
        key: 'blacklistedTags',
        before: '∅',
        after: safeImportDisplayValue('rule', rule),
        kind: ImportChangeKind.added,
      ),
    for (final rule in old.difference(next))
      ImportChangeDetail(
        key: 'blacklistedTags',
        before: safeImportDisplayValue('rule', rule),
        after: '∅',
        kind: ImportChangeKind.removed,
      ),
  ];
}

Map<String, Object?> _searchJson(_SearchValue value) => {
  'query': value.query,
  'profileId': value.profileId,
  'position': value.position,
};
_EntityKey _key(String type, Object id) => _EntityKey(type, id);

String _idWithoutPrefix(String id, String prefix) =>
    id.startsWith(prefix) ? id.substring(prefix.length) : id;

String? _optionalIdWithoutPrefix(String? id, String prefix) =>
    id == null ? null : _idWithoutPrefix(id, prefix);

List<String> _orderedQueryUnion(
  Iterable<String> first,
  Iterable<String> second,
) {
  final seen = <String>{};
  return [
    for (final query in [...first, ...second])
      if (seen.add(normalizeSearchIdentity(query))) query,
  ];
}

final class _EntityKey extends Equatable {
  const _EntityKey(this.type, this.id);

  final String type;
  final Object id;

  @override
  List<Object> get props => [type, id];
}

final class _BookmarkValue extends Equatable {
  const _BookmarkValue(this.wire);
  factory _BookmarkValue.from(
    Bookmark bookmark, {
    StoredBookmarkCodec codec = const StoredBookmarkCodec(),
  }) => _BookmarkValue(
    codec.encodeForTransfer(bookmark)
      ..remove('id')
      ..remove('createdAt'),
  );
  final Map<String, Object?> wire;
  @override
  List<Object?> get props => [wire];
}

final class _BookmarkGroupValue extends Equatable {
  _BookmarkGroupValue({
    required this.name,
    required Set<Object> bookmarkIds,
    this.poolIds = const {},
    Map<Object, DateTime> addedAt = const {},
    this.folderId,
    this.parentGroupId,
    this.position = 0,
  }) : bookmarkIds = Set.unmodifiable(bookmarkIds),
       addedAt = Map.unmodifiable({
         for (final entry in addedAt.entries)
           if (bookmarkIds.contains(entry.key)) entry.key: entry.value.toUtc(),
       });

  final Map<Object, DateTime> addedAt;
  final String name;
  final Set<Object> bookmarkIds;
  final Set<Object> poolIds;
  _BookmarkGroupValue withPools(Set<Object> ids) => _BookmarkGroupValue(
    name: name,
    bookmarkIds: bookmarkIds,
    addedAt: addedAt,
    poolIds: ids,
    folderId: folderId,
    parentGroupId: parentGroupId,
    position: position,
  );
  final String? folderId;
  final String? parentGroupId;
  final int position;

  @override
  List<Object?> get props => [
    name,
    bookmarkIds,
    addedAt,
    folderId,
    parentGroupId,
    position,
    poolIds,
  ];
}

final class _SearchValue extends Equatable {
  const _SearchValue({
    required this.profileId,
    required this.query,
    required this.name,
    required this.position,
    required this.autoUpdateEnabled,
  });

  factory _SearchValue.from(
    FollowingTopic search, {
    bool? autoUpdateEnabled,
  }) => _SearchValue(
    profileId: search.profileId,
    query: normalizeSearchIdentity(search.query),
    name: search.name,
    position: search.position,
    autoUpdateEnabled: autoUpdateEnabled ?? search.autoUpdateEnabled,
  );

  final String profileId;
  final String query;
  final String? name;
  final int position;
  final bool autoUpdateEnabled;

  @override
  List<Object?> get props => [
    profileId,
    query,
    name,
    position,
    autoUpdateEnabled,
  ];
}

final class _FolderValue extends Equatable {
  _FolderValue({
    required this.name,
    required Iterable<String> searchIds,
    required this.position,
    this.parentId,
    this.feedEnabled = false,
    this.feedMaxPosts = topicFeedRetention,
  }) : searchIds = List.unmodifiable(searchIds);

  factory _FolderValue.from(TopicFolder folder) => _FolderValue(
    name: folder.name,
    searchIds: folder.searchIds,
    parentId: folder.parentId,
    position: folder.position,
    feedEnabled: folder.feedEnabled,
    feedMaxPosts: folder.feedMaxPosts,
  );

  final bool feedEnabled;
  final int feedMaxPosts;
  final String name;
  final List<String> searchIds;
  final int position;
  final String? parentId;

  @override
  List<Object?> get props => [
    name,
    searchIds,
    position,
    parentId,
    feedEnabled,
    feedMaxPosts,
  ];
}

final class _HomeValue extends Equatable {
  _HomeValue(Iterable<String> searchIds)
    : searchIds = List.unmodifiable(searchIds);

  final List<String> searchIds;

  @override
  List<Object> get props => [searchIds];
}

final class _FeedValue extends Equatable {
  _FeedValue({
    required this.profileId,
    required this.name,
    required this.position,
    required Iterable<String> queries,
  }) : queries = List.unmodifiable(queries);

  factory _FeedValue.from(
    TopicFeed feed,
    Map<String, FollowingTopic> searches,
  ) => _FeedValue(
    profileId: feed.profileId,
    name: feed.name,
    position: feed.position,
    queries: [
      for (final id in feed.sourceIds)
        if (searches[id] case final source?)
          normalizeSearchIdentity(source.query),
    ],
  );

  final String profileId;
  final String name;
  final int position;
  final List<String> queries;

  @override
  List<Object> get props => [profileId, name, position, queries];
}
