// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

// Project imports:
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_plan.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_planner.dart';
import 'package:boorusama/core/bookmarks/types.dart';

void main() {
  const groupId = '550e8400-e29b-41d4-a716-446655440000';
  final first = Bookmark.empty.copyWith(
    id: 10,
    originalUrl: 'https://example.com/first.jpg',
  );
  final second = Bookmark.empty.copyWith(
    id: 20,
    originalUrl: 'https://example.com/second.jpg',
  );

  test('legacy groups with matching names always receive new IDs', () {
    final plan = const BookmarkImportPlanner().plan(
      data: BookmarkBackupData(
        bookmarks: [first],
        groups: const [
          BookmarkGroupBackup(id: null, name: 'Same', bookmarkIds: [10]),
          BookmarkGroupBackup(id: null, name: 'Same', bookmarkIds: [10]),
        ],
      ),
      currentBookmarks: [first],
      currentGroups: [
        BookmarkGroup(id: groupId, name: 'Same', bookmarkIds: const {}),
      ],
    );

    expect(plan.groups.map((group) => group.id).toSet(), hasLength(2));
    expect(
      plan.groups.every((group) => Uuid.isValidUUID(fromString: group.id)),
      isTrue,
    );
    expect(plan.conflicts, isEmpty);
  });

  test('detects conflicts by GUID and maps file-local bookmark IDs', () {
    final plan = const BookmarkImportPlanner().plan(
      data: BookmarkBackupData(
        bookmarks: [first, second],
        groups: const [
          BookmarkGroupBackup(
            id: groupId,
            name: 'Imported name',
            bookmarkIds: [10, 999],
          ),
        ],
      ),
      currentBookmarks: [first],
      currentGroups: [
        BookmarkGroup(id: groupId, name: 'Local name', bookmarkIds: const {}),
      ],
    );

    expect(plan.missingBookmarks, [second]);
    expect(plan.conflicts.single.name, 'Imported name');
    expect(plan.conflicts.single.bookmarkIds, {first.uniqueId});
    expect(
      plan.resolve({groupId: BookmarkGroupConflictChoice.replace}).isResolved,
      isTrue,
    );
  });
}
