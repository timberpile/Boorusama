import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmarks_source.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_planner.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_plan.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_service.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_grid_entry.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_mirror_state.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/related/related_family.dart';

import '../../support/fakes/bookmark_test_storage.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../search/following_topics/topic_test_utils.dart';
import 'pool_bookmark_test_utils.dart';

void main() {
  final old = DateTime.utc(2020);
  final first = DateTime.utc(2021, 1, 1, 0, 0, 0, 123, 456);
  final second = DateTime.utc(2022);
  final third = DateTime.utc(2023);
  late DateTime now;
  late Directory directory;
  late Box<BookmarkHiveObject> postsBox;
  late Box<BookmarkGroupHiveObject> groupsBox;
  late BookmarkTestStorage storage;
  late BookmarkHiveRepository posts;
  late _Groups groups;
  late BookmarkLibraryService service;
  ImageUrlResolver resolver(int? _) => const DefaultImageUrlResolver();
  BookmarkImportService importer() => BookmarkImportService(
    bookmarkRepository: posts,
    groupRepository: groups,
    imageUrlResolver: resolver,
  );
  Future<PostBookmark> seed(int id) async =>
      (await posts.addBookmarkWithBookmarks([
        testPoolPost(id).copyWith(createdAt: old),
      ])).single;
  Future<BookmarkGroup> group(String id) async => (await groups.getGroup(id))!;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('membership_dates_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4))
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    postsBox = await Hive.openBox('membership_posts');
    storage = await BookmarkTestStorage.open(postsBox);
    groupsBox = await Hive.openBox('membership_groups');
    posts = storage.repository(postsBox);
    now = first;
    groups = _Groups(
      groupsBox,
      organizationBox: MemoryBox<dynamic>(),
      now: () => now,
    );
    service = BookmarkLibraryService(
      bookmarkRepository: posts,
      groupRepository: groups,
      imageUrlResolver: resolver,
    );
    await groups.createGroup('A', id: poolGroupA);
    await groups.createGroup('B', id: poolGroupB);
  });
  tearDown(() async {
    await storage.close();
    await postsBox.close();
    await groupsBox.close();
    await directory.delete(recursive: true);
  });

  test(
    'legacy dates use saved creation time and persist across Hive reopen',
    () async {
      final post = await seed(1);
      await groupsBox.put(
        poolGroupA,
        BookmarkGroupHiveObject(
          id: poolGroupA,
          name: 'A',
          bookmarkIds: [post.id],
        ),
      );
      await service.load();
      expect((await group(poolGroupA)).addedAt[post.id], old);
      await groupsBox.close();
      groupsBox = await Hive.openBox('membership_groups');
      expect(
        DateTime.parse(groupsBox.get(poolGroupA)!.addedAt![post.id] as String),
        old,
      );
    },
  );

  test(
    'new membership dates are independent, stable, reversible and duplicated',
    () async {
      final post = await seed(1);
      await service.addBookmarkToGroup(
        groupId: poolGroupA,
        existingBookmark: post,
      );
      now = second;
      await service.addBookmarkToGroup(
        groupId: poolGroupB,
        existingBookmark: post,
      );
      final other = await seed(2);
      now = second.add(const Duration(days: 1));
      await service.addBookmarkToGroup(
        groupId: poolGroupB,
        existingBookmark: other,
      );
      List<Object> mosaicKeys(BookmarkLibraryState state) =>
          selectBookmarkMosaicEntries(
            state: state,
            view: BookmarkView.group(poolGroupB),
          ).map((entry) => entry.key).toList();
      final postKey = BookmarkPostEntry(post).key;
      final otherKey = BookmarkPostEntry(other).key;
      expect(mosaicKeys(await service.load()), [otherKey, postKey]);
      now = third;
      expect(
        await service.addBookmarkToGroup(
          groupId: poolGroupB,
          existingBookmark: post,
        ),
        isFalse,
      );
      await service.upgradeBookmarkSnapshot(
        bookmark: post,
        post: post.post,
        dataCodec: null,
      );
      expect((await group(poolGroupA)).addedAt[post.id], first);
      expect((await group(poolGroupB)).addedAt[post.id], second);
      final removal = await service.removeBookmarksFromGroup([
        post,
      ], poolGroupB);
      await service.undoRemoval(removal);
      expect((await group(poolGroupB)).addedAt[post.id], second);
      await service.removeBookmarksFromGroup([post], poolGroupB);
      await service.addBookmarkToGroup(
        groupId: poolGroupB,
        existingBookmark: post,
      );
      expect((await group(poolGroupB)).addedAt[post.id], third);
      final duplicate = await service.duplicateGroup(poolGroupB, 'Copy');
      expect(duplicate.addedAt[post.id], third);
      final stored = await posts.getAllBookmarksOrThrow(
        imageUrlResolver: resolver,
      );
      expect(
        stored.singleWhere((record) => record.id == post.id).createdAt,
        old,
      );
      expect(mosaicKeys(await service.load()), [postKey, otherKey]);

      await groupsBox.close();
      groupsBox = await Hive.openBox('membership_groups');
      final reloaded = BookmarkLibraryService(
        bookmarkRepository: posts,
        groupRepository: _Groups(
          groupsBox,
          organizationBox: MemoryBox<dynamic>(),
          now: () => now,
        ),
        imageUrlResolver: resolver,
      );
      expect(mosaicKeys(await reloaded.load()), [postKey, otherKey]);
    },
  );

  test('folder mosaic ranks all types inside each membership scope', () {
    const other = '550e8400-e29b-41d4-a716-446655440003';
    const received = '550e8400-e29b-41d4-a716-446655440004';
    final latestLocal = DateTime.utc(2024);
    final latestReceived = DateTime.utc(2030);
    final post = testPoolPost(1).copyWith(createdAt: old);
    final receivedOnly = testPoolPost(2);
    ContentGroupBookmark groupRecord(
      int id,
      BooruType engine,
      String site,
      String key, {
      DateTime? upload,
    }) {
      final summary = ContentGroupSummary(
        reference: const ContentReferenceCodec().parse(
          engine: engine,
          site: Uri.parse(site),
          kind: ContentKind.group,
          sourceKey: key,
        ),
      );
      return ContentGroupBookmark(
        id: id,
        createdAt: second,
        observedAt: second,
        snapshot: StoredGroupSnapshot(
          summary: summary,
          index: upload == null
              ? null
              : GroupBookmarkIndex(
                  tags: const {},
                  basis: GroupTagIndexBasis.memberUnion,
                  coverage: MetadataCoverage.complete,
                  newestMemberUpload: upload,
                ),
        ),
      );
    }

    final work = groupRecord(
      3,
      BooruType.pixiv,
      'https://www.pixiv.net',
      'work:42',
    );
    final pool = groupRecord(
      4,
      BooruType.danbooru,
      'https://danbooru.donmai.us',
      'pool:42',
    );
    final relatedSource = groupRecord(
      5,
      BooruType.danbooru,
      'https://danbooru.donmai.us',
      'related:42',
      upload: latestReceived,
    );
    final related = RelatedBookmark(
      id: relatedSource.id,
      snapshot: relatedSource.snapshot,
      createdAt: relatedSource.createdAt,
      observedAt: relatedSource.observedAt,
    );
    final state = BookmarkLibraryState(
      bookmarks: const [],
      records: [post, receivedOnly, work, pool, related],
      groups: [
        BookmarkGroup(
          id: poolGroupA,
          name: 'Root',
          bookmarkIds: {post.id, work.id, pool.id, related.id},
          addedAt: {post.id: third, pool.id: first, related.id: second},
        ),
        BookmarkGroup(
          id: poolGroupB,
          name: 'Child',
          parentGroupId: poolGroupA,
          bookmarkIds: {work.id, pool.id},
          addedAt: {work.id: latestLocal, pool.id: second},
        ),
        BookmarkGroup(
          id: other,
          name: 'Other',
          bookmarkIds: {pool.id},
          addedAt: {pool.id: DateTime.utc(2025)},
        ),
        BookmarkGroup(
          id: received,
          name: 'Received',
          bookmarkIds: {receivedOnly.id, related.id},
          addedAt: {related.id: latestReceived},
        ),
      ],
      mirrors: BookmarkMirrorState(
        owners: {
          received: BookmarkMirrorOwner(
            publisher: poolProfile,
            source: received,
            revision: 1,
            payloadDigest: 'a' * 64,
            groupDigest: 'b' * 64,
          ),
        },
        epoch: 1,
      ),
    );
    final postKey = BookmarkPostEntry(post).key;
    final workKey = BookmarkNativeGroupEntry(work).key;
    Object collectionKey(ContentGroupBookmark record) => BookmarkPoolEntry(
      state.pools.singleWhere((p) => p.bookmarkId == record.id),
    ).key;
    final poolKey = collectionKey(pool);
    final relatedKey = collectionKey(related);
    expect(
      selectBookmarkGridEntries(
        state: state,
        view: BookmarkView.group(poolGroupA),
        selectedTags: const [],
        sortType: BookmarkSortType.newestUpload,
      ).first.key,
      relatedKey,
    );
    Iterable<Object> keys(BookmarkView view) => selectBookmarkMosaicEntries(
      state: state,
      view: view,
    ).map((entry) => entry.key);
    expect(keys(BookmarkView.group(poolGroupA)), [
      postKey,
      workKey,
      relatedKey,
      poolKey,
    ]);
    expect(keys(BookmarkView.subtree(poolGroupA)).take(2), [workKey, postKey]);
    expect(keys(const BookmarkView.all()), [
      poolKey,
      workKey,
      postKey,
      relatedKey,
    ]);
    expect(keys(BookmarkView.group(received)).first, relatedKey);
  });

  test(
    'Posts and typed references sort by current membership dates',
    () {
      final a = testPoolPost(1).copyWith(createdAt: old);
      final b = testPoolPost(2).copyWith(createdAt: first);
      final pool = testPool(groups: {poolGroupA})
          .copyWith(addedAt: {poolGroupA: second});
      final related = RelatedCollectionBookmark(
        family: RelatedFamilyReference(origin: poolOrigin(), anchorId: 42),
        localId: poolGroupB,
        createdAt: old,
        observedAt: old,
        groupIds: {poolGroupA},
        addedAt: {poolGroupA: first},
      );
      final state = BookmarkLibraryState(
        bookmarks: [a, b],
        pools: [pool, related],
        groups: [
          BookmarkGroup(
            id: poolGroupA,
            name: 'A',
            bookmarkIds: {a.id, b.id},
            addedAt: {a.id: third, b.id: old},
          ),
        ],
      );
      List<BookmarkGridEntry> select(
        BookmarkView view,
        BookmarkSortType sort,
      ) => selectBookmarkGridEntries(
        state: state,
        view: view,
        selectedTags: [],
        sortType: sort,
      );
      expect(
        select(
          BookmarkView.group(poolGroupA),
          BookmarkSortType.newest,
        ).map((e) => e.key),
        [
          BookmarkPostEntry(a).key,
          BookmarkPoolEntry(pool).key,
          BookmarkPoolEntry(related).key,
          BookmarkPostEntry(b).key,
        ],
      );
      expect(
        (select(const BookmarkView.all(), BookmarkSortType.newest).first
                as BookmarkPostEntry)
            .bookmark,
        a,
      );
      expect(
        selectBookmarks(
          state: state,
          view: BookmarkView.group(poolGroupA),
          selectedTags: [],
          sortType: BookmarkSortType.oldest,
        ).map((b) => b.id),
        [b.id, a.id],
      );
      expect(
        selectBookmarkPreviews(
          state: state,
          view: BookmarkView.group(poolGroupA),
          sortType: BookmarkSortType.newest,
        ).first.id,
        a.id,
      );
    },
  );

  test('collection repeat/refresh/removal/Undo/duplication retain membership dates', () async {
    final original = testPool(groups: {poolGroupA})
        .copyWith(addedAt: {poolGroupA: first});
    final added = original.withGroups({poolGroupA, poolGroupB}, now: second);
    expect(
      added.withGroups({
        poolGroupA,
        poolGroupB,
      }, now: third).addedAt[poolGroupB],
      second,
    );
    await groups.replacePoolBookmarks([added]);
    final removed = await service.removeBookmarksFromGroup(
      [],
      poolGroupB,
      poolLocalIds: {added.localId},
    );
    await service.undoRemoval(removed);
    expect((await groups.getPoolBookmarks()).single.addedAt, {
      poolGroupA: first,
      poolGroupB: second,
    });
    final copy = await service.duplicateGroup(poolGroupB, 'Pool copy');
    expect((await groups.getPoolBookmarks()).single.addedAt[copy.id], second);
    final metadata = testPool(groups: {})
        .withGroups(added.groupIds, addedAt: added.addedAt);
    expect(metadata.addedAt, added.addedAt);
    expect(
      added.withGroups({poolGroupA}).withGroups({
        poolGroupA,
        poolGroupB,
      }, now: third).addedAt[poolGroupB],
      third,
    );
  });

  test(
    'version 10 export/restore remaps local IDs and preserves membership dates',
    () async {
      final post = await seed(1);
      await service.addBookmarkToGroup(
        groupId: poolGroupA,
        existingBookmark: post,
      );
      now = second;
      await service.addBookmarkToGroup(
        groupId: poolGroupB,
        existingBookmark: post,
      );
      await groups.replacePoolBookmarks([
        testPool(groups: {poolGroupA, poolGroupB})
            .copyWith(addedAt: {poolGroupA: first, poolGroupB: second}),
      ]);
      final snapshot = await service.load();
      final data = buildBookmarkBackupData(
        bookmarks: snapshot.items,
        groups: snapshot.groups,
        pools: snapshot.pools,
        scope: const BookmarkExportScope.all(),
      );
      final codec = BookmarkBackupCodec();
      final restored = codec.parse(
        decodeData(
          data: jsonEncode({
            'version': kBookmarksBackupVersion,
            'data': codec.encode(data),
            ...data.extraFields,
          }),
        ),
      );
      await importer().replace(restored);
      final result = await service.load();
      final saved = result.items.single;
      expect(result.groupsById[poolGroupA]!.addedAt[saved.id], first);
      expect(result.groupsById[poolGroupB]!.addedAt[saved.id], second);
      expect(result.pools.single.addedAt, {
        poolGroupA: first,
        poolGroupB: second,
      });
      expect(saved.createdAt, post.createdAt);
    },
  );

  for (final action in [
    ImportAction.merge,
    ImportAction.copy,
    ImportAction.update,
    ImportAction.mergeIntoTarget,
  ]) {
    test(
      'import $action keeps existing merge dates and preserves incoming dates',
      () async {
        final post = await seed(1);
        await service.addBookmarkToGroup(
          groupId: poolGroupA,
          existingBookmark: post,
        );
        final data = BookmarkBackupData(
          bookmarks: [post],
          pools: [
            testPool(groups: {poolGroupA})
                .copyWith(addedAt: {poolGroupA: second}),
          ],
          groups: [
            BookmarkGroupBackup(
              id: poolGroupA,
              name: 'Incoming',
              bookmarkIds: [post.id],
              addedAt: {post.id: second},
            ),
          ],
        );
        final plan = const BookmarkImportPlanner().plan(
          data: data,
          currentBookmarks: [post],
          currentGroups: await groups.getGroups(),
        );
        final resolved = plan.resolveGroupAction(poolGroupA, action);
        await importer().apply(resolved);
        final all = await groups.getGroups();
        final target = action == ImportAction.copy
            ? all.firstWhere(
                (g) => g.id != poolGroupA && g.id != poolGroupB && !g.isDefault,
              )
            : await group(
                action == ImportAction.mergeIntoTarget
                    ? poolGroupB
                    : poolGroupA,
              );
        expect(
          target.addedAt[post.id],
          action == ImportAction.merge ? first : second,
        );
        expect(
          (await groups.getPoolBookmarks()).single.addedAt[target.id],
          second,
        );
      },
    );
  }

  test(
    'merging a legacy membership preserves its creation-date fallback',
    () async {
      final post = await seed(1);
      await groupsBox.put(
        poolGroupA,
        BookmarkGroupHiveObject(
          id: poolGroupA,
          name: 'A',
          bookmarkIds: [post.id],
        ),
      );
      final data = BookmarkBackupData(
        bookmarks: [post],
        groups: [
          BookmarkGroupBackup(
            id: poolGroupA,
            name: 'A',
            bookmarkIds: [post.id],
            addedAt: {post.id: second},
          ),
        ],
      );
      final plan = const BookmarkImportPlanner()
          .plan(
            data: data,
            currentBookmarks: [post],
            currentGroups: await groups.getGroups(),
          )
          .resolveGroupAction(poolGroupA, ImportAction.merge);
      await importer().apply(plan);
      expect((await group(poolGroupA)).addedAt[post.id], old);
    },
  );

  test(
    'import rollback restores dates after a later collection write fails',
    () async {
      final post = await seed(1);
      await service.addBookmarkToGroup(
        groupId: poolGroupA,
        existingBookmark: post,
      );
      final data = BookmarkBackupData(
        bookmarks: [post],
        groups: [
          BookmarkGroupBackup(
            id: poolGroupA,
            name: 'A',
            bookmarkIds: [post.id],
            addedAt: {post.id: second},
          ),
        ],
      );
      final plan = const BookmarkImportPlanner()
          .plan(
            data: data,
            currentBookmarks: [post],
            currentGroups: await groups.getGroups(),
          )
          .resolveGroupAction(poolGroupA, ImportAction.update);
      groups.failNext = true;
      await expectLater(importer().apply(plan), throwsStateError);
      expect((await group(poolGroupA)).addedAt[post.id], first);
    },
  );

  for (final raw in [
    {poolGroupA: 'bad'},
    {'unknown': '2022-01-01'},
    {poolGroupA: 12},
  ]) {
    test('invalid collection membership dates are rejected: $raw', () {
      expect(
        () => CollectionBookmark.fromJson({
          ...testPool().toJson(),
          'addedAt': raw,
        }),
        throwsFormatException,
      );
    });
  }

  for (final raw in [
    'invalid',
    {'1': 'bad'},
    {'99': '2022-01-01'},
    {'1': 12},
  ]) {
    test('malformed group timestamp $raw is rejected before writing', () {
      final post = testPoolPost(1);
      final codec = BookmarkBackupCodec();
      final data = BookmarkBackupData(bookmarks: [post], groups: const []);
      expect(
        () => codec.parse(
          decodeData(
            data: jsonEncode({
              'version': 6,
              'organizationSchema': 'nestedGroups',
              'data': codec.encode(data),
              'groups': [
                {
                  'id': poolGroupA,
                  'name': 'A',
                  'bookmarkIds': [1],
                  'addedAt': raw,
                  'parentGroupId': null,
                  'position': 0,
                },
              ],
            }),
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });
  }
}

class _Groups extends BookmarkGroupRepositoryHive {
  _Groups(super.box, {super.organizationBox, super.now});
  bool failNext = false;
  @override
  Future<void> writePoolBookmarks(List<CollectionBookmark> bookmarks) async {
    if (failNext) {
      failNext = false;
      throw StateError('Injected collection write failure');
    }
    await super.writePoolBookmarks(bookmarks);
  }
}

extension on BookmarkImportPlan {
  BookmarkImportPlan resolveGroupAction(String id, ImportAction action) =>
      resolveActions({
        id: groups
            .singleWhere((g) => g.id == id)
            .resolveAction(
              action,
              targetId: action == ImportAction.mergeIntoTarget
                  ? poolGroupB
                  : null,
              destinationId: action == ImportAction.copy ? poolProfile : null,
            ),
      });
}
