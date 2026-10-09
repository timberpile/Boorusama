import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:i18n/i18n.dart';
import '../../../groups/folder_tree.dart';
import '../../sources/pinned_search_import_service.dart';
import 'collection_import_action.dart';

import '../../../bookmarks/types.dart';
import '../../../configs/config/types.dart';
import '../../../search/subscriptions/types.dart';
import '../../sources/bookmark_backup_data.dart';
import '../../sources/following_feed_backup_data.dart';
import '../../sources/pinned_search_backup_data.dart';
import '../../sources/search_backup_profile.dart';
import '../models/import_action.dart';
import 'import_plan.dart';
import 'bookmark_profile_dependency.dart';
import 'import_change_preview.dart';
import 'import_preflight.dart';
import 'profile_dependency_planner.dart';
import 'profile_import_projection.dart';

final class BookmarkImportLocalSnapshot {
  BookmarkImportLocalSnapshot({
    required Iterable<Bookmark> bookmarks,
    required Iterable<BookmarkGroup> groups,
    this.folders = const [],
  }) : bookmarks = List.unmodifiable(bookmarks),
       groups = List.unmodifiable(groups);

  final List<Bookmark> bookmarks;
  final List<BookmarkGroup> groups;
  final List<CollectionFolder> folders;
}

final class PinnedSearchImportLocalSnapshot {
  PinnedSearchImportLocalSnapshot({
    required Iterable<SearchSubscription> searches,
    required this.organization,
    required Iterable<SearchFollowingFeed> feeds,
  }) : searches = List.unmodifiable(searches),
       feeds = List.unmodifiable(feeds);

  final List<SearchSubscription> searches;
  final SearchOrganization organization;
  final List<SearchFollowingFeed> feeds;
}

final class FollowingFeedImportLocalSnapshot {
  FollowingFeedImportLocalSnapshot({
    required Iterable<SearchSubscription> searches,
    required Iterable<SearchFollowingFeed> feeds,
  }) : searches = List.unmodifiable(searches),
       feeds = List.unmodifiable(feeds);

