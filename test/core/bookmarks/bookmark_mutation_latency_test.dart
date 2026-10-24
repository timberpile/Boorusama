import 'dart:async';

import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_hydration_service.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:foundation/foundation.dart';

import '../search/following_topics/topic_test_utils.dart';

void main() {
  late _CountingBookmarks repository;
  late _CountingGroups groups;
  late ProviderContainer container;
  late BookmarkLibraryNotifier notifier;
  late BooruConfig profile;

  Post post(int id) => testSearchPost(id, DateTime.utc(2026)).copyWith(
    origin: PostOrigin.fromSource(
      booruType: profile.auth.booruType,
      booruId: profile.booruId,
      source: profile.url,
      profileIdHint: profile.id,
    ),
  );

  void expectWarm() {
    expect(repository.reads, 0, reason: 'No whole-library reads after warming');
    expect(groups.repairs, 0, reason: 'Repair is not a normal mutation step');
  }

  Future<void> expectPersistedState() async {
    final published = await notifier.snapshotForExport();
    final reloaded = await BookmarkLibraryService(
      bookmarkRepository: repository,
      groupRepository: groups,
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    ).load(published.activeTarget);
    expect(published, reloaded);
    expect(published.bookmarksById, reloaded.bookmarksById);
    expect(published.bookmarksByUniqueId, reloaded.bookmarksByUniqueId);
    expect(published.membershipsByBookmark, reloaded.membershipsByBookmark);
  }

  ProviderContainer createContainer() => ProviderContainer(
    overrides: [
      booruConfigProvider.overrideWith(
        () => BooruConfigNotifier(initialConfigs: [profile]),
      ),
      bookmarkRepoProvider.overrideWith((ref) => repository),
      bookmarkGroupRepoProvider.overrideWith((ref) => groups),
      bookmarkUrlResolverProvider.overrideWith(
        (ref, booruId) => const DefaultImageUrlResolver(),
      ),
      settingsNotifierProvider.overrideWith(
        () => _Settings(Settings.defaultSettings),
      ),
    ],
  );

  setUp(() async {
    repository = _CountingBookmarks();
    groups = _CountingGroups();
    profile = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': '00000000-0000-4000-8000-000000000001',
      'url': 'https://example.com',
    });
    container = createContainer();
    notifier = container.read(bookmarkProvider.notifier);
    await notifier.future;
    repository.reads = 0;
    groups.repairs = 0;
  });

  tearDown(() => container.dispose());

  test(
    'ordinary add, shared removal, final deletion and Undo stay warm',
    () async {
      final p = post(1);
      final extra = await notifier.createGroup('Extra');
      expect(
        await notifier.togglePostTarget(profile.auth, p),
        BookmarkToggleOutcome.added,
      );
      await notifier.addBookmarkToGroup(profile.auth, p, extra.id);
      final stored = (await notifier.snapshotForExport()).items.single;
      final sharedRemoval = await notifier.removePostsFromGroup(
        profile.auth,
        [p],
        defaultBookmarkGroupId,
      );
      expect(sharedRemoval.deletedCount, 0);
      expect(repository.rows, hasLength(1));
      await notifier.undoRemoval(sharedRemoval);
      expect(
        (await notifier.snapshotForExport()).membershipsFor(stored.uniqueId),
        {defaultBookmarkGroupId, extra.id},
      );
      await notifier.removePostsFromGroup(profile.auth, [p], extra.id);
      final finalRemoval = await notifier.removePostsFromGroup(
        profile.auth,
        [p],
        defaultBookmarkGroupId,
      );
      expect(finalRemoval.deletedCount, 1);
      expect(repository.rows, isEmpty);
      await notifier.undoRemoval(finalRemoval);
      final restored = (await notifier.snapshotForExport()).items.single;
      expect(restored.id, isNot(stored.id));
      expect(
        (await groups.getGroup(defaultBookmarkGroupId))!.bookmarkIds,
        {restored.id},
      );
      expectWarm();
      await expectPersistedState();
    },
  );

  test('all ordinary add and delete entry points avoid full reads', () async {
    final extra = await notifier.createGroup('Extra');
    await notifier.addBookmark(profile.auth, post(1));
    await notifier.addBookmarks(profile.auth, [post(2), post(3)]);
    await notifier.addPostsToGroup(profile.auth, [post(4), post(5)], extra.id);
    var snapshot = await notifier.snapshotForExport();
    await notifier.addExistingBookmarkToGroup(snapshot.items.first, extra.id);
    await notifier.addExistingBookmarksToGroup(snapshot.items, extra.id);
    await notifier.setPostTargetMembership(
      profile.auth,
      post(2),
      target: BookmarkTarget.group(extra.id),
      bookmarked: false,
    );
    await notifier.removeBookmarkFromId(snapshot.items.first.uniqueId);
    await notifier.removeFromGroupAndDeleteIfLast(
      snapshot.items.last.uniqueId,
      extra.id,
    );
    await notifier.deleteBookmarksForPosts(profile.auth, [post(3)]);
    snapshot = await notifier.snapshotForExport();
    await notifier.removeBookmarks(snapshot.items);
    expect((await notifier.snapshotForExport()).items, isEmpty);
    expectWarm();
    await expectPersistedState();
  });

  test('bulk input duplicates do not create duplicate snapshots', () async {
    final p = post(1);
    expect(await notifier.addPostsToGroup(profile.auth, [p, p], null), 1);
    expect(repository.rows, hasLength(1));
    expectWarm();
    await expectPersistedState();
  });

  test('metadata edits reuse bookmark objects and indexes', () async {
    await notifier.addBookmark(profile.auth, post(1));
    final group = await notifier.createGroup('Before');
    final before = await notifier.snapshotForExport();
    await notifier.renameGroup(group.id, 'After');
    await notifier.setActiveTarget(BookmarkTarget.group(group.id));
    final after = await notifier.snapshotForExport();
    expect(identical(before.items, after.items), isTrue);
    expect(identical(before.bookmarksById, after.bookmarksById), isTrue);
    expect(
      identical(before.bookmarksByUniqueId, after.bookmarksByUniqueId),
      isTrue,
    );
    expect(
      identical(before.membershipsByBookmark, after.membershipsByBookmark),
      isTrue,
    );
    expectWarm();
    await expectPersistedState();
  });

  test(
    'rapid toggles are serialized against the latest committed state',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      repository.beforeNextAdd = () async {
        started.complete();
        await release.future;
      };
      final first = notifier.togglePostTarget(profile.auth, post(1));
      await started.future;
      final second = notifier.togglePostTarget(profile.auth, post(1));
      final third = notifier.togglePostTarget(profile.auth, post(1));
      release.complete();
      expect(await Future.wait([first, second, third]), [
        BookmarkToggleOutcome.added,
        BookmarkToggleOutcome.removed,
        BookmarkToggleOutcome.added,
      ]);
      expect(repository.rows, hasLength(1));
      expectWarm();
      await expectPersistedState();
    },
  );

  test(
    'a write that commits then throws uses authoritative recovery',
    () async {
      repository.throwAfterNextAdd = true;
      expect(
        await notifier.togglePostTarget(profile.auth, post(1)),
        BookmarkToggleOutcome.added,
      );
      expect(repository.reads, greaterThan(0));
      expect(repository.rows, hasLength(1));
      await expectPersistedState();
    },
  );

  test('unknown external mutations still reload and repair', () async {
    await notifier.runSerializedMutation(
      () => repository.addBookmark(
        profile.booruId,
        post(1),
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        postLinkGenerator: (_) => const NoLinkPostLinkGenerator(),
      ),
    );
    expect(repository.reads, greaterThan(0));
    expect(groups.repairs, greaterThan(0));
    final snapshot = await notifier.snapshotForExport();
    expect(snapshot.items, hasLength(1));
    expect(snapshot.membershipsFor(snapshot.items.single.uniqueId), {
      defaultBookmarkGroupId,
    });
    await expectPersistedState();
  });

  test(
    'Favorites Sync additions reconcile an ambiguous write before publishing',
    () async {
      repository.throwAfterNextAdd = true;
      expect(await notifier.addPostsToGroup(profile.auth, [post(1)], null), 1);
      expect(repository.reads, greaterThan(0));
      expect(groups.repairs, greaterThan(0));
      expect(repository.rows, hasLength(1));
      await expectPersistedState();
    },
  );

  test(
    'an external write without reload reconciles before the next toggle',
    () async {
      await notifier.runSerializedMutation(
        () => repository.addBookmark(
          profile.booruId,
          post(1),
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
          postLinkGenerator: (_) => const NoLinkPostLinkGenerator(),
        ),
        reload: false,
      );
      expect(container.read(bookmarkProvider).requireValue.items, isEmpty);
      expect(
        await notifier.togglePostTarget(profile.auth, post(1)),
        BookmarkToggleOutcome.removed,
      );
      expect(repository.rows, isEmpty);
      expect(repository.reads, greaterThan(0));
      await expectPersistedState();
    },
  );

  test(
    'global deletion invalidates Undo even after the same post is re-added',
    () async {
      await notifier.addBookmark(profile.auth, post(1));
      final removal = await notifier.removePostsFromGroup(profile.auth, [
        post(1),
      ], defaultBookmarkGroupId);
      await notifier.addBookmark(profile.auth, post(1));
      await notifier.deleteBookmarksForPosts(profile.auth, [post(1)]);
      await expectLater(notifier.undoRemoval(removal), throwsStateError);
      expect(repository.rows, isEmpty);
      await expectPersistedState();
    },
  );

  test(
    'failed reconciliation retains the previous snapshot and blocks writes',
    () async {
      await notifier.addBookmark(profile.auth, post(1));
      final previous = container.read(bookmarkProvider).requireValue;
      groups.failReads = true;
      expect(
        await notifier.togglePostTarget(profile.auth, post(2)),
        BookmarkToggleOutcome.added,
      );
      expect(
        identical(container.read(bookmarkProvider).valueOrNull, previous),
        isTrue,
      );
      await expectLater(
        notifier.togglePostTarget(profile.auth, post(3)),
        throwsStateError,
      );
      expect(
        identical(container.read(bookmarkProvider).valueOrNull, previous),
        isTrue,
      );
      expect(repository.rows, hasLength(2));
      groups.failReads = false;
      expect(
        await notifier.togglePostTarget(profile.auth, post(3)),
        BookmarkToggleOutcome.added,
      );
      expect((await notifier.snapshotForExport()).items, hasLength(3));
      await expectPersistedState();
    },
  );

  test(
    'collection duplication, moves and deletion previews stay warm',
    () async {
      final folder = await notifier.createFolder('Folder');
      final source = await notifier.createGroup('Source', folderId: folder.id);
      await notifier.addPostsToGroup(profile.auth, [
        post(1),
        post(2),
      ], source.id);
      final duplicate = (await notifier.duplicateGroups(
        {source.id: 'Copy'},
        expectedGroups: [
          (await notifier.snapshotForExport()).groupsById[source.id]!,
        ],
      )).single;
      await notifier.moveFolderItems(
        groupIds: {duplicate.id},
        destination: folder.id,
      );
      final stale = await notifier.previewDeleteFolder(folder.id);
      await notifier.addPostsToGroup(profile.auth, [post(3)], source.id);
      await expectLater(
        notifier.deleteFolder(stale),
        throwsA(isA<BookmarkFolderChangedException>()),
      );
      // Stale-preview errors intentionally reconcile authoritatively.
      repository.reads = 0;
      groups.repairs = 0;
      final preview = await notifier.previewDeleteFolder(folder.id);
      await notifier.deleteFolder(preview);
      expectWarm();
      expect((await notifier.snapshotForExport()).items, isEmpty);
      await expectPersistedState();
    },
  );

  test(
    'hydration does not hold the mutation lock during a network request',
    () async {
      await notifier.addBookmark(profile.auth, post(1));
      final started = Completer<void>();
      final release = Completer<Post?>();
      final hydration = notifier.hydrateBookmarks(
        configs: [profile],
        recovery: BookmarkRecoveryService(
          fetchPost: (_, _) {
            started.complete();
            return release.future;
          },
          codecFor: (_) => null,
        ),
        cancellation: BookmarkHydrationCancellation(),
        onProgress: (_) {},
      );
      // Timeouts here guard deadlocks; they are not performance budgets.
      try {
        await started.future.timeout(const Duration(seconds: 10));
        expect(
          await notifier
              .togglePostTarget(profile.auth, post(2))
              .timeout(
                const Duration(seconds: 10),
              ),
          BookmarkToggleOutcome.added,
        );
        expectWarm();
      } finally {
        release.complete(null);
        await hydration;
      }
      await expectPersistedState();
    },
  );

  for (final boundary in ['timer', 'interactive deletion', 'global mutation']) {
    test(
      'hydration batches committed snapshots and flushes before $boundary',
      () async {
        await notifier.addPostsToGroup(profile.auth, [
          for (var id = 1; id <= 35; id++) post(id),
        ], null);
        fakeAsync((time) {
          final container = createContainer();
          final notifier = container.read(bookmarkProvider.notifier);
          time.flushMicrotasks();
          repository.reads = 0;
          groups.repairs = 0;
          final last = Completer<Post?>();
          var completed = false;
          var publications = 0;
          final subscription = container.listen(
            bookmarkProvider,
            (_, _) => publications++,
          );
          final hydration = notifier.hydrateBookmarks(
            configs: [profile],
            recovery: BookmarkRecoveryService(
              fetchPost: (_, id) async => id == 35
                  ? last.future
                  : post(id).copyWith(
                      booruData: const GelbooruV2PostData(hasNotes: true),
                    ),
              codecFor: (_) => const GelbooruV2PostCodec(),
            ),
            cancellation: BookmarkHydrationCancellation(),
            onProgress: (_) {},
          );
          unawaited(
            hydration.then((result) {
              expect(result.updated, 35);
              completed = true;
            }),
          );
          time.flushMicrotasks();
          int publishedNative() => container
              .read(bookmarkProvider)
              .requireValue
              .items
              .where((row) => !needsBookmarkHydration(row))
              .length;
          expect(
            repository.rows.values.where((row) => !needsBookmarkHydration(row)),
            hasLength(34),
          );
          expect(publishedNative(), 32);
          expect(publications, 1);
          expect(completed, isFalse);
          if (boundary == 'timer') {
            time.elapse(const Duration(milliseconds: 16));
            expect(publishedNative(), 34);
          } else if (boundary == 'interactive deletion') {
            unawaited(
              notifier.deleteBookmarksForPosts(profile.auth, [post(33)]),
            );
            time.flushMicrotasks();
            expect(publishedNative(), 33);
            time.elapse(const Duration(milliseconds: 16));
            expect(
              container.read(bookmarkProvider).requireValue.bookmarksByUniqueId,
              isNot(contains(BookmarkUniqueId.fromPost(post(33)))),
            );
          } else {
            final release = Completer<void>();
            unawaited(
              container
                  .read(dataMutationCoordinatorProvider)
                  .runExclusive(() => release.future),
            );
            time.flushMicrotasks();
            time.elapse(const Duration(milliseconds: 16));
            expect(
              publishedNative(),
              32,
              reason:
                  'Timer publication must respect the global mutation boundary',
            );
            release.complete();
            time.flushMicrotasks();
            expect(publishedNative(), 34);
          }
          last.complete(
            post(35)
                .copyWith(booruData: const GelbooruV2PostData(hasNotes: true)),
          );
          time.flushMicrotasks();
          expect(completed, isTrue);
          expect(
            publishedNative(),
            boundary == 'interactive deletion' ? 34 : 35,
          );
          expectWarm();
          expect(
            container.read(bookmarkProvider).requireValue.items,
            repository.rows.values.toList(),
          );
          subscription.close();
          container.dispose();
        });
      },
    );
  }
}

