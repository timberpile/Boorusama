// Dart imports:
import 'dart:io';

// Package imports:
import 'package:hive_ce/hive.dart';
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/blacklists/src/data/hive/factory.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/factory.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_factory_hive.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/unified_bookmark_store.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/bulk_downloads/src/data/repo_io.dart';
import 'package:boorusama/core/cache/hive_misc_data_store.dart';
import 'package:boorusama/core/cache/hive_persistent_cache_store.dart';
import 'package:boorusama/core/debug/data.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/histories/src/data/repo_io.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/tags/favorites/src/data/favorite_tag_repository_factory_hive.dart';
import 'package:boorusama/core/tags/local/src/data/repo_io.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';

import 'core/bookmarks/pool_bookmark_test_utils.dart';

void main() {
  late Directory root;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('boorusama-adapters-');
    Hive.init(root.path);
    Hive.registerAdapter(FavoriteTagHiveObjectAdapter());
    Hive.registerAdapter(BlacklistedTagHiveObjectAdapter());
    Hive.registerAdapter(BookmarkHiveObjectAdapter());
    Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  test(
    'Hive misc and persistent cache stores support basic lifecycle',
    () async {
      final miscBox = await Hive.openBox<String>('misc_adapter_test');
      final misc = HiveMiscDataStore(miscBox);
      expect(misc.get('missing'), isNull);
      await misc.put('theme', 'dark');
      expect(misc.get('theme'), 'dark');
      await misc.put('theme', 'light');
      expect(misc.get('theme'), 'light');
      await miscBox.close();

      final cacheBox = await Hive.openBox<String>('cache_adapter_test');
      final cache = HivePersistentCacheStore(cacheBox);
      expect(cache.length, 0);
      await cache.put('one', '1');
      await cache.put('two', '2');
      expect(cache.keys, containsAll(<String>['one', 'two']));
      expect(cache.get('one'), '1');
      expect(cache.get('missing'), isNull);
      await cache.clear();
      expect(cache.length, 0);
      await cacheBox.close();
    },
  );

  test('Hive repository factories preserve values across disposal', () async {
    const favoriteFactory = HiveFavoriteTagRepositoryFactory(
      boxName: 'favorite_factory_test',
    );
    final favorites = await favoriteFactory.create();
    await favorites.create(name: 'cat', labels: const ['pets']);
    await favoriteFactory.dispose(favorites);
    final reopenedFavorites = await favoriteFactory.create();
    expect(await reopenedFavorites.getFirst('cat'), isNotNull);
    await favoriteFactory.dispose(reopenedFavorites);

    final blacklistFactory = HiveGlobalBlacklistedTagRepositoryFactory(
      path: root.path,
    );
    final blacklist = await blacklistFactory.create();
    final added = await blacklist.addTag('spoiler');
    expect(added?.name, 'spoiler');
    await blacklistFactory.dispose(blacklist);
    final reopenedBlacklist = await blacklistFactory.create();
    expect(
      (await reopenedBlacklist.getBlacklist()).map((tag) => tag.name),
      contains('spoiler'),
    );
    await blacklistFactory.dispose(reopenedBlacklist);

    const bookmarkFactory = HiveBookmarkRepositoryFactory(
      boxName: 'bookmark_factory_test',
    );
    final context = BookmarkStorageContext(
      coordinator: DataMutationCoordinator(),
    );
    final bookmarks = await bookmarkFactory.create(storage: context);
    await bookmarks.addBookmarkWithBookmarks([_bookmark()]);
    await bookmarkFactory.dispose(bookmarks);
    final reopenedBookmarks = await bookmarkFactory.create(storage: context);
    final values = await reopenedBookmarks.getAllBookmarksOrEmpty(
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    );
    expect(values.single.tags, contains('cat'));
    expect(values.single.postId, 101);
    await bookmarkFactory.dispose(reopenedBookmarks);
  });

  test('production bookmark factory completes legacy organization migration before exposure', () async {
    const boxName = 'bookmark_factory_cutover_test';
    final groupsId = poolGroupA;
    const parentFolderId = '550e8400-e29b-41d4-a716-446655440010';
    const childFolderId = '550e8400-e29b-41d4-a716-446655440011';
    final postDate = DateTime.utc(2024, 3, 4, 5, 6, 7, 123, 456);
    final poolDate = DateTime.utc(2025, 6, 7, 8, 9, 10, 789, 123);
    final originalPost = testPoolPost(7).copyWith(id: 0);
    final originalPool = testPool(groups: {groupsId}).withGroups(
      {groupsId},
      addedAt: {groupsId: poolDate},
    );

    final oldPosts = await Hive.openBox<BookmarkHiveObject>(boxName);
    final oldGroups = await Hive.openBox<BookmarkGroupHiveObject>(
      '${boxName}_bookmark_groups',
    );
    final oldOrganization = await Hive.openBox<dynamic>(
      '${boxName}_bookmark_folders',
    );
    await oldPosts.put(0, favoriteToHiveObject(originalPost));
    await oldGroups.put(
      groupsId,
      BookmarkGroupHiveObject(
        id: groupsId,
        name: 'Legacy group',
        bookmarkIds: [0],
        folderId: childFolderId,
        addedAt: {0: postDate.toIso8601String()},
      ),
    );
    await oldOrganization.put('version', 1);
    await oldOrganization.put('poolBookmarks', [originalPool.toJson()]);
    await oldOrganization.put('folders', [
      const CollectionFolder(
        id: parentFolderId,
        name: 'Parent',
        position: 0,
      ).toJson(),
      const CollectionFolder(
        id: childFolderId,
        name: 'Child',
        parentId: parentFolderId,
        position: 0,
      ).toJson(),
    ]);

    const factory = HiveBookmarkRepositoryFactory(boxName: boxName);
    final storage = BookmarkStorageContext(
      coordinator: DataMutationCoordinator(),
    );
    final bookmarkRepository = await factory.create(storage: storage);
    expect(bookmarkRepository, isA<UnifiedBookmarkStore>());
    final organization = await const HiveBookmarkGroupRepositoryFactory()
        .createWithBookmarkRepository(bookmarkRepository);
    expect(organization, isA<UnifiedBookmarkOrganization>());
    expect(
      identical(
        (organization as UnifiedBookmarkOrganization).bookmarks,
        bookmarkRepository,
      ),
      isTrue,
    );

    final store = bookmarkRepository as UnifiedBookmarkStore;
    final migratedRecords = await store.readAll();
    final migratedPost = migratedRecords.whereType<PostBookmark>().single;
    final migratedPoolId = migratedRecords
        .where((record) => record is! PostBookmark)
        .single
        .id;
    final migratedGroup = (await organization.getGroup(groupsId))!;
    expect(migratedPost.id, 0);
    expect(migratedGroup.bookmarkIds, {migratedPost.id, migratedPoolId});
    expect(migratedGroup.addedAt[migratedPost.id], postDate);
    expect(migratedGroup.addedAt[migratedPoolId], poolDate);
    expect(await organization.getFolders(), [
      const CollectionFolder(id: parentFolderId, name: 'Parent', position: 0),
      const CollectionFolder(
        id: childFolderId,
        name: 'Child',
        parentId: parentFolderId,
        position: 0,
      ),
    ]);
    final poolView = (organization as PoolBookmarkRepository).readPoolBookmarks;
    expect((await poolView()).single.bookmarkId, migratedPoolId);

    await factory.dispose(bookmarkRepository);
    await Hive.close();
    Hive.init(root.path);
    final reopenedRepository = await factory.create(storage: storage);
    final reopenedOrganization =
        await const HiveBookmarkGroupRepositoryFactory()
            .createWithBookmarkRepository(reopenedRepository);
    final reopenedStore = reopenedRepository as UnifiedBookmarkStore;
    final reopenedRecords = await reopenedStore.readAll();
    final reopenedGroup = (await reopenedOrganization.getGroup(groupsId))!;
    expect(
      reopenedRecords.map((record) => record.id).toSet(),
      {migratedPost.id, migratedPoolId},
    );
    expect(reopenedGroup.bookmarkIds, migratedGroup.bookmarkIds);
    expect(reopenedGroup.addedAt, migratedGroup.addedAt);
    expect(
      (await (reopenedOrganization as PoolBookmarkRepository)
              .readPoolBookmarks())
          .single
          .bookmarkId,
      migratedPoolId,
    );
    await factory.dispose(reopenedRepository);
  });

  test('production bookmark factory rejects unsupported legacy organization before exposing repository', () async {
    const boxName = 'bookmark_factory_future_org_test';
    final oldPost = testPoolPost(7).copyWith(id: 0);
    final pool = testPool(groups: {poolGroupA});
    final oldPosts = await Hive.openBox<BookmarkHiveObject>(boxName);
    final oldGroups = await Hive.openBox<BookmarkGroupHiveObject>(
      '${boxName}_bookmark_groups',
    );
    final oldOrganization = await Hive.openBox<dynamic>(
      '${boxName}_bookmark_folders',
    );
    await oldPosts.put(0, favoriteToHiveObject(oldPost));
    await oldGroups.put(
      poolGroupA,
      BookmarkGroupHiveObject(
        id: poolGroupA,
        name: 'Legacy group',
        bookmarkIds: [0],
        addedAt: {0: DateTime.utc(2024).toIso8601String()},
      ),
    );
    await oldOrganization.put('version', 99);
    await oldOrganization.put('poolBookmarks', [pool.toJson()]);
    final groupsBefore = oldGroups.toMap();
    final organizationBefore = oldOrganization.toMap();

    const factory = HiveBookmarkRepositoryFactory(boxName: boxName);
    await expectLater(
      factory.create(
        storage: BookmarkStorageContext(
          coordinator: DataMutationCoordinator(),
        ),
      ),
      throwsA(isA<FormatException>()),
    );

    expect(oldPosts.get(0), isNotNull);
    expect(oldGroups.toMap(), groupsBefore);
    expect(oldOrganization.toMap(), organizationBefore);
    final metadata = await Hive.openBox<dynamic>(
      '${boxName}_content_metadata',
    );
    expect(metadata.get(BookmarkStorageMigration.activeKey), isNull);
    expect(metadata.get(BookmarkStorageMigration.pendingKey), isNull);
  });

  test(
    'SQLite search history factory creates and reopens its repository',
    () async {
      final factory = SqliteSearchHistoryRepositoryFactory(
        fileSystem: _TestFileSystem(root.path),
        logger: AppLogger(),
      );

      final repository = await factory.create();
      await repository.addHistory(
        'cat',
        queryType: QueryType.simple,
        booruTypeName: 'test',
        siteUrl: 'https://example.test',
      );
      expect((await repository.getHistories()).single.query, 'cat');
      await factory.dispose(repository);

      final reopened = await factory.create();
      expect((await reopened.getHistories()).single.searchCount, 1);
      await factory.dispose(reopened);
    },
  );

  test('SQLite feature factories create and dispose repositories', () async {
    final fileSystem = _TestFileSystem(root.path);
    final logger = AppLogger();

    final tagFactory = SqliteTagCacheRepositoryFactory(
      fileSystem: fileSystem,
      logger: logger,
    );
    final tags = await tagFactory.create();
    await tags.saveTag(
      siteHost: 'example.test',
      tagName: 'cat',
      category: 'general',
    );
    expect(await tags.getTagCategory('example.test', 'cat'), 'general');
    await tagFactory.dispose(tags);

    final downloadFactory = SqliteDownloadRepositoryFactory(
      fileSystem: fileSystem,
      logger: logger,
    );
    final downloads = await downloadFactory.create();
    expect(await downloads.getTasks(), isEmpty);
    await downloadFactory.dispose(downloads);
  });
}

PostBookmark _bookmark() => PostBookmark(
  id: 1,
  booruId: 1,
  createdAt: DateTime.utc(2020),
  updatedAt: DateTime.utc(2020),
  thumbnailUrl: 'https://example.test/thumb.jpg',
  sampleUrl: 'https://example.test/sample.jpg',
  originalUrl: 'https://example.test/original.jpg',
  sourceUrl: 'https://example.test/posts/101',
  width: 100,
  height: 100,
  md5: 'hash',
  tags: const {'cat'},
  realSourceUrl: 'https://example.test/source',
  format: '.jpg',
  imageUrlResolver: const DefaultImageUrlResolver(),
  postId: 101,
  metadata: const {},
);

final class _TestFileSystem extends IoFileSystem {
  _TestFileSystem(this.path);

  final String path;

  @override
  Future<String> getAppStoragePath() async => path;
}