  final List<SearchSubscription> searches;
  final List<SearchFollowingFeed> feeds;
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
  }) {
    final mappedBookmarks = <int, Bookmark>{};
    for (final bookmark in selectedProfileBookmarks(incoming, resolution)) {
      final profileId =
          profileMappings[ProfileReferenceKey.fromReference(
            bookmarkProfileReference(bookmark),
          )];
      if (profileId != null)
        mappedBookmarks[bookmark.id] = bookmarkWithProfileHint(
          bookmark,
          profileId,
        );
    }
    final data = BookmarkBackupData(
      bookmarks: [
        for (final bookmark in incoming.bookmarks)
          mappedBookmarks[bookmark.id] ?? bookmark,
      ],
      groups: incoming.groups,
      folders: incoming.folders,
    );
    final localByIdentity = {
      for (final bookmark in local.bookmarks)
        bookmark.transferIdentity: bookmark,
    };
    final localIdentityById = {
      for (final bookmark in local.bookmarks)
        bookmark.id: bookmark.transferIdentity,
    };
    final localGroups = <String, _BookmarkGroupValue>{
      for (final group in local.groups)
        group.id: _BookmarkGroupValue(
          name: group.name,
          folderId: group.folderId,
          position: group.position,
          bookmarkIds: {
            for (final id in group.bookmarkIds) ?localIdentityById[id],
          },
        ),
    };
    final localEntities = <Object, Object?>{
      for (final f in local.folders) _key('bookmark-folder', f.id): f,
      for (final entry in localByIdentity.entries)
        _key('bookmark', entry.key): _BookmarkValue.from(entry.value),
      for (final entry in localGroups.entries)
        _key('bookmark-group', entry.key): entry.value,
    };
    if (resolution.action == ImportAction.skip) {
      return PlannedChangeSummary(preserved: localEntities.length);
    }

    final incomingIdentityById = {
      for (final bookmark in data.bookmarks)
        bookmark.id: bookmark.transferIdentity,
    };
    final incomingByIdentity = {
      for (final bookmark in data.bookmarks)
        bookmark.transferIdentity: bookmark,
    };
    if (resolution.action == ImportAction.replace) {
      final projected = <Object, Object?>{
        for (final f in data.folders) _key('bookmark-folder', f.id): f,
        for (final entry in incomingByIdentity.entries)
          _key('bookmark', entry.key): _BookmarkValue.from(entry.value),
        for (final (index, group) in data.groups.indexed)
          _key(
            'bookmark-group',
            group.id ?? 'legacy-$index',
          ): _BookmarkGroupValue(
            name: group.name,
            folderId: group.folderId,
            position: group.position,
            bookmarkIds: {
              for (final id in group.bookmarkIds) ?incomingIdentityById[id],
            },
          ),
      };
      return _summarize(
        local: localEntities,
        projected: projected,
        touched: {...localEntities.keys, ...projected.keys},
      );
    }

    final actions = {for (final item in resolution.items) item.id: item};
    final allGroupedIncomingIds = {
      for (final group in data.groups) ...group.bookmarkIds,
    };
    final ungroupedAction = actions['ungrouped']?.action;
    final chosenGroups = [
      for (final group in data.groups)
        if (actions['group:${group.id}']?.action != ImportAction.skip) group,
    ];
    final chosenIds = {
      for (final group in chosenGroups) ...group.bookmarkIds,
      if (ungroupedAction != null && ungroupedAction != ImportAction.skip)
        for (final bookmark in data.bookmarks)
          if (!allGroupedIncomingIds.contains(bookmark.id)) bookmark.id,
    };
    final projectedBookmarks = Map.of(localByIdentity);
    final projectedGroups = Map.of(localGroups);
    final touched = <Object>{};

    if (ungroupedAction == ImportAction.update) {
      final groupedLocal = {
        for (final group in projectedGroups.values) ...group.bookmarkIds,
      };
      final incomingUngrouped = {
        for (final id in chosenIds)
          if (!allGroupedIncomingIds.contains(id)) ?incomingIdentityById[id],
      };
      projectedBookmarks.removeWhere(
        (identity, _) =>
            !groupedLocal.contains(identity) &&
            !incomingUngrouped.contains(identity),
      );
    }
    for (final id in chosenIds) {
      final identity = incomingIdentityById[id];
      final bookmark = identity == null ? null : incomingByIdentity[identity];
      if (identity == null || bookmark == null) continue;
      projectedBookmarks.putIfAbsent(identity, () => bookmark);
      if (mappedBookmarks.containsKey(id)) {
        projectedBookmarks[identity] = bookmarkWithProfileHint(
          projectedBookmarks[identity]!,
          bookmark.post.origin.profileIdHint!,
        );
      }
      touched.add(_key('bookmark', identity));
    }

    final copies = chosenGroups
        .where(
          (g) =>
              (actions['group:${g.id}']?.action ??
                  (localGroups.containsKey(g.id)
                      ? ImportAction.update
                      : ImportAction.copy)) ==
              ImportAction.copy,
        )
        .toList();
    var nextFolderId = 0;
    final hierarchy = copies.isEmpty
        ? null
        : planFolderHierarchyCopy(
            current: local.folders,
            incoming: data.folders,
            itemFolders: copies.map((g) => g.folderId),
            wrapperName: Translations().folders.imported_groups,
            newId: () => '__created__bookmark-folder-${nextFolderId++}',
          );
    final projectedFolders = hierarchy?.folders ?? local.folders;
    final orphanCandidates = <BookmarkUniqueId>{};
    for (final (index, group) in chosenGroups.indexed) {
      final sourceId = group.id ?? 'legacy-$index';
      final item = actions['group:${group.id}'];
      final action =
          item?.action ??
          (projectedGroups.containsKey(sourceId)
              ? ImportAction.update
              : ImportAction.copy);
      final memberships = {
        for (final id in group.bookmarkIds) ?incomingIdentityById[id],
      };
      final targetId = switch (action) {
        ImportAction.mergeIntoTarget => _optionalIdWithoutPrefix(
          item?.targetId,
          'group:',
        ),
        ImportAction.copy when projectedGroups.containsKey(sourceId) =>
          '__copy__bookmark-group-$sourceId-$index',
        _ => sourceId,
      };
      // Target selection is an intermediate review state. Preflight reports
      // invalid targets; a complete preview is available once one is chosen.
      if (targetId == null ||
          (action == ImportAction.mergeIntoTarget &&
              !localGroups.containsKey(targetId))) {
        return null;
      }
      final existing = projectedGroups[targetId];
      projectedGroups[targetId] = switch (action) {
        ImportAction.update => _BookmarkGroupValue(
          name: existing?.name ?? group.name,
          folderId: existing?.folderId,
          position: existing?.position ?? group.position,
          bookmarkIds: memberships,
        ),
        ImportAction.replace => _BookmarkGroupValue(
          name: group.name,
          bookmarkIds: memberships,
        ),
        ImportAction.merge ||
        ImportAction.mergeIntoTarget => _BookmarkGroupValue(
          name: existing?.name ?? group.name,
          folderId: existing?.folderId,
          position: existing?.position ?? group.position,
          bookmarkIds: {...?existing?.bookmarkIds, ...memberships},
        ),
        ImportAction.copy => _BookmarkGroupValue(
          name: group.name,
          folderId: group.folderId == null
              ? hierarchy?.wrapperId
              : hierarchy?.folderIds[group.folderId],
          position: group.position,
          bookmarkIds: memberships,
        ),
        ImportAction.skip || ImportAction.configureItems => throw StateError(
          'Group action is not applicable',
        ),
      };
      if ((action == ImportAction.update || action == ImportAction.replace) &&
          existing != null) {
        orphanCandidates.addAll(existing.bookmarkIds.difference(memberships));
      }
      touched.add(_key('bookmark-group', targetId));
    }
    final finalMemberships = {
      for (final group in projectedGroups.values) ...group.bookmarkIds,
    };
    for (final identity in orphanCandidates.difference(finalMemberships)) {
      projectedBookmarks.remove(identity);
      touched.add(_key('bookmark', identity));
    }

    return _summarize(
      local: localEntities,
      projected: {
        for (final f in projectedFolders) _key('bookmark-folder', f.id): f,
        for (final entry in projectedBookmarks.entries)
          _key('bookmark', entry.key): _BookmarkValue.from(entry.value),
        for (final entry in projectedGroups.entries)
          _key('bookmark-group', entry.key): entry.value,
      },
      touched: touched,
    );
  }

  PlannedChangeSummary? pinnedSearches({
    required PinnedSearchImportLocalSnapshot local,
    required PinnedSearchBackupData incoming,
    required ResolvedImportSource resolution,
    required Map<ProfileReferenceKey, String> profileMappings,
  }) {
    final internalIds = {
      for (final feed in local.feeds) ...feed.sourceIds,
    };
    final localSearches = {
      for (final search in local.searches)
        if (!internalIds.contains(search.id)) search.id: search,
    };
    final localFolders = local.organization.folders;
    final localEntities = <Object, Object?>{
      for (final entry in localSearches.entries)
        _key('pinned-search', entry.key): _SearchValue.from(entry.value),
      for (final folder in localFolders)
        _key('pinned-folder', folder.id): _FolderValue.from(folder),
      _key('pinned-home', 'home'): _HomeValue(
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

    final searches = <String, SearchSubscription>{
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
              pinnedSearchFolderSkipped(incoming, record.id, {
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
      final normalized = normalizeSearchIdentity(record.query);
      final byQuery = searches.values.firstWhereOrNull(
        (search) =>
            !internalIds.contains(search.id) &&
            search.profileId == profileId &&
            normalizeSearchIdentity(search.query) == normalized,
      );
      final saved = byQuery;
      if (saved != null) {
        importedByBackupId[record.id] = saved.id;
        touched.add(_key('pinned-search', saved.id));
        continue;
      }
      final id = searches.containsKey(record.id)
          ? '__created__pinned-${record.id}'
          : record.id;
      final created = SearchSubscription.create(
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
      touched.add(_key('pinned-search', id));
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
          SharedSearchFolder(
            id: record.id,
            name: record.name,
            parentId: record.parentId,
            position: record.position,
            searchIds: mapped(record.searchIds),
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
      final organization = planPinnedSearchFolderImport(
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
        touched.add(_key('pinned-folder', folder.id));
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
          _key('pinned-search', entry.key): _SearchValue.from(entry.value),
        for (final folder in folders)
          _key('pinned-folder', folder.id): _FolderValue.from(folder),
        _key('pinned-home', 'home'): _HomeValue(home),
      },
      touched: resolution.action == ImportAction.replace
          ? {...localEntities.keys, ...touched}
          : touched,
    );
  }

  PlannedChangeSummary? followingFeeds({
    required FollowingFeedImportLocalSnapshot local,
    required FollowingFeedBackupData incoming,
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
        <({int index, String profileId, FollowingFeedBackupRecord record})>[];
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
        record: FollowingFeedBackupRecord(
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
  required FollowingFeedBackupRecord record,
  required String profileId,
  required Map<String, SearchFollowingFeed> feeds,
  required Map<String, SearchSubscription> searches,
}) {
  final normalized = <String>[];
  final seen = <String>{};
  for (final query in record.queries) {
    final value = normalizeSearchIdentity(query);
    if (value.isNotEmpty && seen.add(value)) normalized.add(value);
  }
  final previous = feeds[record.id];
  final internalIds = {for (final feed in feeds.values) ...feed.sourceIds};
  final internalByQuery = <String, SearchSubscription>{
    for (final search in searches.values)
      if (internalIds.contains(search.id) && search.profileId == profileId)
        normalizeSearchIdentity(search.query): search,
  };
  final retained = <SearchSubscription>[];
  for (final (position, query) in normalized.indexed) {
    final existing = internalByQuery[query];
    retained.add(
      existing ??
          SearchSubscription.create(
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
  feeds[record.id] = SearchFollowingFeed(
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
  required Map<String, SearchFollowingFeed> feeds,
  required Map<String, SearchSubscription> searches,
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
    } else if (local[key] != projected[key]) {
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
    if (before == after) continue;
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
        final oldMembers = old?.bookmarkIds ?? <BookmarkUniqueId>{},
            nextMembers = next?.bookmarkIds ?? <BookmarkUniqueId>{};
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
      case final _BookmarkValue _:
        if (before != null && after != null) metadataChanges++;
      case _SearchValue() || _FolderValue() || _HomeValue():
        // Pins are emitted inside their folders, including unchanged containers.
        break;
      case final _FeedValue feed:
        rows.add(
          ImportChangePreviewRow(
            category: 'following_feeds',
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
        if (key.type == 'pinned-folder')
          if (values[key] case final _FolderValue folder) key: folder.searchIds,
    };
    final assigned = folders.values.expand((ids) => ids).toSet();
    final home = values[_key('pinned-home', 'home')] as _HomeValue?;
    folders[_key('pinned-home', 'home')] = [
      for (final id in home?.searchIds ?? <String>[])
        if (!assigned.contains(id)) id,
      // Legacy pins without an organization entry still belong under Home.
      for (final key in values.keys.cast<_EntityKey>())
        if (key.type == 'pinned-search' &&
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
    final id = key.type == 'pinned-home' ? 'home' : 'folder:${key.id}';
    final isHome = key.type == 'pinned-home';
    final before = local[key];
    final after = projected[key];
    final oldIds = oldContainers[key] ?? [];
    final newIds = newContainers[key] ?? [];
    final oldCommon = oldIds.where(newIds.contains).toList();
    final newCommon = newIds.where(oldIds.contains).toList();
    final children = <ImportChangePreviewRow>[];
    for (final searchId in {...newIds, ...oldIds}) {
      final oldSearch = local[_key('pinned-search', searchId)] as _SearchValue?;
      final newSearch =
          projected[_key('pinned-search', searchId)] as _SearchValue?;
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
          category: 'pinned_searches',
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
        category: 'pinned_folders',
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
  final search = values[_key('pinned-search', id)] as _SearchValue?;
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
  const _BookmarkValue({
    required this.createdAt,
    required this.updatedAt,
    required this.snapshot,
    required this.postId,
  });

  factory _BookmarkValue.from(Bookmark bookmark) => _BookmarkValue(
    createdAt: bookmark.createdAt,
    updatedAt: bookmark.updatedAt,
    snapshot: bookmark.snapshot,
    postId: bookmark.postId,
  );

  final DateTime createdAt;
  final DateTime updatedAt;
  final Object snapshot;
  final int? postId;

  @override
  List<Object?> get props => [createdAt, updatedAt, snapshot, postId];
}

final class _BookmarkGroupValue extends Equatable {
  _BookmarkGroupValue({
    required this.name,
    required Set<BookmarkUniqueId> bookmarkIds,
    this.folderId,
    this.position = 0,
  }) : bookmarkIds = Set.unmodifiable(bookmarkIds);

  final String name;
  final Set<BookmarkUniqueId> bookmarkIds;
  final String? folderId;
  final int position;

  @override
  List<Object?> get props => [name, bookmarkIds, folderId, position];
}

final class _SearchValue extends Equatable {
  const _SearchValue({
    required this.profileId,
    required this.query,
    required this.name,
    required this.position,
  });

  factory _SearchValue.from(SearchSubscription search) => _SearchValue(
    profileId: search.profileId,
    query: normalizeSearchIdentity(search.query),
    name: search.name,
    position: search.position,
  );

  final String profileId;
  final String query;
  final String? name;
  final int position;

  @override
  List<Object?> get props => [profileId, query, name, position];
}

final class _FolderValue extends Equatable {
  _FolderValue({
    required this.name,
    required Iterable<String> searchIds,
    required this.position,
    this.parentId,
  }) : searchIds = List.unmodifiable(searchIds);

  factory _FolderValue.from(SharedSearchFolder folder) => _FolderValue(
    name: folder.name,
    searchIds: folder.searchIds,
    parentId: folder.parentId,
    position: folder.position,
  );

  final String name;
  final List<String> searchIds;
  final int position;
  final String? parentId;

  @override
  List<Object?> get props => [name, searchIds, position, parentId];
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
    SearchFollowingFeed feed,
    Map<String, SearchSubscription> searches,
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
