// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository.dart';
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

  test('a bookmark read failure never repairs memberships as empty', () async {
    await groupRepository.createGroup('First', id: firstGroupId);
    await groupRepository.addBookmarks(firstGroupId, {99});
    service = BookmarkLibraryService(
      bookmarkRepository: _FailingReadBookmarkRepository(bookmarkBox),
      groupRepository: groupRepository,
      imageUrlResolver: resolver,
    );

    await expectLater(
      service.load(const BookmarkTarget.ungrouped()),
      throwsA(isA<BookmarkRepositoryReadException>()),
    );

    expect((await groupRepository.getGroup(firstGroupId))?.bookmarkIds, {99});
  });

  test('group deletion performs authoritative reads before mutation', () async {
    await groupRepository.createGroup('First', id: firstGroupId);
    await groupRepository.addBookmarks(firstGroupId, {99});
    service = BookmarkLibraryService(
      bookmarkRepository: _FailingReadBookmarkRepository(bookmarkBox),
      groupRepository: groupRepository,
      imageUrlResolver: resolver,
    );

    await expectLater(
      service.deleteGroup(firstGroupId),
      throwsA(isA<BookmarkRepositoryReadException>()),
    );

    expect(await groupRepository.getGroup(firstGroupId), isNotNull);
  });

  test('adds an existing bookmark without creating a duplicate', () async {
    final bookmark = await storeBookmark('existing');
    await groupRepository.createGroup('First', id: firstGroupId);
    var createCalls = 0;

    final changed = await service.addBookmarkToGroup(
      groupId: firstGroupId,
      existingBookmark: bookmark,
      createBookmark: () {
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

  test('moves a grouped bookmark into No Group without deleting it', () async {
    final bookmark = await storeBookmark('move-to-no-group');
    await groupRepository.createGroup('First', id: firstGroupId);
    await groupRepository.addBookmarks(firstGroupId, {bookmark.id});

    await service.moveBookmarkToUngrouped(bookmark);

    final state = await service.load(const BookmarkTarget.ungrouped());
    expect(state.items, [bookmark]);
    expect(state.membershipsFor(bookmark.uniqueId), isEmpty);
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
          createBookmarkIdentity: Bookmark.empty
              .copyWith(originalUrl: 'https://example.com/new.jpg')
              .uniqueId,
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
    'single addition restores memberships after a committed write reports failure',
    () async {
      final bookmark = await storeBookmark('committed-single-add');
      await groupRepository.createGroup('First', id: firstGroupId);
      service = BookmarkLibraryService(
        bookmarkRepository: bookmarkRepository,
        groupRepository: _CommitsThenThrowsAddGroupRepository(groupRepository),
        imageUrlResolver: resolver,
      );

      await expectLater(
        service.addBookmarkToGroup(
          groupId: firstGroupId,
          existingBookmark: bookmark,
        ),
        throwsStateError,
      );

      expect(
        (await groupRepository.getGroup(firstGroupId))?.bookmarkIds,
        isEmpty,
      );
    },
  );

  test(
    'single addition recovers a bookmark whose creation committed before failure',
    () async {
      final source = Bookmark.empty.copyWith(
        originalUrl: 'https://example.com/committed-bookmark-create.jpg',
      );
      await groupRepository.createGroup('First', id: firstGroupId);

      final changed = await service.addBookmarkToGroup(
        groupId: firstGroupId,
        createBookmarkIdentity: source.uniqueId,
        createBookmark: () async {
          await bookmarkRepository.addBookmarkWithBookmarks([source]);
          throw StateError('bookmark creation failed after committing');
        },
      );

      final bookmark = (await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      )).single;
      expect(changed, isTrue);
      expect((await groupRepository.getGroup(firstGroupId))?.bookmarkIds, {
        bookmark.id,
      });
    },
  );

  test(
    'duplication recovers a group whose creation committed before failure',
    () async {
      final bookmark = await storeBookmark('committed-duplicate-create');
      await groupRepository.createGroup('First', id: firstGroupId);
      await groupRepository.addBookmarks(firstGroupId, {bookmark.id});
      service = BookmarkLibraryService(
        bookmarkRepository: bookmarkRepository,
        groupRepository: _CommitsThenThrowsCreateGroupRepository(groupBox),
        imageUrlResolver: resolver,
      );

      final duplicate = await service.duplicateGroup(firstGroupId, 'Copy');

      expect(duplicate.name, 'Copy');
      expect(duplicate.bookmarkIds, {bookmark.id});
      expect(await groupRepository.getGroups(), hasLength(2));
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

  test(
    'cache cleanup failure does not turn a committed deletion into failure',
    () async {
      final bookmark = await storeBookmark('cache-failure');
      await groupRepository.createGroup('First', id: firstGroupId);
      await groupRepository.addBookmarks(firstGroupId, {bookmark.id});
      service = BookmarkLibraryService(
        bookmarkRepository: bookmarkRepository,
        groupRepository: groupRepository,
        imageUrlResolver: resolver,
        clearBookmarkCache: (_) => throw StateError('cache cleanup failed'),
      );

      await service.deleteBookmarks([bookmark]);

      expect(
        (await service.load(const BookmarkTarget.ungrouped())).items,
        isEmpty,
      );
      expect(
        (await groupRepository.getGroup(firstGroupId))?.bookmarkIds,
        isEmpty,
      );
    },
  );

  test(
    'complete deletion restores every membership after a partial failure',
    () async {
      final bookmark = await storeBookmark('partial-delete');
      await groupRepository.createGroup('First', id: firstGroupId);
      final second = await groupRepository.createGroup('Second');
      await groupRepository.addBookmarks(firstGroupId, {bookmark.id});
      await groupRepository.addBookmarks(second.id, {bookmark.id});
      service = BookmarkLibraryService(
        bookmarkRepository: bookmarkRepository,
        groupRepository: _FailingRemoveGroupRepository(
          groupRepository,
          failOnCall: 2,
        ),
        imageUrlResolver: resolver,
      );

      await expectLater(service.deleteBookmarks([bookmark]), throwsStateError);

      expect((await groupRepository.getGroup(firstGroupId))?.bookmarkIds, {
        bookmark.id,
      });
      expect((await groupRepository.getGroup(second.id))?.bookmarkIds, {
        bookmark.id,
      });
      expect(
        (await service.load(const BookmarkTarget.ungrouped())).items,
        [bookmark],
      );
    },
  );

  test(
    'group removal restores the bookmark and membership after a committed deletion reports failure',
    () async {
      final bookmark = await storeBookmark('committed-group-removal');
      await groupRepository.createGroup('First', id: firstGroupId);
      await groupRepository.addBookmarks(firstGroupId, {bookmark.id});
      service = BookmarkLibraryService(
        bookmarkRepository: _CommitsThenThrowsBookmarkRemovalRepository(
          bookmarkBox,
        ),
        groupRepository: groupRepository,
        imageUrlResolver: resolver,
      );

      await expectLater(
        service.removeBookmarksFromGroup(
          [bookmark],
          firstGroupId,
          deleteWhenMembershipBecomesEmpty: true,
        ),
        throwsStateError,
      );

      expect((await groupRepository.getGroup(firstGroupId))?.bookmarkIds, {
        bookmark.id,
      });
      expect(
        await bookmarkRepository.getAllBookmarksOrEmpty(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ),
        [bookmark],
      );
    },
  );

  test(
    'group removal restores membership after a committed membership write reports failure',
    () async {
      final bookmark = await storeBookmark('committed-membership-removal');
      await groupRepository.createGroup('First', id: firstGroupId);
      await groupRepository.addBookmarks(firstGroupId, {bookmark.id});
      service = BookmarkLibraryService(
        bookmarkRepository: bookmarkRepository,
        groupRepository: _CommitsThenThrowsRemoveGroupRepository(
          groupRepository,
        ),
        imageUrlResolver: resolver,
      );

      await expectLater(
        service.removeBookmarksFromGroup([bookmark], firstGroupId),
        throwsStateError,
      );

      expect((await groupRepository.getGroup(firstGroupId))?.bookmarkIds, {
        bookmark.id,
      });
      expect(
        await bookmarkRepository.getAllBookmarksOrEmpty(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ),
        [bookmark],
      );
    },
  );

  test(
    'complete deletion restores records and memberships after a committed deletion reports failure',
    () async {
      final bookmark = await storeBookmark('committed-complete-deletion');
      await groupRepository.createGroup('First', id: firstGroupId);
      await groupRepository.addBookmarks(firstGroupId, {bookmark.id});
      service = BookmarkLibraryService(
        bookmarkRepository: _CommitsThenThrowsBookmarkRemovalRepository(
          bookmarkBox,
        ),
        groupRepository: groupRepository,
        imageUrlResolver: resolver,
      );

      await expectLater(service.deleteBookmarks([bookmark]), throwsStateError);

      expect((await groupRepository.getGroup(firstGroupId))?.bookmarkIds, {
        bookmark.id,
      });
      expect(
        await bookmarkRepository.getAllBookmarksOrEmpty(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ),
        [bookmark],
      );
    },
  );

  test(
    'group deletion restores orphan records after a committed deletion reports failure',
    () async {
      final bookmark = await storeBookmark('committed-group-deletion');
      await groupRepository.createGroup('First', id: firstGroupId);
      await groupRepository.addBookmarks(firstGroupId, {bookmark.id});
      service = BookmarkLibraryService(
        bookmarkRepository: _CommitsThenThrowsBookmarkRemovalRepository(
          bookmarkBox,
        ),
        groupRepository: groupRepository,
        imageUrlResolver: resolver,
      );

      await expectLater(service.deleteGroup(firstGroupId), throwsStateError);

      expect((await groupRepository.getGroup(firstGroupId))?.bookmarkIds, {
        bookmark.id,
      });
      expect(
        await bookmarkRepository.getAllBookmarksOrEmpty(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ),
        [bookmark],
      );
    },
  );

  test(
    'moving to No Group restores every membership after a partial failure',
    () async {
      final bookmark = await storeBookmark('partial-move');
      await groupRepository.createGroup('First', id: firstGroupId);
      final second = await groupRepository.createGroup('Second');
      await groupRepository.addBookmarks(firstGroupId, {bookmark.id});
      await groupRepository.addBookmarks(second.id, {bookmark.id});
      service = BookmarkLibraryService(
        bookmarkRepository: bookmarkRepository,
        groupRepository: _FailingRemoveGroupRepository(
          groupRepository,
          failOnCall: 2,
        ),
        imageUrlResolver: resolver,
      );

      await expectLater(
        service.moveBookmarkToUngrouped(bookmark),
        throwsStateError,
      );

      expect((await groupRepository.getGroup(firstGroupId))?.bookmarkIds, {
        bookmark.id,
      });
      expect((await groupRepository.getGroup(second.id))?.bookmarkIds, {
        bookmark.id,
      });
    },
  );

  test('failed duplication removes the partially created group', () async {
    final bookmark = await storeBookmark('duplicate-rollback');
    await groupRepository.createGroup('First', id: firstGroupId);
    await groupRepository.addBookmarks(firstGroupId, {bookmark.id});
    service = BookmarkLibraryService(
      bookmarkRepository: bookmarkRepository,
      groupRepository: _FailingReplaceGroupRepository(groupRepository),
      imageUrlResolver: resolver,
    );

    await expectLater(
      service.duplicateGroup(firstGroupId, 'Copy'),
      throwsStateError,
    );

    expect(await groupRepository.getGroups(), hasLength(1));
    expect((await groupRepository.getGroup(firstGroupId))?.bookmarkIds, {
      bookmark.id,
    });
  });

  test('a group deletion reports failed membership restoration', () async {
    final bookmark = await storeBookmark('failed-group-restore');
    await groupRepository.createGroup('First', id: firstGroupId);
    await groupRepository.addBookmarks(firstGroupId, {bookmark.id});
    service = BookmarkLibraryService(
      bookmarkRepository: _FailingBookmarkRemovalRepository(bookmarkBox),
      groupRepository: _FailingReplaceGroupRepository(groupRepository),
      imageUrlResolver: resolver,
    );

    await expectLater(
      service.deleteGroup(firstGroupId),
      throwsA(
        isA<BookmarkLibraryRollbackException>()
            .having(
              (error) => error.operationError,
              'operation error',
              isA<StateError>(),
            )
            .having(
              (error) => error.rollbackErrors,
              'rollback errors',
              hasLength(1),
            ),
      ),
    );

    expect(
      (await groupRepository.getGroup(firstGroupId))?.bookmarkIds,
      isEmpty,
    );
  });
}

class _FailingReadBookmarkRepository extends BookmarkHiveRepository {
  const _FailingReadBookmarkRepository(super._box);

  @override
  BookmarksOrError getAllBookmarks({
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  }) => TaskEither.fromEither(Either.left(BookmarkGetError.unknown));
}

class _FailingBookmarkRemovalRepository extends BookmarkHiveRepository {
  const _FailingBookmarkRemovalRepository(super._box);

  @override
  Future<void> removeBookmarks(Iterable<Bookmark> favorites) =>
      throw StateError('bookmark removal failed');
}

class _CommitsThenThrowsBookmarkRemovalRepository
    extends BookmarkHiveRepository {
  const _CommitsThenThrowsBookmarkRemovalRepository(super._box);

  @override
  Future<void> removeBookmarks(Iterable<Bookmark> favorites) async {
    await super.removeBookmarks(favorites);
    throw StateError('bookmark removal reported failure after committing');
  }
}

class _CommitsThenThrowsCreateGroupRepository
    extends BookmarkGroupRepositoryHive {
  _CommitsThenThrowsCreateGroupRepository(super._box);

  @override
  Future<BookmarkGroup> createGroup(String name, {String? id}) async {
    await super.createGroup(name, id: id);
    throw StateError('group creation reported failure after committing');
  }
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
  Future<BookmarkGroup> duplicateGroup(String id, {String? name}) =>
      delegate.duplicateGroup(id, name: name);

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

class _CommitsThenThrowsAddGroupRepository implements BookmarkGroupRepository {
  const _CommitsThenThrowsAddGroupRepository(this.delegate);

  final BookmarkGroupRepository delegate;

  @override
  Future<BookmarkGroup> addBookmarks(String id, Set<int> bookmarkIds) async {
    await delegate.addBookmarks(id, bookmarkIds);
    throw StateError('membership addition reported failure after committing');
  }

  @override
  Future<BookmarkGroup> createGroup(String name, {String? id}) =>
      delegate.createGroup(name, id: id);

  @override
  Future<BookmarkGroupDeletionPreview> deleteGroup(String id) =>
      delegate.deleteGroup(id);

  @override
  Future<BookmarkGroup> duplicateGroup(String id, {String? name}) =>
      delegate.duplicateGroup(id, name: name);

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

class _FailingRemoveGroupRepository implements BookmarkGroupRepository {
  _FailingRemoveGroupRepository(this.delegate, {required this.failOnCall});

  final BookmarkGroupRepository delegate;
  final int failOnCall;
  var _removeCalls = 0;

  @override
  Future<BookmarkGroup> removeBookmarks(String id, Set<int> bookmarkIds) {
    _removeCalls++;
    if (_removeCalls == failOnCall) {
      throw StateError('membership removal failed');
    }
    return delegate.removeBookmarks(id, bookmarkIds);
  }

  @override
  Future<BookmarkGroup> addBookmarks(String id, Set<int> bookmarkIds) =>
      delegate.addBookmarks(id, bookmarkIds);

  @override
  Future<BookmarkGroup> createGroup(String name, {String? id}) =>
      delegate.createGroup(name, id: id);

  @override
  Future<BookmarkGroupDeletionPreview> deleteGroup(String id) =>
      delegate.deleteGroup(id);

  @override
  Future<BookmarkGroup> duplicateGroup(String id, {String? name}) =>
      delegate.duplicateGroup(id, name: name);

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
  Future<void> removeBookmarkFromAllGroups(int bookmarkId) async {
    final first = (await delegate.getGroups()).firstWhere(
      (group) => group.bookmarkIds.contains(bookmarkId),
    );
    await delegate.removeBookmarks(first.id, {bookmarkId});
    throw StateError('remove from all groups failed');
  }

  @override
  Future<BookmarkGroup> renameGroup(String id, String name) =>
      delegate.renameGroup(id, name);

  @override
  Future<BookmarkGroup> replaceMemberships(String id, Set<int> bookmarkIds) =>
      delegate.replaceMemberships(id, bookmarkIds);
}

class _CommitsThenThrowsRemoveGroupRepository
    implements BookmarkGroupRepository {
  const _CommitsThenThrowsRemoveGroupRepository(this.delegate);

  final BookmarkGroupRepository delegate;

  @override
  Future<BookmarkGroup> removeBookmarks(String id, Set<int> bookmarkIds) async {
    await delegate.removeBookmarks(id, bookmarkIds);
    throw StateError('membership removal reported failure after committing');
  }

  @override
  Future<BookmarkGroup> addBookmarks(String id, Set<int> bookmarkIds) =>
      delegate.addBookmarks(id, bookmarkIds);

  @override
  Future<BookmarkGroup> createGroup(String name, {String? id}) =>
      delegate.createGroup(name, id: id);

  @override
  Future<BookmarkGroupDeletionPreview> deleteGroup(String id) =>
      delegate.deleteGroup(id);

  @override
  Future<BookmarkGroup> duplicateGroup(String id, {String? name}) =>
      delegate.duplicateGroup(id, name: name);

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
  Future<BookmarkGroup> renameGroup(String id, String name) =>
      delegate.renameGroup(id, name);

  @override
  Future<BookmarkGroup> replaceMemberships(String id, Set<int> bookmarkIds) =>
      delegate.replaceMemberships(id, bookmarkIds);
}

class _FailingReplaceGroupRepository implements BookmarkGroupRepository {
  const _FailingReplaceGroupRepository(this.delegate);

  final BookmarkGroupRepository delegate;

  @override
  Future<BookmarkGroup> replaceMemberships(String id, Set<int> bookmarkIds) {
    throw StateError('membership replacement failed');
  }

  @override
  Future<BookmarkGroup> addBookmarks(String id, Set<int> bookmarkIds) =>
      delegate.addBookmarks(id, bookmarkIds);

  @override
  Future<BookmarkGroup> createGroup(String name, {String? id}) =>
      delegate.createGroup(name, id: id);

  @override
  Future<BookmarkGroupDeletionPreview> deleteGroup(String id) =>
      delegate.deleteGroup(id);

  @override
  Future<BookmarkGroup> duplicateGroup(String id, {String? name}) =>
      delegate.duplicateGroup(id, name: name);

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
}
