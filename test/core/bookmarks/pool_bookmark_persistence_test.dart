import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_cover.dart';

import 'dart:io';

import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_planner.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_plan.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_service.dart';
import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';

import '../search/following_topics/topic_test_utils.dart';
import 'pool_bookmark_test_utils.dart';

void main() {
  late BookmarkHiveRepository posts;
  late Box<BookmarkGroupHiveObject> groupBox;
  late Directory testDirectory;
  late _OrganizationBox organization;
  late BookmarkGroupRepositoryHive groups;
  late BookmarkLibraryService service;
  ImageUrlResolver resolver(int? _) => const DefaultImageUrlResolver();
  BookmarkImportService importer() => BookmarkImportService(
    bookmarkRepository: posts,
    groupRepository: groups,
    imageUrlResolver: resolver,
  );

  Future<List<Bookmark>> allPosts() =>
      posts.getAllBookmarksOrThrow(imageUrlResolver: resolver);
  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'pool-reference-service-',
    );
    Hive.init(testDirectory.path);
    if (!Hive.isAdapterRegistered(4))
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    posts = BookmarkHiveRepository(
      await Hive.openBox<BookmarkHiveObject>('service-posts'),
    );
    groupBox = await Hive.openBox<BookmarkGroupHiveObject>('service-groups');
    organization = _OrganizationBox();
    groups = BookmarkGroupRepositoryHive(
      groupBox,
      organizationBox: organization,
    );
    await groups.createGroup('A', id: poolGroupA);
    service = BookmarkLibraryService(
      bookmarkRepository: posts,
      groupRepository: groups,
      imageUrlResolver: resolver,
    );
  });

  tearDown(() async {
    await posts.close();
    await groupBox.close();
    await testDirectory.delete(recursive: true);
  });

  test('dangling legacy collection memberships migrate to Default without losing the reference', () async {
    await organization.put('poolBookmarks', [
      testPool(groups: {poolGroupB}).toJson(),
    ]);
    final state = await service.load();
    expect(state.pools.single.identity, testPool().identity);
    expect(state.pools.single.groupIds, {defaultBookmarkGroupId});
    expect(state.items, isEmpty);
  });

  test('legacy Post library remains valid and Pool-only removal leaves Posts intact', () async {
    final post = testPoolPost(1);
    await posts.updateBookmark(post);
    await groups.addBookmarks(poolGroupA, {post.id});
    expect(
      (await service.load()).pools,
      isEmpty,
    );
    await groups.writePoolBookmarks([testPool()]);
    final result = await service.removeBookmarksFromGroup(
      [],
      poolGroupA,
      poolLocalIds: {testPool().localId},
    );
    expect(result.removedCount, 1);
    expect((await allPosts()), [post]);
    expect((await groups.getGroup(poolGroupA))!.bookmarkIds, {post.id});
    expect(await groups.readPoolBookmarks(), isEmpty);
    await service.undoRemoval(result);
    expect(await groups.readPoolBookmarks(), [testPool()]);
  });

  test('mixed removal and Undo restores actual Post identities and one Pool reference', () async {
    final post = testPoolPost(1);
    await posts.updateBookmark(post);
    await groups.addBookmarks(poolGroupA, {post.id});
    await groups.writePoolBookmarks([testPool()]);
    final result = await service.removeBookmarksFromGroup(
      [post],
      poolGroupA,
      poolLocalIds: {testPool().localId},
    );
    expect(result.removedCount, 2);
    expect(result.deletedCount, 1);
    expect((await allPosts()), isEmpty);
    expect(await groups.readPoolBookmarks(), isEmpty);
    await service.undoRemoval(result);
    expect((await allPosts()).single.identity, post.identity);
    expect((await groups.getGroup(poolGroupA))!.bookmarkIds, {
      (await allPosts()).single.id,
    });
    expect(
      (await groups.readPoolBookmarks()).single.identity,
      testPool().identity,
    );
  });

  test(
    'removing a shared reference preserves its other group and safe metadata',
    () async {
      await groups.createGroup('B', id: poolGroupB);
      await groups.writePoolBookmarks([
        testPool(groups: {poolGroupA, poolGroupB}),
      ]);
      final result = await service.removeBookmarksFromGroup(
        [],
        poolGroupA,
        poolLocalIds: {testPool().localId},
      );
      expect((await groups.readPoolBookmarks()).single.groupIds, {poolGroupB});
      await service.undoRemoval(result);
      expect((await groups.readPoolBookmarks()).single.groupIds, {
        poolGroupA,
        poolGroupB,
      });
    },
  );

  test(
    'group duplication, deletion preview and deletion include typed references',
    () async {
      await groups.writePoolBookmarks([testPool()]);
      final copy = await service.duplicateGroup(poolGroupA, 'Copy');
      expect((await groups.readPoolBookmarks()).single.groupIds, {
        poolGroupA,
        copy.id,
      });
      final preview = await groups.previewDeleteGroup(poolGroupA);
      expect(preview.bookmarkCount, 1);
      expect(preview.orphanPoolIds, isEmpty);
      await service.deleteGroup(poolGroupA);
      expect((await groups.readPoolBookmarks()).single.groupIds, {copy.id});
      expect((await groups.previewDeleteGroup(copy.id)).orphanPoolIds, {
        testPool().localId,
      });
      await service.deleteGroup(copy.id);
      expect(await groups.readPoolBookmarks(), isEmpty);
    },
  );

  test(
    'failed typed write rolls back an already removed Post and memberships',
    () async {
      final post = testPoolPost(1);
      await posts.updateBookmark(post);
      await groups.addBookmarks(poolGroupA, {1});
      await groups.writePoolBookmarks([testPool()]);
      organization.failNext = true;
      await expectLater(
        service.removeBookmarksFromGroup(
          [post],
          poolGroupA,
          poolLocalIds: {testPool().localId},
        ),
        throwsStateError,
      );
      expect((await allPosts()), [post]);
      expect((await groups.getGroup(poolGroupA))!.bookmarkIds, {1});
      expect(await groups.readPoolBookmarks(), [testPool()]);
    },
  );

  test('version 6 scoped backup round trips Pool-only groups and rejects future kinds', () async {
    await groups.createGroup('B', id: poolGroupB);
    final cover = PoolBookmarkCover(
      thumbnail: 'https://cover.test/low.jpg',
      sample: 'https://cover.test/sample.jpg',
      original: 'https://cover.test/original.png',
      variants: {'720x720': 'https://cover.test/high.jpg'},
    );
    final data = buildBookmarkBackupData(
      bookmarks: [],
      groups: await groups.getGroups(),
      pools: [
        testPool(groups: {poolGroupA, poolGroupB}).copyWith(cover: cover),
      ],
      scope: BookmarkExportScope.selected(groupIds: {poolGroupA}),
    );
    final codec = BookmarkBackupCodec();
    ExportDataPayload payload(Map<String, dynamic> extra) => ExportDataPayload(
      version: 6,
      exportDate: null,
      exportVersion: null,
      data: codec.encode(data),
      extraFields: extra,
    );
    final parsed = codec.parse(payload(data.extraFields));
    expect(parsed.pools.single.groupIds, {poolGroupA});
    expect(parsed.bookmarks, isEmpty);
    expect(parsed.pools.single.total, 20);
    expect(parsed.pools.single.cover, cover);
    expect(
      () => codec.parse(
        payload({
          ...data.extraFields,
          'collectionBookmarks': [
            {...data.pools.single.toJson(), 'kind': 'future'},
          ],
        }),
      ),
      throwsA(isA<InvalidBackupFormatException>()),
    );
    expect(
      () => codec.parse(
        payload({
          ...data.extraFields,
          'collectionBookmarks': [
            data.pools.single.withGroups({poolGroupB}).toJson(),
          ],
        }),
      ),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });

  test('copy import remaps reference memberships without duplicating its source identity', () async {
    await groups.writePoolBookmarks([testPool()]);
    final data = BookmarkBackupData(
      bookmarks: [],
      pools: [testPool()],
      groups: [
        const BookmarkGroupBackup(
          id: poolGroupA,
          name: 'Incoming',
          bookmarkIds: [],
        ),
      ],
    );
    final plan = const BookmarkImportPlanner().plan(
      data: data,
      currentBookmarks: [],
      currentGroups: await groups.getGroups(),
    );
    await importer().apply(
      plan.resolveActions({
        poolGroupA: plan.groups.single.resolveAction(
          ImportAction.copy,
          destinationId: poolGroupB,
        ),
      }),
    );
    expect((await groups.readPoolBookmarks()).single.groupIds, {
      poolGroupA,
      poolGroupB,
    });
    expect((await groups.getGroup(poolGroupA))!.name, 'A');
    expect((await groups.getGroup(poolGroupB))!.name, 'Incoming');
  });

  test(
    'equal remote IDs on another host survive import with distinct local IDs',
    () async {
      await groups.writePoolBookmarks([testPool()]);
      final incoming = testPool(host: 'other.example');
      final data = BookmarkBackupData(
        bookmarks: [],
        pools: [incoming],
        groups: [
          const BookmarkGroupBackup(
            id: poolGroupA,
            name: 'Incoming',
            bookmarkIds: [],
          ),
        ],
      );
      final plan = const BookmarkImportPlanner().plan(
        data: data,
        currentBookmarks: [],
        currentGroups: await groups.getGroups(),
      );
      await importer().apply(
        plan.resolve({poolGroupA: BookmarkGroupConflictChoice.merge}),
      );
      final saved = await groups.readPoolBookmarks();
      expect(saved, hasLength(2));
      expect(saved.map((p) => p.identity).toSet(), hasLength(2));
      expect(saved.map((p) => p.localId).toSet(), hasLength(2));
    },
  );

  test(
    'failed full replacement restores old typed entries and ordinary Posts',
    () async {
      final post = testPoolPost(1);
      await posts.updateBookmark(post);
      await groups.addBookmarks(poolGroupA, {1});
      await groups.writePoolBookmarks([testPool()]);
      organization.failPoolId = 99;
      await expectLater(
        importer().replace(
          BookmarkBackupData(
            bookmarks: [],
            pools: [testPool(id: 99)],
            groups: [
              const BookmarkGroupBackup(
                id: poolGroupA,
                name: 'Incoming',
                bookmarkIds: [],
              ),
            ],
          ),
        ),
        throwsStateError,
      );
      expect((await allPosts()).single.identity, post.identity);
      expect((await groups.getGroup(poolGroupA))!.name, 'A');
      expect((await groups.getGroup(poolGroupA))!.bookmarkIds, {
        (await allPosts()).single.id,
      });
      expect(await groups.readPoolBookmarks(), [testPool()]);
    },
  );

  test(
    'real Hive organization reopens references without changing legacy groups',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pool-bookmark-hive-',
      );
      addTearDown(() => directory.delete(recursive: true));
      Hive.init(directory.path);
      if (!Hive.isAdapterRegistered(5))
        Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
      Future<BookmarkGroupRepositoryHive> open() async =>
          BookmarkGroupRepositoryHive(
            await Hive.openBox<BookmarkGroupHiveObject>('pool-groups'),
            organizationBox: await Hive.openBox<dynamic>('pool-organization'),
          );
      var repository = await open();
      await repository.createGroup('A', id: poolGroupA);
      await repository.addBookmarks(poolGroupA, {7});
      await repository.initializeFolders();
      await repository.writePoolBookmarks([testPool()]);
      await repository.close();
      repository = await open();
      expect((await repository.getGroup(poolGroupA))!.bookmarkIds, {7});
      expect(await repository.readPoolBookmarks(), [testPool()]);
      await repository.close();
    },
  );
}

class _OrganizationBox extends MemoryBox<dynamic> {
  var failNext = false;
  int? failPoolId;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (key == 'poolBookmarks' &&
        (failNext ||
            (failPoolId != null &&
                (value as List).any(
                  (r) => (r as Map)['poolId'] == failPoolId,
                )))) {
      failNext = false;
      failPoolId = null;
      throw StateError('controlled organization write failure');
    }
    await super.put(key, value);
  }
}
