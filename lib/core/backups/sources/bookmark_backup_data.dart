// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../bookmarks/types.dart';
import '../../groups/folder_tree.dart';
import '../types/backup_data_source.dart';
import '../types/types.dart';

class BookmarkExportScope extends Equatable implements BackupExportScope {
  const BookmarkExportScope.all()
    : groupIds = null,
      folderIds = const {},
      includeUngrouped = false;

  BookmarkExportScope.selected({
    required Iterable<String> groupIds,
    this.includeUngrouped = false,
    Iterable<String> folderIds = const [],
  }) : groupIds = Set.unmodifiable(groupIds),
       folderIds = Set.unmodifiable(folderIds);

  final Set<String>? groupIds;
  final Set<String> folderIds;
  final bool includeUngrouped;

  bool get isAll => groupIds == null;

  @override
  List<Object?> get props => [groupIds, includeUngrouped, folderIds];
}

class BookmarkGroupBackup extends Equatable {
  const BookmarkGroupBackup({
    required this.id,
    required this.name,
    required this.bookmarkIds,
    this.folderId,
    this.position = 0,
    this.addedAt = const {},
  });

  bool get isDefault => id == defaultBookmarkGroupId;

  final String? id;
  final String name;
  final List<int> bookmarkIds;
  final Map<int, DateTime> addedAt;
  final String? folderId;
  final int position;

  Map<String, dynamic> toJson() => {
    'id': ?id,
    if (isDefault) 'systemRole': 'default',
    'name': name,
    'bookmarkIds': bookmarkIds,
    'addedAt': addedAt.map(
      (id, date) => MapEntry('$id', date.toUtc().toIso8601String()),
    ),
    'folderId': folderId,
    'position': position,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    bookmarkIds,
    addedAt,
    folderId,
    position,
  ];
}

class BookmarkBackupData extends Equatable {
  const BookmarkBackupData({
    required this.bookmarks,
    required this.groups,
    this.folders = const [],
    this.pools = const [],
  });

  final List<CollectionBookmark> pools;
  final List<Bookmark> bookmarks;
  final List<BookmarkGroupBackup> groups;
  final List<CollectionFolder> folders;

  Map<String, dynamic> get extraFields {
    final byId = {for (final bookmark in bookmarks) bookmark.id: bookmark};
    if (groups.any(
      (group) => group.bookmarkIds.any((id) => !byId.containsKey(id)),
    )) {
      throw const InvalidBackupFormatException(
        'Group references an absent bookmark',
      );
    }
    final exportGroups = <BookmarkGroupBackup>[
      for (final group in groups)
        BookmarkGroupBackup(
          id: group.id,
          name: group.name,
          folderId: group.folderId,
          position: group.position,
          bookmarkIds: group.bookmarkIds,
          addedAt: {
            for (final id in group.bookmarkIds)
              id:
                  group.addedAt[id] ??
                  byId[id]?.createdAt ??
                  (throw const InvalidBackupFormatException(
                    'Group references an absent bookmark',
                  )),
          },
        ),
    ];
    final assigned = {for (final group in exportGroups) ...group.bookmarkIds};
    final ungrouped = byId.keys.toSet().difference(assigned);
    // Legacy ungrouped data gets the same Default membership as library repair.
    if (ungrouped.isNotEmpty) {
      final index = exportGroups.indexWhere((group) => group.isDefault);
      final previous = index < 0 ? null : exportGroups[index];
      final defaultGroup = BookmarkGroupBackup(
        id: defaultBookmarkGroupId,
        name: previous?.name ?? 'Default',
        bookmarkIds: [...?previous?.bookmarkIds, ...ungrouped],
        position: previous?.position ?? 0,
        addedAt: {
          ...?previous?.addedAt,
          for (final id in ungrouped) id: byId[id]!.createdAt,
        },
      );
      if (index < 0) {
        exportGroups.add(defaultGroup);
      } else {
        exportGroups[index] = defaultGroup;
      }
    }
    return {
      'groups': exportGroups.map((group) => group.toJson()).toList(),
      'folders': folders.map((folder) => folder.toJson()).toList(),
      if (pools.isNotEmpty)
        'collectionBookmarks': pools
            .map((pool) => pool.toJson()..remove('createdAt'))
            .toList(),
    };
  }

  @override
  List<Object?> get props => [bookmarks, groups, folders, pools];
}

BookmarkBackupData buildBookmarkBackupData({
  required List<Bookmark> bookmarks,
  required List<BookmarkGroup> groups,
  required BookmarkExportScope scope,
  List<CollectionFolder> folders = const [],
  List<CollectionBookmark> pools = const [],
}) {
  final tree = FolderTree(folders);
  final byId = {for (final bookmark in bookmarks) bookmark.id: bookmark};
  final selectedFolders = {
    for (final id in scope.folderIds)
      if (tree.byId.containsKey(id)) ...tree.subtree(id),
  };
  final selectedGroups = {
    if (scope.includeUngrouped) defaultBookmarkGroupId,
    ...?scope.groupIds,
    for (final g in groups)
      if (selectedFolders.contains(g.folderId)) g.id,
  };
  final membershipsByBookmark = <int, Set<String>>{};
  for (final group in groups) {
    for (final bookmarkId in group.bookmarkIds) {
      membershipsByBookmark.putIfAbsent(bookmarkId, () => {}).add(group.id);
    }
  }
  final exportedBookmarks = scope.isAll
      ? bookmarks
      : bookmarks.where((bookmark) {
          final memberships = membershipsByBookmark[bookmark.id] ?? const {};
          return (scope.includeUngrouped && memberships.isEmpty) ||
              memberships.any(selectedGroups.contains);
        }).toList();
  final exportedIds = exportedBookmarks.map((bookmark) => bookmark.id).toSet();
  final exportedGroups = groups
      .where((group) => scope.isAll || selectedGroups.contains(group.id))
      .map(
        (group) => BookmarkGroupBackup(
          id: group.id,
          name: group.name,
          folderId: group.folderId,
          position: group.position,
          bookmarkIds: group.bookmarkIds.intersection(exportedIds).toList(),
          addedAt: {
            for (final id in group.bookmarkIds.intersection(exportedIds))
              id: group.addedAt[id] ?? byId[id]!.createdAt,
          },
        ),
      )
      .toList();
  return BookmarkBackupData(
    bookmarks: exportedBookmarks,
    pools: [
      for (final pool in pools)
        if (scope.isAll)
          pool
        else if (pool.groupIds.intersection(selectedGroups).isNotEmpty)
          pool.withGroups(pool.groupIds.intersection(selectedGroups)),
    ],
    groups: exportedGroups,
    folders: scope.isAll
        ? folders
        : folders
              .where(
                (f) =>
                    selectedFolders.contains(f.id) ||
                    scope.folderIds.any(
                      (id) =>
                          tree.byId.containsKey(id) &&
                          tree.ancestors(id).any((a) => a.id == f.id),
                    ) ||
                    exportedGroups.any(
                      (g) =>
                          tree.ancestors(g.folderId).any((a) => a.id == f.id),
                    ),
              )
              .toList(),
  );
}
