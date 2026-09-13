// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_plan.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_planner.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_service.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';

void main() {
  const groupId = '550e8400-e29b-41d4-a716-446655440000';
  late Directory directory;
  late Box<BookmarkHiveObject> bookmarkBox;
  late Box<BookmarkGroupHiveObject> groupBox;
  late BookmarkHiveRepository bookmarks;
  late BookmarkGroupRepositoryHive groups;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bookmark_import_test_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    bookmarkBox = await Hive.openBox('bookmark_import_bookmarks');
    groupBox = await Hive.openBox('bookmark_import_groups');
    bookmarks = BookmarkHiveRepository(bookmarkBox);
    groups = BookmarkGroupRepositoryHive(groupBox);
  });

  tearDown(() async {
    await bookmarkBox.close();
    await groupBox.close();
    await directory.delete(recursive: true);
  });

  for (final testCase in [
    (choice: BookmarkGroupConflictChoice.merge, expectedMemberships: 2),
    (choice: BookmarkGroupConflictChoice.replace, expectedMemberships: 1),
  ]) {
    test(
      '${testCase.choice.name} uses imported name and expected memberships',
      () async {
        final local = Bookmark.empty.copyWith(
          id: 1,
          originalUrl: 'https://example.com/local.jpg',
        );
        await bookmarks.addBookmarkWithBookmarks([local]);
        final storedLocal = (await _load(bookmarks)).single;
        await groups.createGroup('Local name', id: groupId);
        await groups.addBookmarks(groupId, {storedLocal.id});
        final imported = Bookmark.empty.copyWith(
          id: 200,
          originalUrl: 'https://example.com/imported.jpg',
        );
        final plan = const BookmarkImportPlanner()
            .plan(
              data: BookmarkBackupData(
                bookmarks: [imported],
                groups: const [
                  BookmarkGroupBackup(
                    id: groupId,
                    name: 'Imported name',
                    bookmarkIds: [200],
                  ),
                ],
              ),
              currentBookmarks: [storedLocal],
              currentGroups: await groups.getGroups(),
            )
            .resolve({groupId: testCase.choice});

        await BookmarkImportService(
          bookmarkRepository: bookmarks,
          groupRepository: groups,
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ).apply(plan);

        final group = await groups.getGroup(groupId);
        expect(group?.name, 'Imported name');
        expect(group?.bookmarkIds, hasLength(testCase.expectedMemberships));
        expect(await _load(bookmarks), hasLength(2));
      },
    );
  }
}

Future<List<Bookmark>> _load(BookmarkHiveRepository repository) =>
    repository.getAllBookmarksOrEmpty(
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    );
