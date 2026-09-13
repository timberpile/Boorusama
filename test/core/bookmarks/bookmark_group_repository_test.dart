// Dart imports:
import 'dart:io';

// Package imports:
import 'package:hive_ce/hive.dart';
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';

void main() {
  late Directory tempDirectory;
  late Box<BookmarkGroupHiveObject> box;
  late BookmarkGroupRepositoryHive repository;

  test('bookmark targets canonicalize group identity and reject bad IDs', () {
    expect(const BookmarkTarget.ungrouped().groupId, isNull);
    expect(
      BookmarkTarget.group(
        '550E8400-E29B-41D4-A716-446655440000',
      ).groupId,
      '550e8400-e29b-41d4-a716-446655440000',
    );
    expect(
      () => BookmarkTarget.group('not-a-guid'),
      throwsFormatException,
    );
  });

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'bookmark_group_repository_test_',
    );
    Hive.init(tempDirectory.path);
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    box = await Hive.openBox<BookmarkGroupHiveObject>('bookmark_groups_test');
    repository = BookmarkGroupRepositoryHive(box);
  });

  tearDown(() async {
    await box.close();
    await tempDirectory.delete(recursive: true);
  });

  test(
    'creates groups with canonical unique IDs and duplicate names',
    () async {
      final first = await repository.createGroup(' Favorites ');
      final second = await repository.createGroup('Favorites');

      expect(first.name, 'Favorites');
      expect(second.name, 'Favorites');
      expect(first.id, isNot(second.id));
      expect(first.id, first.id.toLowerCase());
      expect(first.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
    },
  );

  test('accepts a supplied canonical ID for imported groups', () async {
    final group = await repository.createGroup(
      'Shared',
      id: '550E8400-E29B-41D4-A716-446655440000',
    );

    expect(group.id, '550e8400-e29b-41d4-a716-446655440000');
    expect(box.containsKey(group.id), isTrue);
  });

  final invalidNames = ['', '   '];
  for (final name in invalidNames) {
    test('rejects the empty display name ${name.length}', () {
      expect(() => repository.createGroup(name), throwsFormatException);
    });
  }

  test('rejects malformed supplied IDs', () {
    expect(
      () => repository.createGroup('Shared', id: 'not-a-guid'),
      throwsFormatException,
    );
  });

  test('adds each bookmark membership at most once', () async {
    final group = await repository.createGroup('Saved');

    await repository.addBookmarks(group.id, {10, 11});
    await repository.addBookmarks(group.id, {10});

    expect((await repository.getGroup(group.id))?.bookmarkIds, {10, 11});
  });

  test('duplicates memberships while retaining independent identity', () async {
    final source = await repository.createGroup('Saved');
    await repository.addBookmarks(source.id, {10, 11});

    final duplicate = await repository.duplicateGroup(source.id);
    await repository.removeBookmarks(source.id, {10});

    expect(duplicate.id, isNot(source.id));
    expect(duplicate.name, 'Saved');
    expect((await repository.getGroup(duplicate.id))?.bookmarkIds, {10, 11});
    expect((await repository.getGroup(source.id))?.bookmarkIds, {11});
  });

  test(
    'renames a group without changing its identity or memberships',
    () async {
      final original = await repository.createGroup('Old');
      await repository.addBookmarks(original.id, {20});

      final renamed = await repository.renameGroup(original.id, ' New ');

      expect(renamed.id, original.id);
      expect(renamed.name, 'New');
      expect(renamed.bookmarkIds, {20});
    },
  );

  test('previews and deletes only the requested group', () async {
    final first = await repository.createGroup('First');
    final second = await repository.createGroup('Second');
    await repository.addBookmarks(first.id, {30, 31});
    await repository.addBookmarks(second.id, {31});

    final preview = await repository.previewDeleteGroup(first.id);
    final deleted = await repository.deleteGroup(first.id);

    expect(preview.bookmarkCount, 2);
    expect(preview.orphanBookmarkIds, {30});
    expect(deleted, preview);
    expect(await repository.getGroup(first.id), isNull);
    expect((await repository.getGroup(second.id))?.bookmarkIds, {31});
  });

  test('removes a bookmark from every group', () async {
    final first = await repository.createGroup('First');
    final second = await repository.createGroup('Second');
    await repository.addBookmarks(first.id, {40});
    await repository.addBookmarks(second.id, {40, 41});

    await repository.removeBookmarkFromAllGroups(40);

    expect((await repository.getGroup(first.id))?.bookmarkIds, isEmpty);
    expect((await repository.getGroup(second.id))?.bookmarkIds, {41});
  });

  test('repairs duplicate and stale bookmark references', () async {
    const id = '550e8400-e29b-41d4-a716-446655440000';
    await box.put(
      id,
      BookmarkGroupHiveObject(
        id: id,
        name: 'Imported',
        bookmarkIds: [50, 50, 51, 99],
      ),
    );

    final changed = await repository.repair(validBookmarkIds: {50, 51});

    expect(changed, isTrue);
    expect((await repository.getGroup(id))?.bookmarkIds, {50, 51});
  });
}
