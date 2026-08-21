// Dart imports:
import 'dart:io';

// Package imports:
import 'package:hive_ce/hive.dart';
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_membership_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_browser_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/local_providers.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';

void main() {
  late Directory tempDirectory;
  var boxIndex = 0;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'bookmark_group_repository_test_',
    );
    Hive.init(tempDirectory.path);
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(BookmarkGroupMembershipHiveObjectAdapter());
    }
  });

  tearDownAll(() => tempDirectory.delete(recursive: true));

  Future<BookmarkGroupRepositoryHive> openRepository() async {
    final suffix = boxIndex++;
    final groupsBox = await Hive.openBox<BookmarkGroupHiveObject>(
      'bookmark_groups_test_$suffix',
    );
    final membershipsBox =
        await Hive.openBox<BookmarkGroupMembershipHiveObject>(
          'bookmark_memberships_test_$suffix',
        );

    addTearDown(() async {
      await groupsBox.close();
      await membershipsBox.close();
    });

    return BookmarkGroupRepositoryHive(
      groupsBox: groupsBox,
      membershipsBox: membershipsBox,
    );
  }

  test('existing bookmarks have no memberships until assigned', () async {
    final repository = await openRepository();
    expect(await repository.getMembershipsByBookmark(), isEmpty);
  });

  test(
    'supports multiple memberships and duplicate membership copying',
    () async {
      final repository = await openRepository();
      final first = await repository.createGroup('First');
      final second = await repository.createGroup('Second');

      await repository.addBookmarkToGroup(bookmarkId: 10, groupId: first.id);
      await repository.addBookmarkToGroup(bookmarkId: 10, groupId: second.id);

      final duplicate = await repository.duplicateGroup(first.id);
      expect(duplicate.name, 'First (2)');
      expect(await repository.getBookmarkIdsForGroup(duplicate.id), {10});
      expect(
        await repository.getMembershipsByBookmark(),
        {
          10: {first.id, second.id, duplicate.id},
        },
      );
    },
  );

  test(
    'deleting final membership reports an orphan without deleting it',
    () async {
      final repository = await openRepository();
      final group = await repository.createGroup('Only group');
      await repository.addBookmarkToGroup(bookmarkId: 20, groupId: group.id);

      final preview = await repository.previewDeleteGroup(group.id);
      expect(preview, isA<BookmarkGroupDeletionPreview>());
      expect(preview.bookmarkCount, 1);
      expect(await repository.deleteGroup(group.id), {20});
      expect(await repository.getMembershipsByBookmark(), isEmpty);
    },
  );

  test('deleting one group preserves memberships in another group', () async {
    final repository = await openRepository();
    final first = await repository.createGroup('First');
    final second = await repository.createGroup('Second');
    await repository.addBookmarkToGroup(bookmarkId: 30, groupId: first.id);
    await repository.addBookmarkToGroup(bookmarkId: 30, groupId: second.id);

    expect(await repository.deleteGroup(first.id), isEmpty);
    expect(await repository.getBookmarkIdsForGroup(second.id), {30});
  });

  test('complete membership removal removes every group link', () async {
    final repository = await openRepository();
    final first = await repository.createGroup('First');
    final second = await repository.createGroup('Second');
    await repository.addBookmarkToGroup(bookmarkId: 40, groupId: first.id);
    await repository.addBookmarkToGroup(bookmarkId: 40, groupId: second.id);

    await repository.removeBookmarkFromAllGroups(40);
    expect(await repository.getMembershipsByBookmark(), isEmpty);
  });

  test('prunes memberships for missing bookmarks', () async {
    final repository = await openRepository();
    final group = await repository.createGroup('First');
    await repository.addBookmarkToGroup(bookmarkId: 50, groupId: group.id);
    await repository.addBookmarkToGroup(bookmarkId: 51, groupId: group.id);

    await repository.pruneStaleMemberships(bookmarkIds: {50});
    expect(await repository.getBookmarkIdsForGroup(group.id), {50});
  });

  test('filters all, ungrouped, and named bookmark views', () {
    final bookmarks = [
      Bookmark.empty.copyWith(id: 1),
      Bookmark.empty.copyWith(id: 2),
      Bookmark.empty.copyWith(id: 3),
    ];

    expect(
      filterBookmarks(
        bookmarks: bookmarks,
        selectedTags: const [],
        sortType: BookmarkSortType.oldest,
      ).map((bookmark) => bookmark.id),
      [1, 2, 3],
    );
    expect(
      filterBookmarks(
        bookmarks: bookmarks,
        selectedTags: const [],
        sortType: BookmarkSortType.oldest,
        membershipsByBookmark: const {
          1: {7},
          3: {8},
        },
        selectedBookmarkGroupId: -1,
      ).map((bookmark) => bookmark.id),
      [2],
    );
    expect(
      filterBookmarks(
        bookmarks: bookmarks,
        selectedTags: const [],
        sortType: BookmarkSortType.oldest,
        membershipsByBookmark: const {
          1: {7},
          3: {8},
        },
        selectedBookmarkGroupId: 8,
      ).map((bookmark) => bookmark.id),
      [3],
    );
  });

  test(
    'uses the first four bookmarks from a sorted group view as previews',
    () {
      final bookmarks = List.generate(
        6,
        (index) => Bookmark.empty.copyWith(
          id: index + 1,
          createdAt: DateTime(2026, 1, index + 1),
        ),
      );

      expect(
        getBookmarkGroupPreviews(
          bookmarks: bookmarks,
          sortType: BookmarkSortType.oldest,
          membershipsByBookmark: const {
            1: {7},
            2: {7},
            3: {7},
            4: {7},
            5: {7},
          },
          selectedBookmarkGroupId: 7,
        ).map((bookmark) => bookmark.id),
        [1, 2, 3, 4],
      );
    },
  );
}
