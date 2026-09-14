// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../bookmarks/types.dart';
import '../types/backup_data_source.dart';

class BookmarkExportScope extends Equatable implements BackupExportScope {
  const BookmarkExportScope.all() : groupIds = null, includeUngrouped = false;

  BookmarkExportScope.selected({
    required Iterable<String> groupIds,
    this.includeUngrouped = false,
  }) : groupIds = Set.unmodifiable(groupIds);

  final Set<String>? groupIds;
  final bool includeUngrouped;

  bool get isAll => groupIds == null;

  @override
  List<Object?> get props => [groupIds, includeUngrouped];
}

class BookmarkGroupBackup extends Equatable {
  const BookmarkGroupBackup({
    required this.id,
    required this.name,
    required this.bookmarkIds,
  });

  final String? id;
  final String name;
  final List<int> bookmarkIds;

  Map<String, dynamic> toJson() => {
    'id': ?id,
    'name': name,
    'bookmarkIds': bookmarkIds,
  };

  @override
  List<Object?> get props => [id, name, bookmarkIds];
}

class BookmarkBackupData extends Equatable {
  const BookmarkBackupData({
    required this.bookmarks,
    required this.groups,
  });

  final List<Bookmark> bookmarks;
  final List<BookmarkGroupBackup> groups;

  Map<String, dynamic> get extraFields => {
    'groups': groups.map((group) => group.toJson()).toList(),
  };

  @override
  List<Object?> get props => [bookmarks, groups];
}

BookmarkBackupData buildBookmarkBackupData({
  required List<Bookmark> bookmarks,
  required List<BookmarkGroup> groups,
  required BookmarkExportScope scope,
}) {
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
              memberships.any(scope.groupIds!.contains);
        }).toList();
  final exportedIds = exportedBookmarks.map((bookmark) => bookmark.id).toSet();
  final exportedGroups = groups
      .where((group) => scope.isAll || scope.groupIds!.contains(group.id))
      .map(
        (group) => BookmarkGroupBackup(
          id: group.id,
          name: group.name,
          bookmarkIds: group.bookmarkIds.intersection(exportedIds).toList(),
        ),
      )
      .toList();
  return BookmarkBackupData(
    bookmarks: exportedBookmarks,
    groups: exportedGroups,
  );
}
