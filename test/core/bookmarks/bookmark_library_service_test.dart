// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';

void main() {
  const firstGroupId = '550e8400-e29b-41d4-a716-446655440000';
  late Directory tempDirectory;
  late Box<BookmarkHiveObject> bookmarkBox;
  late Box<BookmarkGroupHiveObject> groupBox;
  late BookmarkHiveRepository bookmarkRepository;
  late BookmarkGroupRepositoryHive groupRepository;
  late BookmarkLibraryService service;
  late List<int> clearedBookmarkIds;

  ImageUrlResolver resolver(int? _) => const DefaultImageUrlResolver();

  Future<Bookmark> storeBookmark(String path) async {
    await bookmarkRepository.addBookmarkWithBookmarks([
      Bookmark.empty.copyWith(originalUrl: 'https://example.com/$path.jpg'),
    ]);
    return (await service.load(
      const BookmarkTarget.ungrouped(),
    )).items.last;
  }

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'bookmark_library_service_test_',
    );
    Hive.init(tempDirectory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    bookmarkBox = await Hive.openBox<BookmarkHiveObject>('bookmarks_test');
    groupBox = await Hive.openBox<BookmarkGroupHiveObject>('groups_test');
    bookmarkRepository = BookmarkHiveRepository(bookmarkBox);
    groupRepository = BookmarkGroupRepositoryHive(groupBox);
    clearedBookmarkIds = [];
    service = BookmarkLibraryService(
      bookmarkRepository: bookmarkRepository,
      groupRepository: groupRepository,
      imageUrlResolver: resolver,
      clearBookmarkCache: (bookmark) async {
        clearedBookmarkIds.add(bookmark.id);
      },
    );
  });

  tearDown(() async {
    await bookmarkBox.close();
    await groupBox.close();
    await tempDirectory.delete(recursive: true);
  });

  test(
    'loads one repaired snapshot after removing stale memberships',
    () async {
      await groupRepository.createGroup('First', id: firstGroupId);
      await groupRepository.addBookmarks(firstGroupId, {99});

      final state = await service.load(BookmarkTarget.group(firstGroupId));

      expect(state.groups.single.bookmarkIds, isEmpty);
      expect(state.activeTarget.groupId, firstGroupId);
    },
  );

  test('adds an existing bookmark without creating a duplicate', () async {
    final bookmark = await storeBookmark('existing');
    await groupRepository.createGroup('First', id: firstGroupId);
    var createCalls = 0;

    final changed = await service.addBookmarkToGroup(
      groupId: firstGroupId,
      existingBookmark: bookmark,
      createBookmark: () async {
        createCalls++;
        return storeBookmark('duplicate');
      },
    );

    expect(changed, isTrue);
    expect(createCalls, 0);
    expect((await groupRepository.getGroup(firstGroupId))?.bookmarkIds, {
      bookmark.id,
    });
    expect((await service.load(const BookmarkTarget.ungrouped())).items, [
      bookmark,
    ]);
  });

  test(
    'rolls back a newly created bookmark when membership storage fails',
    () async {
      await groupRepository.createGroup('First', id: firstGroupId);
      service = BookmarkLibraryService(
        bookmarkRepository: bookmarkRepository,
        groupRepository: _FailingAddGroupRepository(groupRepository),
        imageUrlResolver: resolver,
      );

      await expectLater(
        service.addBookmarkToGroup(
          groupId: firstGroupId,
          createBookmark: () => storeBookmark('new'),
        ),
        throwsStateError,
      );

      expect(
        (await service.load(const BookmarkTarget.ungrouped())).items,
        isEmpty,
      );
    },
  );

  test(
    'single-post removal deletes the final membership and bookmark',
    () async {
      final bookmark = await storeBookmark('single');
      await groupRepository.createGroup('First', id: firstGroupId);
      await groupRepository.addBookmarks(firstGroupId, {bookmark.id});

      final result = await service.removeBookmarksFromGroup(
        [bookmark],
        firstGroupId,
        deleteWhenMembershipBecomesEmpty: true,
      );

      expect(result.removedCount, 1);
      expect(result.movedToNoGroupCount, 0);
      expect(
        (await service.load(const BookmarkTarget.ungrouped())).items,
        isEmpty,
      );
      expect(clearedBookmarkIds, [bookmark.id]);
    },
  );

  test('bulk removal preserves final memberships in No Group', () async {
    final bookmark = await storeBookmark('bulk');
    await groupRepository.createGroup('First', id: firstGroupId);
    await groupRepository.addBookmarks(firstGroupId, {bookmark.id});

    final result = await service.removeBookmarksFromGroup(
      [bookmark],
      firstGroupId,
    );

    expect(result.removedCount, 1);
    expect(result.movedToNoGroupCount, 1);
    expect(
      (await service.load(const BookmarkTarget.ungrouped())).items,
      [bookmark],
    );
    expect(clearedBookmarkIds, isEmpty);
  });

  test(
    'deleting a group deletes only bookmarks without another group',
    () async {
      final orphan = await storeBookmark('orphan');
      final shared = await storeBookmark('shared');
      await groupRepository.createGroup('First', id: firstGroupId);
      final second = await groupRepository.createGroup('Second');
      await groupRepository.addBookmarks(firstGroupId, {orphan.id, shared.id});
      await groupRepository.addBookmarks(second.id, {shared.id});

      final preview = await service.deleteGroup(firstGroupId);
      final state = await service.load(const BookmarkTarget.ungrouped());

      expect(preview.orphanBookmarkIds, {orphan.id});
      expect(state.items.map((bookmark) => bookmark.id), [shared.id]);
      expect(state.groups.single.bookmarkIds, {shared.id});
      expect(clearedBookmarkIds, [orphan.id]);
    },
  );
}

class _FailingAddGroupRepository implements BookmarkGroupRepository {
  const _FailingAddGroupRepository(this.delegate);

  final BookmarkGroupRepository delegate;

  @override
  Future<BookmarkGroup> addBookmarks(String id, Set<int> bookmarkIds) {
    throw StateError('membership write failed');
  }

  @override
  Future<BookmarkGroup> createGroup(String name, {String? id}) =>
      delegate.createGroup(name, id: id);

  @override
  Future<BookmarkGroupDeletionPreview> deleteGroup(String id) =>
      delegate.deleteGroup(id);

  @override
  Future<BookmarkGroup> duplicateGroup(String id) =>
      delegate.duplicateGroup(id);

  @override
  Future<BookmarkGroup?> getGroup(String id) => delegate.getGroup(id);

  @override
  Future<List<BookmarkGroup>> getGroups() => delegate.getGroups();

  @override
  Future<BookmarkGroupDeletionPreview> previewDeleteGroup(String id) =>
      delegate.previewDeleteGroup(id);

  @override
  Future<bool> repair({required Set<int> validBookmarkIds}) =>
      delegate.repair(validBookmarkIds: validBookmarkIds);

  @override
  Future<void> removeBookmarkFromAllGroups(int bookmarkId) =>
      delegate.removeBookmarkFromAllGroups(bookmarkId);

  @override
  Future<BookmarkGroup> removeBookmarks(String id, Set<int> bookmarkIds) =>
      delegate.removeBookmarks(id, bookmarkIds);

  @override
  Future<BookmarkGroup> renameGroup(String id, String name) =>
      delegate.renameGroup(id, name);

  @override
  Future<BookmarkGroup> replaceMemberships(String id, Set<int> bookmarkIds) =>
      delegate.replaceMemberships(id, bookmarkIds);
}
