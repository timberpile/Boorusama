import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_plan.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';

class _LegacyRecords implements BookmarkRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected repository access');
}

class _LegacyGroups implements BookmarkGroupRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected repository access');
}

void main() {
  const parent = '11111111-1111-4111-8111-111111111111';
  const child = '22222222-2222-4222-8222-222222222222';
  final service = BookmarkImportService(
    bookmarkRepository: _LegacyRecords(),
    groupRepository: _LegacyGroups(),
    imageUrlResolver: (_) => const DefaultImageUrlResolver(),
  );
  final unsupported = isA<StateError>().having(
    (error) => error.message,
    'message',
    'Nested Bookmark imports require unified storage',
  );
  test(
    'nested apply rejects an unmigrated target before reading or writing it',
    () async {
      final plan = BookmarkImportPlan(
        records: const [],
        alreadyExistedCount: 0,
        groups: const [
          BookmarkGroupImport(
            id: parent,
            name: 'Parent',
            bookmarkIds: {},
            conflicts: false,
          ),
          BookmarkGroupImport(
            id: child,
            name: 'Child',
            parentGroupId: parent,
            bookmarkIds: {},
            conflicts: false,
          ),
        ],
      );
      await expectLater(service.apply(plan), throwsA(unsupported));
    },
  );
  test(
    'nested Replace rejects an unmigrated target before reading or writing it',
    () async {
      final data = BookmarkBackupData(
        bookmarks: const [],
        groups: const [
          BookmarkGroupBackup(id: parent, name: 'Parent', bookmarkIds: []),
          BookmarkGroupBackup(
            id: child,
            name: 'Child',
            parentGroupId: parent,
            bookmarkIds: [],
          ),
        ],
      );
      await expectLater(service.replace(data), throwsA(unsupported));
    },
  );
}
