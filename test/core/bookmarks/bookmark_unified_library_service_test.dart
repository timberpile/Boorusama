import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/content/content_map.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/related/related_posts_order_value.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../support/fakes/bookmark_test_storage.dart';
import 'pool_bookmark_test_utils.dart';

void main() {
  late Directory directory;
  late Box<BookmarkHiveObject> posts;
  late Box<BookmarkGroupHiveObject> legacyGroups;
  late Box<dynamic> legacyOrganization;
  late BookmarkTestStorage storage;
  late BookmarkHiveRepository bookmarks;
  late UnifiedBookmarkGroupRepository groups;
  late BookmarkLibraryService service;

  ImageUrlResolver resolver(int? _) => const DefaultImageUrlResolver();

  Future<void> openBoxes() async {
    posts = await Hive.openBox<BookmarkHiveObject>('posts');
    legacyGroups = await Hive.openBox<BookmarkGroupHiveObject>('groups');
    legacyOrganization = await Hive.openBox<dynamic>('organization');
    storage = await BookmarkTestStorage.open(posts);
    bookmarks = storage.repository(posts);
  }

  Future<void> attachActiveRepository() async {
    final reader = await BookmarkStorageMigration(
      bookmarks: bookmarks,
      legacyGroups: legacyGroups,
      legacyOrganization: legacyOrganization,
      metadata: storage.metadataBox,
    ).open();
    groups = UnifiedBookmarkGroupRepository(
      bookmarks: bookmarks,
      reader: reader,
    );
    service = BookmarkLibraryService(
      bookmarkRepository: bookmarks,
      groupRepository: groups,
      imageUrlResolver: resolver,
    );
  }

  ContentGroupBookmark nativeGroup(int id, {String sourceKey = 'pool:42'}) {
    final reference = const ContentReferenceCodec().parse(
      engine: BooruType.danbooru,
      site: Uri.parse('https://danbooru.donmai.us/install'),
      kind: ContentKind.group,
      sourceKey: sourceKey,
    );
    return ContentGroupBookmark(
      id: id,
      snapshot: StoredGroupSnapshot(
        summary: ContentGroupSummary(reference: reference, title: 'Pool 42'),
        index: GroupBookmarkIndex(
          tags: const {'source-group-tag'},
          basis: GroupTagIndexBasis.sourceGroup,
          coverage: MetadataCoverage.complete,
        ),
      ),
      createdAt: DateTime.utc(2020, 1, 2),
      observedAt: DateTime.utc(2025, 3, 4),
    );
  }

  RelatedBookmark relatedGroup(int id) {
    final reference = const ContentReferenceCodec().parse(
      engine: BooruType.danbooru,
      site: Uri.parse('https://danbooru.donmai.us/install'),
      kind: ContentKind.group,
      sourceKey: 'related:900',
    );
    return RelatedBookmark(
      id: id,
      snapshot: StoredGroupSnapshot(
        summary: ContentGroupSummary(reference: reference),
        index: GroupBookmarkIndex(
          tags: const {'related-member-tag'},
          basis: GroupTagIndexBasis.memberUnion,
          coverage: MetadataCoverage.partial,
        ),
      ),
      createdAt: DateTime.utc(2021),
      observedAt: DateTime.utc(2025),
    );
  }

  LegacyGroupBookmark opaqueGroup(int id) => LegacyGroupBookmark.fromMetadata(
    id: id,
    metadata: PoolBookmark(
      localId: 'opaque-pool-777',
      origin: poolOrigin(host: 'legacy.example', type: BooruType.unknown),
      sourceTypeId: 777,
      poolId: 777,
      category: BookmarkedPoolCategory.series,
      title: 'Opaque Group',
      createdAt: DateTime.utc(2019, 7, 8),
      observedAt: DateTime.utc(2024, 9, 10),
      groupIds: const {},
      tags: const {'opaque-source-tag'},
      coverage: PoolTagCoverage.partial,
      total: 12,
    ),
  );

  Future<void> initialize() async {
    directory = await Directory.systemTemp.createTemp(
      'unified-library-service-',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4))
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    await openBoxes();
    final firstCreated = DateTime.utc(2010, 4, 5);
    final defaultCreated = DateTime.utc(2011, 6, 7);
    final firstDate = DateTime.utc(2024, 1, 2, 3, 4, 5, 123, 456);
    final secondDate = DateTime.utc(2025, 7, 8, 9, 10, 11, 789, 123);
    await posts.put(
      0,
      favoriteToHiveObject(
        testPoolPost(7).copyWith(id: 0, createdAt: firstCreated),
      ),
    );
    await posts.put(
      1,
      favoriteToHiveObject(
        testPoolPost(8).copyWith(id: 1, createdAt: defaultCreated),
      ),
    );
    final unaddressable = testPoolPost(88).copyWith(
      id: 4,
      createdAt: DateTime.utc(2012, 8, 9),
      postId: () => null,
    );
    await legacyGroups.put(
      poolGroupA,
      BookmarkGroupHiveObject(
        id: poolGroupA,
        name: 'A',
        bookmarkIds: [0],
        addedAt: {0: firstDate.toIso8601String()},
      ),
    );
    await legacyGroups.put(
      poolGroupB,
      BookmarkGroupHiveObject(
        id: poolGroupB,
        name: 'B',
        bookmarkIds: [0],
        addedAt: {0: secondDate.toIso8601String()},
      ),
    );
    await legacyOrganization.put('version', 1);
    await legacyOrganization.put('poolBookmarks', []);
    await BookmarkStorageMigration(
      bookmarks: bookmarks,
      legacyGroups: legacyGroups,
      legacyOrganization: legacyOrganization,
      metadata: storage.metadataBox,
    ).open();
    final reservedPrefix = await bookmarks.reserveIds(3);
    final extra = await bookmarks.reserveIds(3);
    final nativeId = extra[0];
    final relatedId = extra[1];
    final opaqueId = extra[2];
    await bookmarks.commitOrganization(
      records: [
        unaddressable,
        nativeGroup(nativeId),
        relatedGroup(relatedId),
        opaqueGroup(opaqueId),
      ],
      groups: [
        BookmarkGroup(
          id: poolGroupA,
          name: 'A',
          bookmarkIds: {0, nativeId, relatedId, opaqueId},
          addedAt: {
            0: firstDate,
            nativeId: DateTime.utc(2024, 3, 4),
            relatedId: DateTime.utc(2024, 5, 6),
            opaqueId: DateTime.utc(2024, 7, 8),
          },
        ),
        BookmarkGroup(
          id: poolGroupB,
          name: 'B',
          bookmarkIds: {0, nativeId, relatedId},
          addedAt: {
            0: secondDate,
            nativeId: DateTime.utc(2025, 4, 5),
            relatedId: DateTime.utc(2025, 6, 7),
          },
        ),
      ],
    );
    expect(reservedPrefix.last, 4);
    await attachActiveRepository();
  }

  Future<void> restart() async {
    await Hive.close();
    Hive.init(directory.path);
    await openBoxes();
    await attachActiveRepository();
  }

  setUp(initialize);
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('load preserves mixed records, memberships and dates across cold and warm reads', () async {
    final archivedPoolRows = legacyOrganization.get('poolBookmarks');
    final active = contentMap(
      storage.metadataBox.get(BookmarkStorageMigration.activeKey),
    );
    final generation = contentMap(active['generation']);
    final activeOrganization = await Hive.openBox<dynamic>(
      generation['organization']! as String,
    );
    final revisionBefore = await bookmarks.readRevision();

    final cold = await service.load();
    final native = cold.records
        .whereType<ContentGroupBookmark>()
        .where((record) => record is! RelatedBookmark)
        .single;
    final related = cold.records.whereType<RelatedBookmark>().single;
    final opaque = cold.records.whereType<LegacyGroupBookmark>().single;
    expect(cold.records.whereType<PostBookmark>().map((record) => record.id), [
      0,
      1,
      4,
    ]);
    expect(cold.records, hasLength(6));
    expect(cold.membershipsByBookmarkId[0], {poolGroupA, poolGroupB});
    expect(cold.membershipsByBookmarkId[native.id], {poolGroupA, poolGroupB});
    expect(cold.membershipsByBookmarkId[related.id], {poolGroupA, poolGroupB});
    expect(cold.membershipsByBookmarkId[opaque.id], {poolGroupA});
    expect(cold.membershipsByBookmarkId[1], {defaultBookmarkGroupId});
    expect(cold.membershipsByBookmarkId[4], {defaultBookmarkGroupId});

    final groupA = cold.groupsById[poolGroupA]!;
    final groupB = cold.groupsById[poolGroupB]!;
    final defaultGroup = cold.groupsById[defaultBookmarkGroupId]!;
    expect(groupA.bookmarkIds, {0, native.id, related.id, opaque.id});
    expect(groupB.bookmarkIds, {0, native.id, related.id});
    expect(groupA.addedAt[0], DateTime.utc(2024, 1, 2, 3, 4, 5, 123, 456));
    expect(groupB.addedAt[0], DateTime.utc(2025, 7, 8, 9, 10, 11, 789, 123));
    expect(groupA.addedAt[native.id], DateTime.utc(2024, 3, 4));
    expect(groupB.addedAt[native.id], DateTime.utc(2025, 4, 5));
    expect(groupA.addedAt[related.id], DateTime.utc(2024, 5, 6));
    expect(groupB.addedAt[related.id], DateTime.utc(2025, 6, 7));
    expect(groupA.addedAt[opaque.id], DateTime.utc(2024, 7, 8));
    expect(defaultGroup.bookmarkIds, {1, 4});
    expect(defaultGroup.addedAt[1], DateTime.utc(2011, 6, 7));
    expect(defaultGroup.addedAt[4], DateTime.utc(2012, 8, 9));

    expect(cold.pools, hasLength(3));
    final projectedPool = cold.pools.singleWhere(
      (pool) => pool.bookmarkId == native.id,
    );
    expect(projectedPool.groupIds, {poolGroupA, poolGroupB});
    expect(projectedPool.addedAt, {
      poolGroupA: groupA.addedAt[native.id],
      poolGroupB: groupB.addedAt[native.id],
    });
    final projectedOpaque = cold.pools.singleWhere(
      (pool) => pool.bookmarkId == opaque.id,
    );
    expect(projectedOpaque.sourceSite, isNull);
    expect(projectedOpaque.groupIds, {poolGroupA});
    expect(legacyOrganization.get('poolBookmarks'), archivedPoolRows);
    expect(activeOrganization.containsKey('poolBookmarks'), isFalse);
    expect(cold.revision, revisionBefore + 1);

    final warm = await service.load();
    expect(warm, cold);
    expect(warm.revision, cold.revision);
    expect(await bookmarks.readRevision(), cold.revision);

    await restart();
    final reopened = await service.load();
    expect(reopened, cold);
    expect(reopened.revision, cold.revision);
    expect(legacyOrganization.get('poolBookmarks'), archivedPoolRows);
  });

  test('mixed Group removal and Undo preserve independent dates and rekey last memberships', () async {
    final before = await service.load();
    final native = before.records
        .whereType<ContentGroupBookmark>()
        .where((record) => record is! RelatedBookmark)
        .single;
    final related = before.records.whereType<RelatedBookmark>().single;
    final opaque = before.records.whereType<LegacyGroupBookmark>().single;
    final firstDate = DateTime.utc(2024, 1, 2, 3, 4, 5, 123, 456);
    final nativeA = DateTime.utc(2024, 3, 4);
    final nativeB = DateTime.utc(2025, 4, 5);
    final relatedA = DateTime.utc(2024, 5, 6);
    final relatedB = DateTime.utc(2025, 6, 7);
    final opaqueA = DateTime.utc(2024, 7, 8);

    final removal = await service.removeBookmarksFromGroup(
      [before.byId[0]!, native, related, opaque],
      poolGroupA,
    );
    expect(removal.removedRecords.map((record) => record.id).toSet(), {
      0,
      native.id,
      related.id,
      opaque.id,
    });
    expect(removal.deletedRecords.map((record) => record.id), [opaque.id]);
    expect(removal.recordAddedAt, {
      0: firstDate,
      native.id: nativeA,
      related.id: relatedA,
      opaque.id: opaqueA,
    });

    final afterRemoval = await service.load();
    expect(afterRemoval.records.map((record) => record.id), [
      0,
      1,
      4,
      native.id,
      related.id,
    ]);
    expect(afterRemoval.groupsById[poolGroupA]!.bookmarkIds, isEmpty);
    expect(afterRemoval.groupsById[poolGroupB]!.bookmarkIds, {
      0,
      native.id,
      related.id,
    });
    expect(
      afterRemoval.groupsById[poolGroupB]!.addedAt[0],
      DateTime.utc(2025, 7, 8, 9, 10, 11, 789, 123),
    );
    expect(afterRemoval.groupsById[poolGroupB]!.addedAt[native.id], nativeB);
    expect(afterRemoval.groupsById[poolGroupB]!.addedAt[related.id], relatedB);
    expect(
      afterRemoval.groupsById[defaultBookmarkGroupId]!.addedAt[4],
      DateTime.utc(2012, 8, 9),
    );

    await service.undoRemoval(removal);
    final restored = await service.load();
    final restoredOpaque = restored.records
        .whereType<LegacyGroupBookmark>()
        .single;
    expect(restoredOpaque.id, greaterThan(opaque.id));
    expect(restoredOpaque.metadata.origin, opaque.metadata.origin);
    expect(restoredOpaque.metadata.sourceTypeId, 777);
    expect(restoredOpaque.metadata.referenceId, 777);
    expect(restoredOpaque.metadata.title, opaque.metadata.title);
    expect(restoredOpaque.metadata.tags, opaque.metadata.tags);
    expect(restoredOpaque.createdAt, opaque.createdAt);
    expect(restored.groupsById[poolGroupA]!.bookmarkIds, {
      0,
      native.id,
      related.id,
      restoredOpaque.id,
    });
    expect(restored.groupsById[poolGroupA]!.addedAt[0], firstDate);
    expect(restored.groupsById[poolGroupA]!.addedAt[native.id], nativeA);
    expect(restored.groupsById[poolGroupA]!.addedAt[related.id], relatedA);
    expect(
      restored.groupsById[poolGroupA]!.addedAt[restoredOpaque.id],
      opaqueA,
    );
    expect(restored.groupsById[poolGroupB]!.addedAt[native.id], nativeB);
    expect(restored.groupsById[poolGroupB]!.addedAt[related.id], relatedB);
  });

  test('duplicate Group copies per-record dates and folder deletion keeps shared records', () async {
    final before = await service.load();
    final source = before.groupsById[poolGroupA]!;
    final duplicateSource = before.groupsById[poolGroupB]!;
    final folder = await service.createFolder('Mixed collection');
    await service.moveFolderItems(
      groupIds: {poolGroupA},
      destination: folder.id,
    );
    final duplicate = await service.duplicateGroup(poolGroupB, 'B copy');
    expect(duplicate.bookmarkIds, duplicateSource.bookmarkIds);
    expect(duplicate.addedAt, duplicateSource.addedAt);

    final preview = await service.previewDeleteSelection(
      folderIds: {folder.id},
      groupIds: {poolGroupA},
    );
    await service.deleteSelection(preview);
    final after = await service.load();
    final native = after.records
        .whereType<ContentGroupBookmark>()
        .where((record) => record is! RelatedBookmark)
        .single;
    final related = after.records.whereType<RelatedBookmark>().single;
    final opaqueId = source.bookmarkIds.singleWhere(
      (id) => id != 0 && id != native.id && id != related.id,
    );

    expect(after.groupsById.containsKey(poolGroupA), isFalse);
    expect(after.folders, isEmpty);
    expect(
      after.groupsById[duplicate.id]!.bookmarkIds,
      duplicateSource.bookmarkIds,
    );
    expect(after.groupsById[duplicate.id]!.addedAt, duplicateSource.addedAt);
    expect(after.byId.containsKey(opaqueId), isFalse);
    expect(after.byId.containsKey(0), isTrue);
    expect(after.byId.containsKey(native.id), isTrue);
    expect(after.byId.containsKey(related.id), isTrue);
    expect(after.groupsById[poolGroupB]!.bookmarkIds, {
      0,
      native.id,
      related.id,
    });
    expect(
      after.groupsById[poolGroupB]!.addedAt[native.id],
      DateTime.utc(2025, 4, 5),
    );
    expect(
      after.groupsById[poolGroupB]!.addedAt[related.id],
      DateTime.utc(2025, 6, 7),
    );
    expect(
      after.groupsById[defaultBookmarkGroupId]!.addedAt[4],
      DateTime.utc(2012, 8, 9),
    );
  });

  test(
    'saving drafts remaps incoming ids and keeps known records on repeat',
    () async {
      final before = await service.load();
      final originalPost = testPoolPost(91).copyWith(id: 0);
      final originalPool = nativeGroup(1, sourceKey: 'pool:43');
      final opaque = opaqueGroup(2);
      final revisionBefore = await bookmarks.readRevision();

      final saved = await service.saveDraftsToGroup(
        [originalPost, originalPool, opaque],
        poolGroupA,
      );

      expect(saved.addedCount, 3);
      expect(saved.createdRecords, hasLength(3));
      expect(
        saved.createdRecords.map((record) => record.id).toSet(),
        hasLength(3),
      );
      expect(saved.createdRecords.every((record) => record.id > 7), isTrue);
      final savedPost = saved.createdRecords.whereType<PostBookmark>().single;
      final savedPool = saved.createdRecords
          .whereType<ContentGroupBookmark>()
          .single;
      final savedOpaque = saved.createdRecords
          .whereType<LegacyGroupBookmark>()
          .single;
      expect(savedPost.id, isNot(originalPost.id));
      expect(savedPool.id, isNot(originalPool.id));
      expect(savedOpaque.id, isNot(opaque.id));
      expect(await bookmarks.readRevision(), revisionBefore + 1);

      final savedState = await service.load();
      final savedDates = {
        for (final record in saved.createdRecords)
          record.id: savedState.groupsById[poolGroupA]!.addedAt[record.id],
      };
      expect(
        savedState.groupsById[poolGroupA]!.bookmarkIds,
        containsAll(savedDates.keys),
      );
      expect(savedDates.values.every((date) => date != null), isTrue);

      final repeated = await service.saveDraftsToGroup(
        [originalPost, originalPool],
        poolGroupA,
      );
      expect(repeated.addedCount, 0);
      expect(repeated.createdRecords, isEmpty);
      expect(await bookmarks.readRevision(), revisionBefore + 1);
      final repeatedState = await service.load();
      expect(repeatedState.groupsById[poolGroupA]!.addedAt, {
        ...savedState.groupsById[poolGroupA]!.addedAt,
      });
      expect(repeatedState.byId[savedPost.id], savedPost);
      expect(repeatedState.byId[savedPool.id], savedPool);
      expect(repeatedState.byId[savedOpaque.id], savedOpaque);
      expect(before.byId.containsKey(savedPost.id), isFalse);
    },
  );

  test('saving a known content identity with another engine fails before allocation', () async {
    final before = await service.load();
    final revisionBefore = await bookmarks.readRevision();
    final counterBefore = contentMap(
      storage.metadataBox.get('idReservation'),
    )['nextId'];
    final reference = const ContentReferenceCodec().parse(
      engine: BooruType.szurubooru,
      site: Uri.parse('https://danbooru.donmai.us/install'),
      kind: ContentKind.group,
      sourceKey: 'pool:42',
    );
    final otherEngineDraft = ContentGroupBookmark(
      id: 500,
      snapshot: StoredGroupSnapshot(
        summary: ContentGroupSummary(reference: reference, title: 'Pool 42'),
        index: GroupBookmarkIndex(
          tags: const {'source-group-tag'},
          basis: GroupTagIndexBasis.sourceGroup,
          coverage: MetadataCoverage.complete,
        ),
      ),
      createdAt: DateTime.utc(2020, 1, 2),
      observedAt: DateTime.utc(2025, 3, 4),
    );
    expect(
      before.records
          .whereType<ContentGroupBookmark>()
          .where((record) => record is! RelatedBookmark)
          .single
          .snapshot
          .summary
          .reference
          .engine,
      BooruType.danbooru,
    );

    await expectLater(
      service.saveDraftsToGroup([otherEngineDraft], poolGroupA),
      throwsFormatException,
    );

    expect(
      contentMap(storage.metadataBox.get('idReservation'))['nextId'],
      counterBefore,
    );
    expect(await bookmarks.readRevision(), revisionBefore);
    expect(await service.load(), before);
  });

  test(
    'identical opaque drafts remain distinct and do not gain a source site',
    () async {
      await service.load();
      final revisionBefore = await bookmarks.readRevision();
      final firstDraft = opaqueGroup(3);
      final secondDraft = opaqueGroup(3);

      final saved = await service.saveDraftsToGroup(
        [firstDraft, secondDraft],
        poolGroupA,
      );

      expect(saved.addedCount, 2);
      expect(saved.createdRecords, hasLength(2));
      expect(
        saved.createdRecords.map((record) => record.id).toSet(),
        hasLength(2),
      );
      expect(saved.createdRecords.every((record) => record.id > 7), isTrue);
      expect(await bookmarks.readRevision(), revisionBefore + 1);
      final state = await service.load();
      expect(
        saved.createdRecords.every((record) => record is LegacyGroupBookmark),
        isTrue,
      );
      expect(
        saved.createdRecords.every(
          (record) =>
              (record as LegacyGroupBookmark).metadata.origin.sourceHost ==
              'legacy.example',
        ),
        isTrue,
      );
      expect(
        state.pools
            .where(
              (pool) =>
                  saved.createdRecords.any((r) => r.id == pool.bookmarkId),
            )
            .every((pool) => pool.sourceSite == null),
        isTrue,
      );
      expect(
        state.groupsById[poolGroupA]!.bookmarkIds,
        containsAll(saved.createdRecords.map((record) => record.id)),
      );
    },
  );

  test(
    'saved opaque records attach by frozen local ID without allocation',
    () async {
      final state = await service.load();
      final opaque = state.records.whereType<LegacyGroupBookmark>().single;
      final counterBefore = contentMap(
        storage.metadataBox.get('idReservation'),
      )['nextId'];
      final firstGroupDate = state.groupsById[poolGroupA]!.addedAt[opaque.id];
      expect(
        state.groupsById[poolGroupB]!.bookmarkIds,
        isNot(contains(opaque.id)),
      );

      final result = await service.saveDraftsToGroup(
        const [],
        poolGroupB,
        savedRecords: [opaque],
      );

      expect(result.addedCount, 1);
      expect(result.createdRecords, isEmpty);
      expect(
        contentMap(storage.metadataBox.get('idReservation'))['nextId'],
        counterBefore,
      );
      final after = await service.load();
      expect(after.byId[opaque.id], opaque);
      expect(after.groupsById[poolGroupA]!.addedAt[opaque.id], firstGroupDate);
      expect(after.groupsById[poolGroupB]!.bookmarkIds, contains(opaque.id));
      expect(after.groupsById[poolGroupB]!.addedAt[opaque.id], isNotNull);
    },
  );

  test(
    'Related order changes preserve snapshots and membership dates',
    () async {
      final before = await service.load();
      final related = before.records.whereType<RelatedBookmark>().single;
      final groupADates = before.groupsById[poolGroupA]!.addedAt;
      final groupBDates = before.groupsById[poolGroupB]!.addedAt;

      await service.setRelatedOrder(related.id, RelatedPostsOrder.oldest);
      final updated = (await bookmarks.read(related.id))! as RelatedBookmark;
      expect(updated.preferredOrder, RelatedPostsOrder.oldest);
      expect(updated.snapshot, related.snapshot);
      expect(updated.observedAt, related.observedAt);
      var after = await service.load();
      expect(after.groupsById[poolGroupA]!.addedAt, groupADates);
      expect(after.groupsById[poolGroupB]!.addedAt, groupBDates);

      final revision = await bookmarks.readRevision();
      await service.setRelatedOrder(related.id, RelatedPostsOrder.oldest);
      expect(await bookmarks.readRevision(), revision);
      await expectLater(
        service.setRelatedOrder(0, RelatedPostsOrder.oldest),
        throwsStateError,
      );
      final native = before.records
          .whereType<ContentGroupBookmark>()
          .where((record) => record is! RelatedBookmark)
          .single;
      await expectLater(
        service.setRelatedOrder(native.id, RelatedPostsOrder.oldest),
        throwsStateError,
      );
      expect(await bookmarks.readRevision(), revision);
      after = await service.load();
      expect(
        (after.byId[related.id]! as RelatedBookmark).preferredOrder,
        RelatedPostsOrder.oldest,
      );
      expect(after.groupsById[poolGroupA]!.addedAt, groupADates);
      expect(after.groupsById[poolGroupB]!.addedAt, groupBDates);
    },
  );

  test('native Group snapshot refresh preserves cached data and rejects identity changes', () async {
    final before = await service.load();
    final native = before.records
        .whereType<ContentGroupBookmark>()
        .where((record) => record is! RelatedBookmark)
        .single;
    final groupADates = before.groupsById[poolGroupA]!.addedAt;
    final groupBDates = before.groupsById[poolGroupB]!.addedAt;
    final description = const GroupDescription(
      text: 'Cached details',
      format: GroupTextFormat.plainText,
    );
    final details = ContentGroupDetails(
      summary: native.summary,
      description: description,
      creators: [CreatorRef(displayName: 'Saved creator')],
    );
    final index = GroupBookmarkIndex(
      tags: const {'saved-index-tag'},
      basis: GroupTagIndexBasis.sourceGroup,
      coverage: MetadataCoverage.complete,
    );
    final hydratedAt = DateTime.utc(2026, 2, 3);
    await service.updateGroupSnapshot(
      native.id,
      StoredGroupSnapshot(
        summary: native.summary,
        details: details,
        index: index,
      ),
      observedAt: hydratedAt,
    );
    final refreshedSummary = ContentGroupSummary(
      reference: native.reference,
      title: 'Refreshed pool title',
    );
    final refreshedAt = DateTime.utc(2026, 4, 5);
    await service.updateGroupSnapshot(
      native.id,
      StoredGroupSnapshot(summary: refreshedSummary),
      observedAt: refreshedAt,
    );
    final refreshed =
        (await bookmarks.read(native.id))! as ContentGroupBookmark;
    expect(refreshed.summary.title, 'Refreshed pool title');
    expect(refreshed.snapshot.details!.description, description);
    expect(refreshed.snapshot.details!.creators, details.creators);
    expect(refreshed.snapshot.details!.summary, refreshed.summary);
    expect(refreshed.snapshot.index, index);
    expect(refreshed.observedAt, refreshedAt);
    final revisionBeforeRejectedSnapshots = await bookmarks.readRevision();

    final wrongKey = const ContentReferenceCodec().parse(
      engine: BooruType.danbooru,
      site: native.reference.site,
      kind: ContentKind.group,
      sourceKey: 'pool:44',
    );
    await expectLater(
      service.updateGroupSnapshot(
        native.id,
        StoredGroupSnapshot(summary: ContentGroupSummary(reference: wrongKey)),
        observedAt: DateTime.utc(2030),
      ),
      throwsFormatException,
    );
    final wrongEngine = const ContentReferenceCodec().parse(
      engine: BooruType.szurubooru,
      site: native.reference.site,
      kind: ContentKind.group,
      sourceKey: 'pool:42',
    );
    await expectLater(
      service.updateGroupSnapshot(
        native.id,
        StoredGroupSnapshot(
          summary: ContentGroupSummary(reference: wrongEngine),
        ),
        observedAt: DateTime.utc(2031),
      ),
      throwsFormatException,
    );
    expect(await bookmarks.readRevision(), revisionBeforeRejectedSnapshots);
    final unchanged =
        (await bookmarks.read(native.id))! as ContentGroupBookmark;
    expect(unchanged, refreshed);
    final authoritativeAt = DateTime.utc(2026, 6, 7);
    await service.updateGroupSnapshot(
      native.id,
      StoredGroupSnapshot(summary: refreshedSummary),
      observedAt: authoritativeAt,
      authoritative: true,
    );
    final authoritative =
        (await bookmarks.read(native.id))! as ContentGroupBookmark;
    expect(authoritative.snapshot.details, isNull);
    expect(authoritative.snapshot.index, isNull);
    expect(authoritative.observedAt, authoritativeAt);

    final related = before.records.whereType<RelatedBookmark>().single;
    await service.setRelatedOrder(related.id, RelatedPostsOrder.newest);
    final relatedBeforeSummaryUpdate =
        (await bookmarks.read(related.id))! as RelatedBookmark;
    final revisionBeforeRelatedSummary = await bookmarks.readRevision();
    final relatedSummary = ContentGroupSummary(
      reference: related.reference,
      title: 'Updated Related summary',
    );
    await service.updateGroupSnapshot(
      related.id,
      StoredGroupSnapshot(summary: relatedSummary),
    );
    final relatedAfter = (await bookmarks.read(related.id))! as RelatedBookmark;
    expect(relatedAfter.preferredOrder, RelatedPostsOrder.newest);
    expect(
      relatedAfter.observedAt,
      isNot(relatedBeforeSummaryUpdate.observedAt),
    );
    expect(
      await bookmarks.readRevision(),
      revisionBeforeRelatedSummary + 1,
    );
    final after = await service.load();
    expect(after.groupsById[poolGroupA]!.addedAt, groupADates);
    expect(after.groupsById[poolGroupB]!.addedAt, groupBDates);
  });
}
