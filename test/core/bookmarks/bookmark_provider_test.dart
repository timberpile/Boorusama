// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
