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
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
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

  test('a missing group cannot become the active target', () async {
    final container = createContainer();
    final notifier = container.read(bookmarkProvider.notifier);
    await notifier.future;

    final saved = await notifier.setActiveTarget(
      BookmarkTarget.group('550e8400-e29b-41d4-a716-446655440999'),
    );

    expect(saved, isFalse);
    expect(container.read(settingsProvider).activeBookmarkGroupId, isNull);
    expect(
      container.read(bookmarkProvider).requireValue.activeTarget.groupId,
      isNull,
    );
  });

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
        BooruConfig.empty.copyWith(
          booruIdHint: post.origin.booruType.id,
        ),
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
    'creating a group with posts stays committed when publishing fails',
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
        BooruConfig.empty.copyWith(
          booruIdHint: post.origin.booruType.id,
        ),
      );

      final result = await notifier.createGroupWithPosts('Atomic', config, [
        post,
      ]);

      final bookmarks = await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      );
      expect(result.addedCount, 1);
      expect(bookmarks, hasLength(1));
      expect(
        (await groupRepository.getGroup(result.group.id))?.bookmarkIds,
        {bookmarks.single.id},
      );
      expect(
        container.read(settingsProvider).activeBookmarkGroupId,
        result.group.id,
      );
      expect(container.read(bookmarkProvider).hasValue, isTrue);
      expect(
        (await notifier.snapshotForExport()).groupsById,
        contains(result.group.id),
      );
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
        BooruConfig.empty.copyWith(
          booruIdHint: post.origin.booruType.id,
        ),
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

  test(
    'setting target membership repeatedly preserves the desired state',
    () async {
      final source = Bookmark.empty.copyWith(
        originalUrl: 'https://example.com/idempotent.jpg',
      );
      await bookmarkRepository.addBookmarkWithBookmarks([source]);
      final stored = (await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      )).single;
      final group = await groupRepository.createGroup('Idempotent');
      final target = BookmarkTarget.group(group.id);
      final container = createContainer();
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;
      final config = BooruConfigAuth.fromConfig(
        BooruConfig.empty.copyWith(booruIdHint: stored.booruId),
      );

      for (var i = 0; i < 2; i++) {
        expect(
          await notifier.setPostTargetMembership(
            config,
            source.toPost(),
            target: target,
            bookmarked: true,
          ),
          BookmarkToggleOutcome.added,
        );
      }
      expect((await groupRepository.getGroup(group.id))?.bookmarkIds, {
        stored.id,
      });

      for (var i = 0; i < 2; i++) {
        expect(
          await notifier.setPostTargetMembership(
            config,
            source.toPost(),
            target: target,
            bookmarked: false,
          ),
          BookmarkToggleOutcome.removed,
        );
      }
      expect((await groupRepository.getGroup(group.id))?.bookmarkIds, isEmpty);
      expect(
        await bookmarkRepository.getAllBookmarksOrEmpty(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ),
        isEmpty,
      );
    },
  );

  test('two queued toggles apply both intents in order', () async {
    final source = Bookmark.empty.copyWith(
      originalUrl: 'https://example.com/toggle.jpg',
    );
    await bookmarkRepository.addBookmarkWithBookmarks([source]);
    final stored = (await bookmarkRepository.getAllBookmarksOrThrow(
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    )).single;
    final active = await groupRepository.createGroup('Active');
    final other = await groupRepository.createGroup('Other');
    await groupRepository.addBookmarks(other.id, {stored.id});
    final settings = Settings.defaultSettings.copyWith(
      activeBookmarkGroupId: active.id,
    );
    final container = createContainer(
      settingsNotifier: _TestSettingsNotifier(settings),
    );
    final notifier = container.read(bookmarkProvider.notifier);
    await notifier.future;
    final config = BooruConfigAuth.fromConfig(
      BooruConfig.empty.copyWith(booruIdHint: stored.booruId),
    );

    final outcomes = await Future.wait([
      notifier.togglePostTarget(config, stored.toPost()),
      notifier.togglePostTarget(config, stored.toPost()),
    ]);

    expect(outcomes, [
      BookmarkToggleOutcome.added,
      BookmarkToggleOutcome.removed,
    ]);
    expect((await groupRepository.getGroup(active.id))?.bookmarkIds, isEmpty);
    expect((await groupRepository.getGroup(other.id))?.bookmarkIds, {
      stored.id,
    });
  });

  test('No Group reports unavailable for a grouped bookmark', () async {
    final source = Bookmark.empty.copyWith(
      originalUrl: 'https://example.com/unavailable.jpg',
    );
    await bookmarkRepository.addBookmarkWithBookmarks([source]);
    final stored = (await bookmarkRepository.getAllBookmarksOrThrow(
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    )).single;
    final group = await groupRepository.createGroup('Named');
    await groupRepository.addBookmarks(group.id, {stored.id});
    final container = createContainer();
    final notifier = container.read(bookmarkProvider.notifier);
    await notifier.future;
    final config = BooruConfigAuth.fromConfig(
      BooruConfig.empty.copyWith(booruIdHint: stored.booruId),
    );

    final outcome = await notifier.togglePostTarget(config, stored.toPost());

    expect(outcome, BookmarkToggleOutcome.unavailable);
    expect((await groupRepository.getGroup(group.id))?.bookmarkIds, {
      stored.id,
    });
  });

  test(
    'a stale No Group action never deletes a newly grouped bookmark',
    () async {
      final source = Bookmark.empty.copyWith(
        originalUrl: 'https://example.com/stale-picker.jpg',
      );
      await bookmarkRepository.addBookmarkWithBookmarks([source]);
      final stored = (await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      )).single;
      final group = await groupRepository.createGroup('New membership');
      final container = createContainer(
        bookmarkRepositoryOverride: _FailingSecondReadBookmarkRepository(
          bookmarkBox,
        ),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;
      await notifier.addExistingBookmarkToGroup(stored, group.id);

      final outcome = await notifier.togglePostTarget(
        BooruConfigAuth.fromConfig(
          BooruConfig.empty.copyWith(booruIdHint: stored.booruId),
        ),
        stored.toPost(),
        target: const BookmarkTarget.ungrouped(),
        activateTarget: true,
      );

      expect(outcome, BookmarkToggleOutcome.unavailable);
      expect((await groupRepository.getGroup(group.id))?.bookmarkIds, {
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

  test(
    'a stale No Group edit removal preserves a newly grouped bookmark',
    () async {
      final source = Bookmark.empty.copyWith(
        originalUrl: 'https://example.com/stale-edit.jpg',
      );
      await bookmarkRepository.addBookmarkWithBookmarks([source]);
      final stored = (await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      )).single;
      final group = await groupRepository.createGroup('New membership');
      final container = createContainer(
        bookmarkRepositoryOverride: _FailingSecondReadBookmarkRepository(
          bookmarkBox,
        ),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;
      await notifier.addExistingBookmarkToGroup(stored, group.id);
      var succeeded = false;
      var failed = false;

      await notifier.removeBookmarkFromView(
        stored,
        const BookmarkView.ungrouped(),
        onSuccess: () => succeeded = true,
        onError: () => failed = true,
      );

      expect(succeeded, isFalse);
      expect(failed, isTrue);
      expect((await groupRepository.getGroup(group.id))?.bookmarkIds, {
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

  test(
    'bulk creation rolls back earlier bookmarks after a later failure',
    () async {
      final failingRepository = _FailsSecondAddBookmarkRepository(bookmarkBox);
      final container = createContainer(
        bookmarkRepositoryOverride: failingRepository,
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;
      final posts = [
        Bookmark.empty
            .copyWith(originalUrl: 'https://example.com/one.jpg')
            .toPost(),
        Bookmark.empty
            .copyWith(originalUrl: 'https://example.com/two.jpg')
            .toPost(),
      ];
      final config = BooruConfigAuth.fromConfig(BooruConfig.empty);

      await expectLater(
        notifier.addPostsToGroup(config, posts, null),
        throwsStateError,
      );

      expect(
        await bookmarkRepository.getAllBookmarksOrThrow(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ),
        isEmpty,
      );
    },
  );

  test(
    'bulk group creation retries cleanup exposed by an inner failure',
    () async {
      final container = createContainer(
        bookmarkRepositoryOverride: _FailsSecondAddAndFirstCleanupRepository(
          bookmarkBox,
        ),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;
      final posts = [
        Bookmark.empty
            .copyWith(originalUrl: 'https://example.com/retry-first.jpg')
            .toPost(),
        Bookmark.empty
            .copyWith(originalUrl: 'https://example.com/retry-second.jpg')
            .toPost(),
      ];

      await expectLater(
        notifier.createGroupWithPosts(
          'Retry cleanup',
          BooruConfigAuth.fromConfig(BooruConfig.empty),
          posts,
        ),
        throwsA(isA<BookmarkPostBatchRollbackException>()),
      );

      expect(await groupRepository.getGroups(), isEmpty);
      expect(
        await bookmarkRepository.getAllBookmarksOrEmpty(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ),
        isEmpty,
      );
      expect(container.read(settingsProvider).activeBookmarkGroupId, isNull);
    },
  );

  test(
    'bulk addition restores exact memberships after a committed write reports failure',
    () async {
      final source = Bookmark.empty.copyWith(
        originalUrl: 'https://example.com/existing-bulk-add.jpg',
      );
      await bookmarkRepository.addBookmarkWithBookmarks([source]);
      final stored = (await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      )).single;
      final group = await groupRepository.createGroup('Target');
      final container = createContainer(
        bookmarkRepositoryOverride: _BookmarkPostRepository(bookmarkBox),
        groupRepositoryOverride: _CommitsThenThrowsAddGroupRepository(
          groupBox,
        ),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;
      final posts = [
        stored.toPost(),
        Bookmark.empty
            .copyWith(originalUrl: 'https://example.com/new-bulk-add.jpg')
            .toPost(),
      ];

      await expectLater(
        notifier.addPostsToGroup(
          BooruConfigAuth.fromConfig(BooruConfig.empty),
          posts,
          group.id,
        ),
        throwsStateError,
      );

      expect((await groupRepository.getGroup(group.id))?.bookmarkIds, isEmpty);
      expect(
        await bookmarkRepository.getAllBookmarksOrThrow(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ),
        [stored],
      );
    },
  );

  test(
    'existing bookmark addition restores memberships after a committed write reports failure',
    () async {
      final source = Bookmark.empty.copyWith(
        originalUrl: 'https://example.com/existing-committed-add.jpg',
      );
      await bookmarkRepository.addBookmarkWithBookmarks([source]);
      final stored = (await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      )).single;
      final group = await groupRepository.createGroup('Target');
      final container = createContainer(
        groupRepositoryOverride: _CommitsThenThrowsAddGroupRepository(
          groupBox,
        ),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;
      var failed = false;

      await notifier.addExistingBookmarksToGroup(
        [stored],
        group.id,
        onError: () => failed = true,
      );

      expect(failed, isTrue);
      expect((await groupRepository.getGroup(group.id))?.bookmarkIds, isEmpty);
    },
  );

  test(
    'an active group is not deleted when clearing its target fails',
    () async {
      final group = await groupRepository.createGroup('Protected');
      final settings = Settings.defaultSettings.copyWith(
        activeBookmarkGroupId: group.id,
      );
      final container = createContainer(
        settingsNotifier: _FailingSettingsNotifier(settings),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;

      await expectLater(notifier.deleteGroup(group.id), throwsStateError);

      expect(await groupRepository.getGroup(group.id), group);
      expect(container.read(settingsProvider).activeBookmarkGroupId, group.id);
    },
  );

  test(
    'a committed deletion succeeds and keeps its cleared target when publishing fails',
    () async {
      final group = await groupRepository.createGroup('Committed');
      final settings = Settings.defaultSettings.copyWith(
        activeBookmarkGroupId: group.id,
      );
      final container = createContainer(
        settingsNotifier: _TestSettingsNotifier(settings),
        bookmarkRepositoryOverride: _FailingThirdReadBookmarkRepository(
          bookmarkBox,
        ),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;

      final preview = await notifier.deleteGroup(group.id);

      expect(preview.group.id, group.id);
      expect(await groupRepository.getGroup(group.id), isNull);
      expect(container.read(settingsProvider).activeBookmarkGroupId, isNull);
      expect(container.read(bookmarkProvider).hasValue, isTrue);
      expect(
        (await notifier.snapshotForExport()).groupsById,
        isNot(contains(group.id)),
      );
    },
  );

  test('a committed group delete error is reconciled as success', () async {
    final group = await groupRepository.createGroup('Committed delete');
    final settings = Settings.defaultSettings.copyWith(
      activeBookmarkGroupId: group.id,
    );
    final container = createContainer(
      settingsNotifier: _TestSettingsNotifier(settings),
      groupRepositoryOverride: _CommitsThenThrowsDeleteGroupRepository(
        groupBox,
      ),
    );
    final notifier = container.read(bookmarkProvider.notifier);
    await notifier.future;

    final preview = await notifier.deleteGroup(group.id);

    expect(preview.group.id, group.id);
    expect(await groupRepository.getGroup(group.id), isNull);
    expect(container.read(settingsProvider).activeBookmarkGroupId, isNull);
  });

  test(
    'a committed group creation returns its group when publishing fails',
    () async {
      final container = createContainer(
        bookmarkRepositoryOverride: _FailingSecondReadBookmarkRepository(
          bookmarkBox,
        ),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;

      final created = await notifier.createGroup('Created once');

      expect(
        (await groupRepository.getGroup(created.id))?.name,
        'Created once',
      );
      expect(await groupRepository.getGroups(), hasLength(1));
      expect(container.read(bookmarkProvider).hasValue, isTrue);
      expect(
        (await notifier.snapshotForExport()).groupsById,
        contains(created.id),
      );
    },
  );

  test('a committed group creation is reconciled as success', () async {
    final container = createContainer(
      groupRepositoryOverride: _CommitsThenThrowsCreateGroupRepository(
        groupBox,
      ),
    );
    final notifier = container.read(bookmarkProvider.notifier);
    await notifier.future;

    final created = await notifier.createGroup('Committed create');

    expect(created.name, 'Committed create');
    expect(await groupRepository.getGroups(), [created]);
  });

  test(
    'group creation recovers committed group and bookmark writes',
    () async {
      final container = createContainer(
        bookmarkRepositoryOverride: _CommitsThenThrowsAddBookmarkRepository(
          bookmarkBox,
        ),
        groupRepositoryOverride: _CommitsThenThrowsCreateGroupRepository(
          groupBox,
        ),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;
      final post = Bookmark.empty
          .copyWith(originalUrl: 'https://example.com/committed-both.jpg')
          .toPost();

      final result = await notifier.createGroupWithPosts(
        'Committed writes',
        BooruConfigAuth.fromConfig(BooruConfig.empty),
        [post],
      );

      final bookmark = (await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      )).single;
      expect(result.addedCount, 1);
      expect((await groupRepository.getGroup(result.group.id))?.bookmarkIds, {
        bookmark.id,
      });
    },
  );

  test(
    'a committed group duplication returns its group when publishing fails',
    () async {
      final source = await groupRepository.createGroup('Source');
      final container = createContainer(
        bookmarkRepositoryOverride: _FailingSecondReadBookmarkRepository(
          bookmarkBox,
        ),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;

      final duplicate = await notifier.duplicateGroup(source.id, 'Copy');

      expect((await groupRepository.getGroup(duplicate.id))?.name, 'Copy');
      expect(await groupRepository.getGroups(), hasLength(2));
      expect(container.read(bookmarkProvider).hasValue, isTrue);
      expect(
        (await notifier.snapshotForExport()).groupsById,
        contains(duplicate.id),
      );
    },
  );

  test(
    'a committed bookmark add reports success when publishing fails',
    () async {
      final container = createContainer(
        bookmarkRepositoryOverride: _FailingSecondReadBookmarkRepository(
          bookmarkBox,
        ),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;
      var succeeded = false;
      var failed = false;

      await notifier.addBookmark(
        BooruConfigAuth.fromConfig(BooruConfig.empty),
        Bookmark.empty
            .copyWith(originalUrl: 'https://example.com/committed.jpg')
            .toPost(),
        onSuccess: () => succeeded = true,
        onError: () => failed = true,
      );

      expect(succeeded, isTrue);
      expect(failed, isFalse);
      expect(
        await bookmarkRepository.getAllBookmarksOrEmpty(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ),
        hasLength(1),
      );
    },
  );

  test('a stale deletion preview cannot delete changed memberships', () async {
    final bookmark = Bookmark.empty.copyWith(
      originalUrl: 'https://example.com/changed.jpg',
    );
    await bookmarkRepository.addBookmarkWithBookmarks([bookmark]);
    final stored = (await bookmarkRepository.getAllBookmarksOrThrow(
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    )).single;
    final group = await groupRepository.createGroup('Changed');
    await groupRepository.addBookmarks(group.id, {stored.id});
    final container = createContainer();
    final notifier = container.read(bookmarkProvider.notifier);
    await notifier.future;

    await expectLater(
      notifier.deleteGroup(
        group.id,
        expectedPreview: BookmarkGroupDeletionPreview(
          group: group.copyWith(bookmarkIds: const {}),
          orphanBookmarkIds: const {},
        ),
      ),
      throwsA(isA<BookmarkGroupChangedException>()),
    );

    expect((await groupRepository.getGroup(group.id))?.bookmarkIds, {
      stored.id,
    });
  });

  test(
    'a stale orphan preview cannot delete a newly orphaned bookmark',
    () async {
      final bookmark = Bookmark.empty.copyWith(
        originalUrl: 'https://example.com/topology.jpg',
      );
      await bookmarkRepository.addBookmarkWithBookmarks([bookmark]);
      final stored = (await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      )).single;
      final first = await groupRepository.createGroup('First');
      final second = await groupRepository.createGroup('Second');
      await groupRepository.addBookmarks(first.id, {stored.id});
      await groupRepository.addBookmarks(second.id, {stored.id});
      final expected = BookmarkGroupDeletionPreview(
        group: (await groupRepository.getGroup(first.id))!,
        orphanBookmarkIds: const {},
      );
      final container = createContainer();
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;
      await groupRepository.removeBookmarks(second.id, {stored.id});

      await expectLater(
        notifier.deleteGroup(first.id, expectedPreview: expected),
        throwsA(isA<BookmarkGroupChangedException>()),
      );

      expect(await groupRepository.getGroup(first.id), isNotNull);
      expect(
        await bookmarkRepository.getAllBookmarksOrEmpty(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ),
        hasLength(1),
      );
    },
  );

  test(
    'a committed serialized mutation is returned when publishing fails',
    () async {
      final container = createContainer(
        bookmarkRepositoryOverride: _FailingSecondReadBookmarkRepository(
          bookmarkBox,
        ),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;

      final result = await notifier.runSerializedMutation(() async => 42);

      expect(result, 42);
      expect(container.read(bookmarkProvider).hasValue, isTrue);
      expect(await notifier.snapshotForExport(), isA<BookmarkLibraryState>());
    },
  );

  test('a committed bookmark creation is reconciled as success', () async {
    final container = createContainer(
      bookmarkRepositoryOverride: _CommitsThenThrowsAddBookmarkRepository(
        bookmarkBox,
      ),
    );
    final notifier = container.read(bookmarkProvider.notifier);
    await notifier.future;
    var succeeded = false;
    var failed = false;

    await notifier.addBookmark(
      BooruConfigAuth.fromConfig(BooruConfig.empty),
      Bookmark.empty
          .copyWith(originalUrl: 'https://example.com/partial.jpg')
          .toPost(),
      onSuccess: () => succeeded = true,
      onError: () => failed = true,
    );

    expect(succeeded, isTrue);
    expect(failed, isFalse);
    expect(
      await bookmarkRepository.getAllBookmarksOrEmpty(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      ),
      hasLength(1),
    );
    expect(container.read(bookmarkProvider).requireValue.items, hasLength(1));
  });

  test(
    'an operation error is preserved when recovery publishing also fails',
    () async {
      final container = createContainer(
        bookmarkRepositoryOverride: _FailingSecondReadBookmarkRepository(
          bookmarkBox,
        ),
      );
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;

      await expectLater(
        notifier.runSerializedMutation<void>(
          () async => throw StateError('operation failed'),
        ),
        throwsStateError,
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

class _CommitsThenThrowsDeleteGroupRepository
    extends BookmarkGroupRepositoryHive {
  _CommitsThenThrowsDeleteGroupRepository(super._box);

  @override
  Future<BookmarkGroupDeletionPreview> deleteGroup(String id) async {
    await super.deleteGroup(id);
    throw StateError('group delete reported failure after committing');
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

class _CommitsThenThrowsAddGroupRepository extends BookmarkGroupRepositoryHive {
  _CommitsThenThrowsAddGroupRepository(super._box);

  @override
  Future<BookmarkGroup> addBookmarks(String id, Set<int> bookmarkIds) async {
    await super.addBookmarks(id, bookmarkIds);
    throw StateError('membership addition reported failure after committing');
  }
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
    return (await addBookmarkWithBookmarks([
      _bookmarkFromPost(post),
    ])).single;
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

class _CommitsThenThrowsAddBookmarkRepository extends BookmarkHiveRepository {
  const _CommitsThenThrowsAddBookmarkRepository(super._box);

  @override
  Future<Bookmark> addBookmark(
    int booruId,
    Post post, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator Function(int? booruId) postLinkGenerator,
  }) async {
    await addBookmarkWithBookmarks([_bookmarkFromPost(post)]);
    throw StateError('bookmark write reported failure after committing');
  }
}

class _BookmarkPostRepository extends BookmarkHiveRepository {
  const _BookmarkPostRepository(super._box);

  @override
  Future<Bookmark> addBookmark(
    int booruId,
    Post post, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator Function(int? booruId) postLinkGenerator,
  }) async => (await addBookmarkWithBookmarks([
    _bookmarkFromPost(post),
  ])).single;
}

class _FailsSecondAddBookmarkRepository extends BookmarkHiveRepository {
  _FailsSecondAddBookmarkRepository(super._box);

  var _addCount = 0;

  @override
  Future<Bookmark> addBookmark(
    int booruId,
    Post post, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator Function(int? booruId) postLinkGenerator,
  }) async {
    _addCount++;
    if (_addCount == 2) throw StateError('second bookmark write failed');
    return (await addBookmarkWithBookmarks([
      _bookmarkFromPost(post),
    ])).single;
  }
}

Bookmark _bookmarkFromPost(Post post) {
  return Bookmark.fromSnapshot(
    id: -1,
    createdAt: DateTime(1),
    updatedAt: DateTime(1),
    snapshot: const StoredPostCodec().encode(post),
    post: post,
    sourceUrl: post.origin.sourceHost.isEmpty
        ? ''
        : 'https://${post.origin.sourceHost}',
  );
}

class _FailsSecondAddAndFirstCleanupRepository
    extends _FailsSecondAddBookmarkRepository {
  _FailsSecondAddAndFirstCleanupRepository(super._box);

  var _removeCount = 0;

  @override
  Future<void> removeBookmarks(Iterable<Bookmark> favorites) {
    _removeCount++;
    if (_removeCount == 1) throw StateError('first cleanup failed');
    return super.removeBookmarks(favorites);
  }
}

class _FailingThirdReadBookmarkRepository extends BookmarkHiveRepository {
  _FailingThirdReadBookmarkRepository(super._box);

  var _readCount = 0;

  @override
  BookmarksOrError getAllBookmarks({
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  }) {
    _readCount++;
    if (_readCount == 3) return TaskEither.left(BookmarkGetError.unknown);
    return super.getAllBookmarks(imageUrlResolver: imageUrlResolver);
  }
}