class _Settings extends SettingsNotifier {
  _Settings(super.initialSettings);

  @override
  Future<bool> updateWith(Settings Function(Settings) selector) async {
    state = selector(state);
    return true;
  }
}

class _CountingGroups extends BookmarkGroupRepositoryHive {
  _CountingGroups()
    : super(
        MemoryBox<BookmarkGroupHiveObject>(),
        organizationBox: MemoryBox<dynamic>(),
      );

  int repairs = 0;
  var failReads = false;

  @override
  Future<List<BookmarkGroup>> getGroups() {
    if (failReads) throw StateError('Publication unavailable');
    return super.getGroups();
  }

  @override
  Future<bool> repair({required Set<int> validBookmarkIds}) {
    repairs++;
    return super.repair(validBookmarkIds: validBookmarkIds);
  }
}

class _CountingBookmarks implements BookmarkRepository<Post> {
  final rows = <int, Bookmark>{};
  int reads = 0;
  int _nextId = 0;
  bool throwAfterNextAdd = false;
  Future<void> Function()? beforeNextAdd;

  @override
  BookmarksOrError getAllBookmarks({
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  }) {
    reads++;
    return TaskEither.right(rows.values.toList());
  }

  @override
  Future<Bookmark> addBookmark(
    int booruId,
    Post post, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator<Post> Function(int? booruId) postLinkGenerator,
  }) async {
    final before = beforeNextAdd;
    beforeNextAdd = null;
    await before?.call();
    final bookmark = Bookmark.fromSnapshot(
      id: _nextId++,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      snapshot: const StoredPostCodec().encode(post),
      post: post,
      postId: post.id,
      sourceUrl: '',
    );
    rows[bookmark.id] = bookmark;
    if (throwAfterNextAdd) {
      throwAfterNextAdd = false;
      throw StateError('Committed before throwing');
    }
    return bookmark;
  }

  @override
  Future<List<Bookmark>> addBookmarks(
    int booruId,
    Iterable<Post> posts, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator<Post> Function(int? booruId) postLinkGenerator,
  }) => Future.wait([
    for (final post in posts)
      addBookmark(
        booruId,
        post,
        imageUrlResolver: imageUrlResolver,
        postLinkGenerator: postLinkGenerator,
      ),
  ]);

  @override
  Future<List<Bookmark>> addBookmarkWithBookmarks(
    List<Bookmark> bookmarks,
  ) async {
    final added = [for (final b in bookmarks) b.copyWith(id: _nextId++)];
    for (final b in added) {
      rows[b.id] = b;
    }
    return added;
  }

  @override
  Future<void> updateBookmark(Bookmark bookmark) async {
    rows[bookmark.id] = bookmark;
  }

  @override
  Future<void> removeBookmark(Bookmark bookmark) async {
    rows.remove(bookmark.id);
  }

  @override
  Future<void> removeBookmarks(Iterable<Bookmark> bookmarks) async {
    for (final b in bookmarks.toList()) {
      rows.remove(b.id);
    }
  }
}
