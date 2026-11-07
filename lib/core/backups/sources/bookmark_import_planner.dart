// Package imports:
import 'package:uuid/uuid.dart';

// Project imports:
import '../../bookmarks/types.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
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
    final currentIdentities = {
      for (final bookmark in currentBookmarks)
        if (bookmarkContentIdentity(bookmark) case final identity?) identity,
    };
    final importedBookmarks = {for (final b in data.records) b.id: b};
    final currentGroupIds = currentGroups.map((group) => group.id).toSet();
    return BookmarkImportPlan(
      records: data.records,
      folders: data.folders,
      alreadyExistedCount: data.records
          .where(
            (b) => switch (bookmarkContentIdentity(b)) {
              final identity? => currentIdentities.contains(identity),
              _ => false,
            },
          )
          .length,
      groups: [
        for (final group in data.groups)
          BookmarkGroupImport(
            id: group.id ?? uuid.v4().toLowerCase(),
            name: group.name,
            folderId: group.folderId,
            position: group.position,
            bookmarkIds: group.bookmarkIds.toSet(),
            addedAt: {
              for (final id in group.bookmarkIds)
                id:
                    group.addedAt[id] ??
                    bookmarkCreatedAt(
                      importedBookmarks[id] ??
                          (throw const FormatException(
                            'Absent Bookmark reference',
                          )),
                    ),
            },
            conflicts:
                !group.isDefault &&
                group.id != null &&
                currentGroupIds.contains(group.id),
          ),
      ],
    );
  }
}
