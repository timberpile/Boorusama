// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../bookmarks/types.dart';
import '../../groups/folder_tree.dart';
import '../types/backup_data_source.dart';

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
  });

  final String? id;
  final String name;
  final List<int> bookmarkIds;
  final String? folderId;
  final int position;

  Map<String, dynamic> toJson() => {
    'id': ?id,
    'name': name,
    'bookmarkIds': bookmarkIds,
    'folderId': folderId,
    'position': position,
  };

  @override
  List<Object?> get props => [id, name, bookmarkIds, folderId, position];
}

class BookmarkBackupData extends Equatable {
  const BookmarkBackupData({
    required this.bookmarks,
    required this.groups,
    this.folders = const [],
  });

  final List<Bookmark> bookmarks;
  final List<BookmarkGroupBackup> groups;
  final List<CollectionFolder> folders;

  Map<String, dynamic> get extraFields => {
    'groups': groups.map((group) => group.toJson()).toList(),
    'folders': folders.map((folder) => folder.toJson()).toList(),
  };

  @override
  List<Object?> get props => [bookmarks, groups, folders];
}

BookmarkBackupData buildBookmarkBackupData({
  required List<Bookmark> bookmarks,
  required List<BookmarkGroup> groups,
  required BookmarkExportScope scope,
  List<CollectionFolder> folders = const [],
}) {
  final tree = FolderTree(folders);
  final selectedFolders = {
    for (final id in scope.folderIds)
      if (tree.byId.containsKey(id)) ...tree.subtree(id),
  };
  final selectedGroups = {
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
        ),
      )
      .toList();
  return BookmarkBackupData(
    bookmarks: exportedBookmarks,
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
