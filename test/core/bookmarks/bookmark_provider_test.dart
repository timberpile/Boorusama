// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';

void main() {
  const groupId = '550e8400-e29b-41d4-a716-446655440000';
  late Directory tempDirectory;
  late Box<BookmarkHiveObject> bookmarkBox;
  late Box<BookmarkGroupHiveObject> groupBox;
  late BookmarkHiveRepository bookmarkRepository;
  late BookmarkGroupRepositoryHive groupRepository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'bookmark_provider_test_',
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
  });

  tearDown(() async {
    await bookmarkBox.close();
    await groupBox.close();
    await tempDirectory.delete(recursive: true);
  });

  ProviderContainer createContainer({
    SettingsNotifier? settingsNotifier,
    BookmarkRepository? bookmarkRepositoryOverride,
    BookmarkGroupRepository? groupRepositoryOverride,
  }) {
    final container = ProviderContainer(
      overrides: [
        bookmarkRepoProvider.overrideWith(
          (ref) => bookmarkRepositoryOverride ?? bookmarkRepository,
        ),
        bookmarkGroupRepoProvider.overrideWith(
          (ref) => groupRepositoryOverride ?? groupRepository,
        ),
        bookmarkUrlResolverProvider.overrideWith(
          (ref, booruId) => const DefaultImageUrlResolver(),
        ),
        bookmarkImageCacheManagerProvider.overrideWithValue(null),
        settingsNotifierProvider.overrideWith(
          () =>
              settingsNotifier ??
              _TestSettingsNotifier(Settings.defaultSettings),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'adding to No Group never clears existing named memberships',
    () async {
      final bookmark = Bookmark.empty.copyWith(
        originalUrl: 'https://example.com/grouped.jpg',
      );
      await bookmarkRepository.addBookmarkWithBookmarks([bookmark]);
      final stored = (await bookmarkRepository.getAllBookmarksOrEmpty(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      )).single;
      await groupRepository.createGroup('Shared', id: groupId);
      await groupRepository.addBookmarks(groupId, {stored.id});
      final container = createContainer();
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;

      await notifier.addBookmark(
        BooruConfigAuth.fromConfig(
          BooruConfig.empty.copyWith(booruIdHint: stored.booruId),
        ),
        stored.toPost(),
      );

      expect((await groupRepository.getGroup(groupId))?.bookmarkIds, {
        stored.id,
      });
      expect(
        await bookmarkRepository.getAllBookmarksOrEmpty(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ),
        hasLength(1),
      );
    },
  );

  test('removing from a group view preserves every other membership', () async {
    final bookmark = Bookmark.empty.copyWith(
      originalUrl: 'https://example.com/shared.jpg',
    );
    await bookmarkRepository.addBookmarkWithBookmarks([bookmark]);
    final stored = (await bookmarkRepository.getAllBookmarksOrEmpty(
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    )).single;
    await groupRepository.createGroup('First', id: groupId);
    final second = await groupRepository.createGroup('Second');
    await groupRepository.addBookmarks(groupId, {stored.id});
    await groupRepository.addBookmarks(second.id, {stored.id});
    final container = createContainer();
    final notifier = container.read(bookmarkProvider.notifier);
    await notifier.future;

    await notifier.removeBookmarkFromView(
      stored,
      BookmarkView.group(groupId),
    );

    expect((await groupRepository.getGroup(groupId))?.bookmarkIds, isEmpty);
    expect((await groupRepository.getGroup(second.id))?.bookmarkIds, {
      stored.id,
    });
    expect(
      await bookmarkRepository.getAllBookmarksOrEmpty(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      ),
      hasLength(1),
    );
  });

  test('bulk removal resolves stored identities for bookmark posts', () async {
    final bookmark = Bookmark.empty.copyWith(
      originalUrl: 'https://example.com/other-booru.jpg',
    );
    await bookmarkRepository.addBookmarkWithBookmarks([bookmark]);
    final stored = (await bookmarkRepository.getAllBookmarksOrEmpty(
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    )).single;
    await groupRepository.createGroup('First', id: groupId);
    await groupRepository.addBookmarks(groupId, {stored.id});
    final container = createContainer();
    final notifier = container.read(bookmarkProvider.notifier);
    await notifier.future;

    final result = await notifier.removePostsFromGroup(
      BooruConfigAuth.fromConfig(
        BooruConfig.empty.copyWith(booruIdHint: stored.booruId + 100),
      ),
      [stored.toPost()],
      groupId,
    );

    expect(result.removedCount, 1);
    expect((await groupRepository.getGroup(groupId))?.bookmarkIds, isEmpty);
  });

  test(
    'active target publishes the newly persisted group deterministically',
    () async {
      await groupRepository.createGroup('Target', id: groupId);
      final container = createContainer();
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;

      final saved = await notifier.setActiveTarget(
        BookmarkTarget.group(groupId),
      );

      expect(saved, isTrue);
      expect(
        container.read(bookmarkProvider).value?.activeTarget.groupId,
        groupId,
      );
      expect(
        container.read(settingsProvider).activeBookmarkGroupId,
        groupId,
      );
    },
  );

  test('an export snapshot waits for preceding bookmark mutations', () async {
    final container = createContainer();
    final notifier = container.read(bookmarkProvider.notifier);
    await notifier.future;
    final blocker = Completer<void>();
    final bookmark = Bookmark.empty.copyWith(
      originalUrl: 'https://example.com/queued.jpg',
    );

    final mutation = notifier.runSerializedMutation(() async {
      await blocker.future;
      await bookmarkRepository.addBookmarkWithBookmarks([bookmark]);
    });
    var snapshotCompleted = false;
    final snapshot = notifier.snapshotForExport().then((value) {
      snapshotCompleted = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);

    expect(snapshotCompleted, isFalse);
    blocker.complete();
    await mutation;
    expect((await snapshot).items.single.originalUrl, bookmark.originalUrl);
  });

  test(
    'settings synchronization publishes the persisted active group',
    () async {
      await groupRepository.createGroup('Imported target', id: groupId);
      final container = createContainer();
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;
      await container
          .read(settingsNotifierProvider.notifier)
          .updateWith(
            (settings) => settings.copyWith(activeBookmarkGroupId: groupId),
          );

      await notifier.syncActiveTargetFromSettings();

      expect((await notifier.future).activeTarget.groupId, groupId);
    },
  );

  test(
    'a group is removed when its requested activation cannot be saved',
    () async {
      final container = createContainer(
        settingsNotifier: _FailingSettingsNotifier(Settings.defaultSettings),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;

      await expectLater(
        notifier.createGroup('Unsaved', activate: true),
        throwsStateError,
      );

      expect(await groupRepository.getGroups(), isEmpty);
    },
  );

  test(
    'creating a group rolls back when a new bookmark cannot be stored',
    () async {
      final container = createContainer(
        bookmarkRepositoryOverride: _FailingAddBookmarkRepository(bookmarkBox),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;
      final post = Bookmark.empty
          .copyWith(originalUrl: 'https://example.com/new.jpg')
          .toPost();
      final config = BooruConfigAuth.fromConfig(
        BooruConfig.empty.copyWith(booruIdHint: post.bookmark.booruId),
      );

      await expectLater(
        notifier.createGroupWithPosts('Atomic', config, [post]),
        throwsStateError,
      );

      expect(await groupRepository.getGroups(), isEmpty);
      expect(container.read(settingsProvider).activeBookmarkGroupId, isNull);
    },
  );

  test(
    'creating a group preserves an existing bookmark when assignment fails',
    () async {
      final source = Bookmark.empty.copyWith(
        originalUrl: 'https://example.com/existing.jpg',
      );
      await bookmarkRepository.addBookmarkWithBookmarks([source]);
      final stored = (await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      )).single;
      final container = createContainer(
        groupRepositoryOverride: _FailingMembershipGroupRepository(groupBox),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;
      final config = BooruConfigAuth.fromConfig(
        BooruConfig.empty.copyWith(booruIdHint: stored.booruId),
      );

      await expectLater(
        notifier.createGroupWithPosts('Atomic', config, [stored.toPost()]),
        throwsStateError,
      );

      expect(await groupRepository.getGroups(), isEmpty);
      expect(
        await bookmarkRepository.getAllBookmarksOrThrow(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ),
        [stored],
      );
    },
  );

  test(
    'creating a group removes a new bookmark when publishing fails',
    () async {
      final container = createContainer(
        bookmarkRepositoryOverride: _FailingSecondReadBookmarkRepository(
          bookmarkBox,
        ),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;
      final post = Bookmark.empty
          .copyWith(originalUrl: 'https://example.com/rollback.jpg')
          .toPost();
      final config = BooruConfigAuth.fromConfig(
        BooruConfig.empty.copyWith(booruIdHint: post.bookmark.booruId),
      );

      await expectLater(
        notifier.createGroupWithPosts('Atomic', config, [post]),
        throwsA(isA<BookmarkRepositoryReadException>()),
      );

      expect(await groupRepository.getGroups(), isEmpty);
      expect(
        await bookmarkRepository.getAllBookmarksOrThrow(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ),
        isEmpty,
      );
      expect(container.read(settingsProvider).activeBookmarkGroupId, isNull);
    },
  );

  test(
    'creating a group reports a failed active target rollback',
    () async {
      final container = createContainer(
        settingsNotifier: _FailsSecondSettingsUpdateNotifier(
          Settings.defaultSettings,
        ),
        groupRepositoryOverride: _FailingMembershipGroupRepository(groupBox),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;
      final post = Bookmark.empty
          .copyWith(originalUrl: 'https://example.com/settings-rollback.jpg')
          .toPost();
      final config = BooruConfigAuth.fromConfig(
        BooruConfig.empty.copyWith(booruIdHint: post.bookmark.booruId),
      );

      await expectLater(
        notifier.createGroupWithPosts('Atomic', config, [post]),
        throwsA(
          isA<BookmarkGroupCreationRollbackException>().having(
            (error) => error.rollbackErrors,
            'rollback errors',
            hasLength(1),
          ),
        ),
      );

      expect(await groupRepository.getGroups(), isEmpty);
      expect(
        await bookmarkRepository.getAllBookmarksOrThrow(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ),
        isEmpty,
      );
    },
  );
}

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier(super.initialSettings);

  @override
  Future<bool> updateWith(Settings Function(Settings) selector) async {
    state = selector(state);
    return true;
  }
}

class _FailingSettingsNotifier extends SettingsNotifier {
  _FailingSettingsNotifier(super.initialSettings);

  @override
  Future<bool> updateWith(Settings Function(Settings) selector) async => false;
}

class _FailsSecondSettingsUpdateNotifier extends SettingsNotifier {
  _FailsSecondSettingsUpdateNotifier(super.initialSettings);

  var _updateCount = 0;

  @override
  Future<bool> updateWith(Settings Function(Settings) selector) async {
    _updateCount++;
    if (_updateCount == 2) return false;
    state = selector(state);
    return true;
  }
}

class _FailingAddBookmarkRepository extends BookmarkHiveRepository {
  const _FailingAddBookmarkRepository(super._box);

  @override
  Future<Bookmark> addBookmark(
    int booruId,
    Post post, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator Function(int? booruId) postLinkGenerator,
  }) => throw StateError('bookmark write failed');
}

class _FailingMembershipGroupRepository extends BookmarkGroupRepositoryHive {
  _FailingMembershipGroupRepository(super._box);

  @override
  Future<BookmarkGroup> addBookmarks(String groupId, Set<int> bookmarkIds) =>
      throw StateError('membership write failed');
}

class _FailingSecondReadBookmarkRepository extends BookmarkHiveRepository {
  _FailingSecondReadBookmarkRepository(super._box);

  var _readCount = 0;

  @override
  Future<Bookmark> addBookmark(
    int booruId,
    Post post, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator Function(int? booruId) postLinkGenerator,
  }) async {
    final bookmark = switch (post) {
      BookmarkPost(:final bookmark) => bookmark,
      _ => throw StateError('Expected a stored bookmark post.'),
    };
    return (await addBookmarkWithBookmarks([bookmark])).single;
  }

  @override
  BookmarksOrError getAllBookmarks({
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  }) {
    _readCount++;
    if (_readCount == 2) {
      return TaskEither.left(BookmarkGetError.unknown);
    }
    return super.getAllBookmarks(imageUrlResolver: imageUrlResolver);
  }
}
