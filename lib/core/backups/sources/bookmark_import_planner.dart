// Package imports:
import 'package:uuid/uuid.dart';

// Project imports:
import '../../bookmarks/types.dart';
import 'bookmark_backup_data.dart';
import 'bookmark_import_plan.dart';

class BookmarkImportPlanner {
  const BookmarkImportPlanner({this.uuid = const Uuid()});

  final Uuid uuid;

  BookmarkImportPlan plan({
    required BookmarkBackupData data,
    required List<Bookmark> currentBookmarks,
    required List<BookmarkGroup> currentGroups,
  }) {
    final currentBookmarkIds = currentBookmarks
        .map((bookmark) => bookmark.transferIdentity)
        .toSet();
    final importedByLocalId = {
      for (final bookmark in data.bookmarks)
        bookmark.id: bookmark.transferIdentity,
    };
    final currentGroupIds = currentGroups.map((group) => group.id).toSet();
    return BookmarkImportPlan(
      bookmarks: List.unmodifiable(data.bookmarks),
      folders: data.folders,
      missingBookmarks: data.bookmarks
          .where(
            (bookmark) =>
                !currentBookmarkIds.contains(bookmark.transferIdentity),
          )
          .toList(),
      groups: [
        for (final group in data.groups)
          BookmarkGroupImport(
            id: group.id ?? uuid.v4().toLowerCase(),
            name: group.name,
            folderId: group.folderId,
            position: group.position,
            bookmarkIds: {
              for (final exportedId in group.bookmarkIds)
                ?importedByLocalId[exportedId],
            },
            conflicts: group.id != null && currentGroupIds.contains(group.id),
          ),
      ],
    );
  }
}
