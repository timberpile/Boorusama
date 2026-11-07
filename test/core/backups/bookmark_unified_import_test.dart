import 'dart:io';
import 'dart:convert';

import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/export_import/import/bookmark_profile_dependency.dart';
import 'package:boorusama/core/backups/sources/bookmark_unified_import.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_planned_change_projector.dart';
import 'package:boorusama/core/backups/export_import/import/profile_dependency_planner.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_record_fields.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_plan.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_planner.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_service.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_tree.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/content_map.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/related/related_posts_order_value.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../support/fakes/bookmark_test_storage.dart';
import '../bookmarks/pool_bookmark_test_utils.dart';

const _newGroupId = '550e8400-e29b-41d4-a716-446655440010';
const _copyGroupId = '550e8400-e29b-41d4-a716-446655440011';
const _mergeSourceGroupId = '550e8400-e29b-41d4-a716-446655440012';
const _folderRootId = '550e8400-e29b-41d4-a716-446655440013';
const _folderChildId = '550e8400-e29b-41d4-a716-446655440014';

void main() {
  late Directory directory;
  late Box<BookmarkHiveObject> posts;
  late Box<BookmarkGroupHiveObject> legacyGroups;
  late Box<dynamic> legacyOrganization;
  late BookmarkTestStorage storage;
  late BookmarkHiveRepository bookmarks;
  late UnifiedBookmarkGroupRepository groups;
  late PostBookmark localPost;
  late ContentGroupBookmark localPool;
  late RelatedBookmark localRelated;
  late LegacyGroupBookmark localOpaque;
  late DateTime postA;
  late DateTime postB;
  late DateTime poolA;
  late DateTime poolB;
  late DateTime relatedA;
  late DateTime relatedB;
  late DateTime opaqueA;

  Future<void> openBoxes() async {
    posts = await Hive.openBox<BookmarkHiveObject>('posts');
    legacyGroups = await Hive.openBox<BookmarkGroupHiveObject>('groups');
    legacyOrganization = await Hive.openBox<dynamic>('organization');
    storage = await BookmarkTestStorage.open(posts);
    bookmarks = storage.repository(posts);
  }

  ContentGroupBookmark poolRecord(int id, {String sourceKey = 'pool:42'}) {
    final reference = const ContentReferenceCodec().parse(
      engine: BooruType.danbooru,
      site: Uri.parse('https://danbooru.donmai.us/install'),
      kind: ContentKind.group,
      sourceKey: sourceKey,
    );
    final summary = ContentGroupSummary(
      reference: reference,
      title: 'Stored pool',
    );
    final details = ContentGroupDetails(
      summary: summary,
      description: const GroupDescription(
        text: 'Saved pool details',
        format: GroupTextFormat.plainText,
      ),
      creators: [CreatorRef(displayName: 'Saved creator')],
    );
    return ContentGroupBookmark(
      id: id,
      snapshot: StoredGroupSnapshot(
        summary: summary,
        details: details,
        index: GroupBookmarkIndex(
          tags: const {'saved-pool-tag'},
          basis: GroupTagIndexBasis.sourceGroup,
          coverage: MetadataCoverage.complete,
        ),
      ),
      createdAt: DateTime.utc(2020, 1, 2),
      observedAt: DateTime.utc(2025, 3, 4),
    );
  }

  RelatedBookmark relatedRecord(int id, {String title = 'Stored Related'}) {
    final reference = const ContentReferenceCodec().parse(
      engine: BooruType.danbooru,
      site: Uri.parse('https://danbooru.donmai.us/install'),
      kind: ContentKind.group,
      sourceKey: 'related:900',
    );
    final summary = ContentGroupSummary(reference: reference, title: title);
    final details = ContentGroupDetails(
      summary: summary,
      description: const GroupDescription(
        text: 'Saved Related details',
        format: GroupTextFormat.dtext,
      ),
      creators: [CreatorRef(displayName: 'Related creator')],
    );
    return RelatedBookmark(
      id: id,
      snapshot: StoredGroupSnapshot(
        summary: summary,
        details: details,
        index: GroupBookmarkIndex(
          tags: const {'related-source-tag'},
          basis: GroupTagIndexBasis.memberUnion,
          coverage: MetadataCoverage.partial,
        ),
      ),
      createdAt: DateTime.utc(2021, 2, 3),
      observedAt: DateTime.utc(2025, 4, 5),
      preferredOrder: RelatedPostsOrder.oldest,
    );
  }

  LegacyGroupBookmark opaqueRecord(int id) => LegacyGroupBookmark.fromMetadata(
    id: id,
    metadata: PoolBookmark(
      localId: 'opaque-source-777',
      origin: poolOrigin(host: 'legacy.example', type: BooruType.unknown),
      sourceTypeId: 777,
      poolId: 777,
      category: BookmarkedPoolCategory.series,
      title: 'Opaque legacy group',
      createdAt: DateTime.utc(2019, 7, 8),
      observedAt: DateTime.utc(2024, 9, 10),
      groupIds: const {},
      tags: const {'opaque-tag'},
      coverage: PoolTagCoverage.partial,
      total: 12,
    ),
  );

  BookmarkGroup withMember(
    BookmarkGroup group,
    int id,
    DateTime date,
  ) => group.copyWith(
    bookmarkIds: {...group.bookmarkIds, id},
    addedAt: {...group.addedAt, id: date},
  );

  Future<void> initialize() async {
    directory = await Directory.systemTemp.createTemp(
      'bookmark-unified-import-',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    await openBoxes();
    postA = DateTime.utc(2024, 1, 2, 3, 4, 5, 123, 456);
    postB = DateTime.utc(2025, 2, 3, 4, 5, 6, 789, 123);
    poolA = DateTime.utc(2024, 3, 4, 5, 6, 7);
    poolB = DateTime.utc(2025, 4, 5, 6, 7, 8);
    relatedA = DateTime.utc(2024, 5, 6, 7, 8, 9);
    relatedB = DateTime.utc(2025, 6, 7, 8, 9, 10);
    opaqueA = DateTime.utc(2024, 7, 8, 9, 10, 11);
    localPost = testPoolPost(7).copyWith(id: 0);
    await posts.put(0, favoriteToHiveObject(localPost));
    await legacyGroups.put(
      poolGroupA,
      BookmarkGroupHiveObject(
        id: poolGroupA,
        name: 'A',
        bookmarkIds: [0],
        addedAt: {0: postA.toIso8601String()},
      ),
    );
    await legacyGroups.put(
      poolGroupB,
      BookmarkGroupHiveObject(
        id: poolGroupB,
        name: 'B',
        bookmarkIds: [0],
        addedAt: {0: postB.toIso8601String()},
      ),
    );
    await legacyOrganization.put('version', 1);
    await legacyOrganization.put('poolBookmarks', []);
    final reader = await BookmarkStorageMigration(
      bookmarks: bookmarks,
      legacyGroups: legacyGroups,
      legacyOrganization: legacyOrganization,
      metadata: storage.metadataBox,
    ).open();
    final reserved = await bookmarks.reserveIds(7);
    localRelated = relatedRecord(reserved[5]);
    localPool = poolRecord(reserved[6]);
    localOpaque = opaqueRecord(reserved[4]);
    final sourceA = (await reader.getGroup(poolGroupA))!;
    final sourceB = (await reader.getGroup(poolGroupB))!;
    await bookmarks.commitOrganization(
      records: [localRelated, localPool, localOpaque],
      groups: [
        withMember(
          withMember(
            withMember(sourceA, localPool.id, poolA),
            localRelated.id,
            relatedA,
          ),
          localOpaque.id,
          opaqueA,
        ),
        withMember(
          withMember(sourceB, localPool.id, poolB),
          localRelated.id,
          relatedB,
        ),
      ],
    );
    groups = UnifiedBookmarkGroupRepository(
      bookmarks: bookmarks,
      reader: reader,
    );
  }

  Future<void> restart() async {
    await Hive.close();
    Hive.init(directory.path);
    await openBoxes();
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
  }

  const planner = BookmarkImportPlanner();
  BookmarkImportService service() => BookmarkImportService(
    bookmarkRepository: bookmarks,
    groupRepository: groups,
    imageUrlResolver: (_) => const DefaultImageUrlResolver(),
  );

  Future<BookmarkImportPlan> plan(BookmarkBackupData data) async =>
      planner.plan(
        data: data,
        currentBookmarks: await bookmarks.readAll(),
        currentGroups: await groups.getGroups(),
      );

  setUp(initialize);
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('file Post ID colliding with a native Group ID resolves by content identity', () async {
    final importedPost = testPoolPost(7).copyWith(
      id: localPool.id,
      createdAt: DateTime.utc(2018, 8, 9),
    );
    final membershipDate = DateTime.utc(2026, 1, 2, 3, 4, 5, 678, 901);
    final importData = BookmarkBackupData.unified(
      records: [importedPost],
      groups: [
        BookmarkGroupBackup(
          id: _newGroupId,
          name: 'Imported Post',
          bookmarkIds: [importedPost.id],
          addedAt: {importedPost.id: membershipDate},
        ),
      ],
    );
    final importPlan = await plan(importData);
    final counterBefore = contentMap(
      storage.metadataBox.get('idReservation'),
    )['nextId'];

    await service().apply(importPlan);

    expect(importPlan.alreadyExistedCount, 1);
    expect(await bookmarks.read(0), localPost);
    expect(await bookmarks.read(localPool.id), localPool);
    final copiedGroup = (await groups.getGroups()).singleWhere(
      (group) => group.name == 'Imported Post',
    );
    expect(copiedGroup.bookmarkIds, {localPost.id});
    expect(copiedGroup.addedAt[localPost.id], membershipDate);
    expect(
      contentMap(storage.metadataBox.get('idReservation'))['nextId'],
      counterBefore,
    );
  });

  test(
    'opaque and unaddressable imported records receive independent fresh IDs',
    () async {
      final opaqueOne = opaqueRecord(localPool.id);
      final opaqueTwo = opaqueRecord(localPool.id + 1);
      final unaddressable = testPoolPost(88).copyWith(
        id: localPool.id + 2,
        postId: () => null,
      );
      final importedDates = {
        opaqueOne.id: DateTime.utc(2026, 1, 1),
        opaqueTwo.id: DateTime.utc(2026, 2, 2),
        unaddressable.id: DateTime.utc(2026, 3, 3),
      };
      final importPlan = await plan(
        BookmarkBackupData.unified(
          records: [opaqueOne, opaqueTwo, unaddressable],
          groups: [
            BookmarkGroupBackup(
              id: _newGroupId,
              name: 'Opaque imports',
              bookmarkIds: [opaqueOne.id, opaqueTwo.id, unaddressable.id],
              addedAt: importedDates,
            ),
          ],
        ),
      );

      await service().apply(importPlan);

      expect(await bookmarks.read(localPool.id), localPool);
      final importedGroup = (await groups.getGroups()).singleWhere(
        (group) => group.name == 'Opaque imports',
      );
      expect(importedGroup.bookmarkIds, hasLength(3));
      expect(
        importedGroup.bookmarkIds.every((id) => id > localPool.id),
        isTrue,
      );
      expect(
        importedGroup.addedAt.values.toSet(),
        importedDates.values.toSet(),
      );
      final importedRecords = [
        for (final id in importedGroup.bookmarkIds) (await bookmarks.read(id))!,
      ];
      final opaqueRecords = importedRecords
          .whereType<LegacyGroupBookmark>()
          .toList();
      expect(opaqueRecords, hasLength(2));
      expect(opaqueRecords.map((record) => record.id).toSet(), hasLength(2));
      expect(
        opaqueRecords.every((record) => record.metadata.sourceSite == null),
        isTrue,
      );
      final savedUnaddressable = importedRecords
          .whereType<PostBookmark>()
          .single;
      expect(savedUnaddressable.postId, isNull);
      expect(savedUnaddressable.id, isNot(unaddressable.id));
      expect(
        legacyOrganization.get('poolBookmarks'),
        isEmpty,
      );
    },
  );

  test('known Related import merges membership dates without replacing saved details or order', () async {
    final imported = relatedRecord(90, title: 'Incoming Related').copyWith(
      preferredOrder: () => RelatedPostsOrder.newest,
      snapshot: StoredGroupSnapshot(
        summary: ContentGroupSummary(
          reference: localRelated.reference,
          title: 'Incoming Related',
        ),
      ),
    );
    final aDate = DateTime.utc(2026, 4, 5, 6, 7, 8);
    final importPlan = await plan(
      BookmarkBackupData.unified(
        records: [imported],
        groups: [
          BookmarkGroupBackup(
            id: poolGroupA,
            name: 'Incoming name',
            bookmarkIds: [imported.id],
            addedAt: {imported.id: aDate},
          ),
        ],
      ),
    );
    final resolved = importPlan.resolveActions({
      poolGroupA: importPlan.groups.single.resolveAction(ImportAction.merge),
    });

    await service().apply(resolved);

    final stored = (await bookmarks.read(localRelated.id))! as RelatedBookmark;
    expect(stored, localRelated);
    expect(
      stored.snapshot.details!.description,
      localRelated.snapshot.details!.description,
    );
    expect(stored.preferredOrder, RelatedPostsOrder.oldest);
    final groupA = (await groups.getGroup(poolGroupA))!;
    final groupB = (await groups.getGroup(poolGroupB))!;
    expect(groupA.name, 'A');
    expect(groupA.bookmarkIds, {
      0,
      localPool.id,
      localRelated.id,
      localOpaque.id,
    });
    expect(groupA.addedAt[localRelated.id], relatedA);
    expect(relatedA, isNot(aDate));
    expect(groupA.addedAt[localPool.id], poolA);
    expect(groupA.addedAt[localOpaque.id], opaqueA);
    expect(groupB.addedAt[localRelated.id], relatedB);
    expect(groupB.addedAt[localPool.id], poolB);
  });

  test('updating a Group removes its last orphan and retains records shared elsewhere', () async {
    final newPost = testPoolPost(99).copyWith(id: 99);
    final date = DateTime.utc(2026, 5, 6, 7, 8, 9);
    final importPlan = await plan(
      BookmarkBackupData.unified(
        records: [newPost],
        groups: [
          BookmarkGroupBackup(
            id: poolGroupA,
            name: 'Updated A',
            bookmarkIds: [newPost.id],
            addedAt: {newPost.id: date},
          ),
        ],
      ),
    );
    final resolved = importPlan.resolveActions({
      poolGroupA: importPlan.groups.single.resolveAction(ImportAction.update),
    });

    await service().apply(resolved);

    final savedPost = (await bookmarks.readAll())
        .whereType<PostBookmark>()
        .singleWhere(
          (record) => record.postId == 99,
        );
    expect(savedPost.id, greaterThan(localPool.id));
    expect(await bookmarks.read(localOpaque.id), isNull);
    expect(await bookmarks.read(localPool.id), localPool);
    expect(await bookmarks.read(localRelated.id), localRelated);
    expect(await bookmarks.read(localPost.id), localPost);
    final groupA = (await groups.getGroup(poolGroupA))!;
    final groupB = (await groups.getGroup(poolGroupB))!;
    expect(groupA.bookmarkIds, {savedPost.id});
    expect(groupA.addedAt[savedPost.id], date);
    expect(groupB.bookmarkIds, {0, localPool.id, localRelated.id});
    expect(groupB.addedAt[0], postB);
    expect(groupB.addedAt[localPool.id], poolB);
    expect(groupB.addedAt[localRelated.id], relatedB);
  });

  test(
    'copy and mergeIntoTarget preserve imported and unrelated membership dates',
    () async {
      final matchedPost = testPoolPost(7).copyWith(id: 50);
      final importedOpaque = opaqueRecord(51);
      final copyDate = DateTime.utc(2026, 6, 1);
      final mergeDate = DateTime.utc(2026, 6, 2);
      final importPlan = await plan(
        BookmarkBackupData.unified(
          records: [matchedPost, importedOpaque],
          folders: const [
            CollectionFolder(id: _folderRootId, name: 'Root'),
            CollectionFolder(
              id: _folderChildId,
              name: 'Nested',
              parentId: _folderRootId,
            ),
          ],
          groups: [
            BookmarkGroupBackup(
              id: _copyGroupId,
              name: 'Copied opaque',
              folderId: _folderChildId,
              bookmarkIds: [importedOpaque.id],
              addedAt: {importedOpaque.id: copyDate},
            ),
            BookmarkGroupBackup(
              id: _mergeSourceGroupId,
              name: 'Merge into B',
              bookmarkIds: [matchedPost.id],
              addedAt: {matchedPost.id: mergeDate},
            ),
          ],
        ),
      );
      final resolved = importPlan.resolveActions({
        _copyGroupId: importPlan.groups
            .singleWhere((group) => group.id == _copyGroupId)
            .resolveAction(ImportAction.copy),
        _mergeSourceGroupId: importPlan.groups
            .singleWhere((group) => group.id == _mergeSourceGroupId)
            .resolveAction(
              ImportAction.mergeIntoTarget,
              targetId: poolGroupB,
            ),
      });

      await service().apply(resolved);

      final copied = (await groups.getGroup(_copyGroupId))!;
      expect(copied.bookmarkIds, hasLength(1));
      expect(copied.folderId, isNull);
      expect(copied.parentGroupId, _folderChildId);
      expect(copied.addedAt.values.single, copyDate);
      final folders = await groups.getFolders();
      expect(folders, isEmpty);
      final copiedAncestors = BookmarkGroupTree(await groups.getGroups())
          .ancestors(copied.id);
      expect(copiedAncestors.map((group) => group.name).last, 'Nested');
      final groupB = (await groups.getGroup(poolGroupB))!;
      expect(groupB.name, 'B');
      expect(groupB.bookmarkIds, {0, localPool.id, localRelated.id});
      expect(groupB.addedAt[0], postB);
      expect(postB, isNot(mergeDate));
      expect(groupB.addedAt[localPool.id], poolB);
      expect(groupB.addedAt[localRelated.id], relatedB);
    },
  );

  for (final replace in [false, true]) {
    test('Default placement survives import (replace=$replace)', () async {
      final current = (await groups.getGroup(defaultBookmarkGroupId))!;
      await bookmarks.commitOrganization(
        groups: [current.copyWith(position: 13)],
      );
      final imported = testPoolPost(7).copyWith(id: 50);
      final date = DateTime.utc(2026, 8, 9);
      final data = BookmarkBackupData.unified(
        records: [imported],
        groups: [
          BookmarkGroupBackup(
            id: defaultBookmarkGroupId,
            name: 'Default',
            position: 23,
            bookmarkIds: [50],
            addedAt: {50: date},
          ),
        ],
      );
      if (replace) {
        await service().replace(data);
      } else {
        await service().apply(await plan(data));
      }
      final saved = (await groups.getGroup(defaultBookmarkGroupId))!;
      expect(saved.position, replace ? 23 : 13);
      expect(saved.folderId, isNull);
      expect(saved.bookmarkIds, {localPost.id});
      expect(saved.addedAt[localPost.id], date);
    });
  }

  test(
    'known content engine conflict fails before import allocation or mutation',
    () async {
      final conflictReference = const ContentReferenceCodec().parse(
        engine: BooruType.szurubooru,
        site: localPool.reference.site,
        kind: ContentKind.group,
        sourceKey: 'pool:42',
      );
      final conflicting = ContentGroupBookmark(
        id: 80,
        snapshot: StoredGroupSnapshot(
          summary: ContentGroupSummary(reference: conflictReference),
        ),
        createdAt: DateTime.utc(2026),
        observedAt: DateTime.utc(2026),
      );
      final importPlan = await plan(
        BookmarkBackupData.unified(
          records: [conflicting],
          groups: [
            BookmarkGroupBackup(
              id: _newGroupId,
              name: 'Invalid source',
              bookmarkIds: [conflicting.id],
            ),
          ],
        ),
      );
      final revisionBefore = await bookmarks.readRevision();
      final counterBefore = contentMap(
        storage.metadataBox.get('idReservation'),
      )['nextId'];

      await expectLater(service().apply(importPlan), throwsFormatException);

      expect(await bookmarks.readRevision(), revisionBefore);
      expect(
        contentMap(storage.metadataBox.get('idReservation'))['nextId'],
        counterBefore,
      );
      expect(await bookmarks.read(localPool.id), localPool);
      expect(await groups.getGroup(poolGroupA), isNotNull);
    },
  );

  test('Replace restores only imported records and group membership', () async {
    final incomingPost = testPoolPost(7).copyWith(id: 100);
    final incomingPool = poolRecord(101);
    final importedDate = DateTime.utc(2026, 7, 8);
    final data = BookmarkBackupData.unified(
      records: [incomingPost, incomingPool],
      groups: [
        BookmarkGroupBackup(
          id: poolGroupA,
          name: 'Restored A',
          bookmarkIds: [incomingPost.id, incomingPool.id],
          addedAt: {
            incomingPost.id: importedDate,
            incomingPool.id: importedDate.add(const Duration(days: 1)),
          },
        ),
      ],
    );

    await service().replace(data);
    await restart();

    final records = await bookmarks.readAll();
    expect(records.whereType<PostBookmark>(), [localPost]);
    expect(
      records.whereType<ContentGroupBookmark>().whereType<RelatedBookmark>(),
      isEmpty,
    );
    final restoredPool = records.whereType<ContentGroupBookmark>().single;
    expect(restoredPool.id, localPool.id);
    expect(restoredPool.snapshot.details, localPool.snapshot.details);
    expect(records.whereType<LegacyGroupBookmark>(), isEmpty);
    final restored = await groups.getGroup(poolGroupA);
    expect(restored!.bookmarkIds, {localPost.id, localPool.id});
    expect(restored.addedAt[localPost.id], importedDate);
    expect(
      restored.addedAt[localPool.id],
      importedDate.add(const Duration(days: 1)),
    );
    expect(await groups.getGroup(poolGroupB), isNull);
    expect(await groups.getGroup(defaultBookmarkGroupId), isNotNull);
  });

  test(
    'v10 file IDs above local range and zero resolve to reserved content IDs',
    () async {
      const highFileId = 9007199254740991;
      expect(highFileId, greaterThan(maxBookmarkId));
      final importedPool = poolRecord(highFileId, sourceKey: 'pool:99');
      final importedRelated = relatedRecord(
        0,
        title: 'Incoming Related',
      ).copyWith(preferredOrder: () => RelatedPostsOrder.newest);
      final poolDate = DateTime.utc(2026, 8, 9, 10, 11, 12, 345, 678);
      final relatedDate = DateTime.utc(2026, 9, 10, 11, 12, 13, 456, 789);
      final source = BookmarkBackupData.unified(
        records: [importedPool, importedRelated],
        groups: [
          BookmarkGroupBackup(
            id: _newGroupId,
            name: 'High file IDs',
            bookmarkIds: [highFileId, 0],
            addedAt: {highFileId: poolDate, 0: relatedDate},
          ),
        ],
      );
      final codec = BookmarkBackupCodec();
      final payload = <String, dynamic>{
        'version': 10,
        'data': codec.encode(source),
        ...source.extraFields,
      };
      final decoded = codec.parse(decodeData(data: jsonEncode(payload)));
      final importPlan = await plan(decoded);
      final counterBefore =
          contentMap(
                storage.metadataBox.get('idReservation'),
              )['nextId']!
              as int;

      await service().apply(importPlan);

      final importedGroup = (await groups.getGroup(_newGroupId))!;
      final newPoolId = importedGroup.bookmarkIds.singleWhere(
        (id) => id != localRelated.id,
      );
      expect(newPoolId, greaterThan(localPool.id));
      expect(newPoolId, lessThanOrEqualTo(maxBookmarkId));
      expect(importedGroup.bookmarkIds, {newPoolId, localRelated.id});
      expect(importedGroup.addedAt[newPoolId], poolDate);
      expect(importedGroup.addedAt[localRelated.id], relatedDate);
      expect(await bookmarks.read(newPoolId), isA<ContentGroupBookmark>());
      expect(await bookmarks.read(localRelated.id), localRelated);
      expect(await bookmarks.read(localPool.id), localPool);
      expect(await bookmarks.read(localPost.id), localPost);
      final relatedAfter =
          (await bookmarks.read(localRelated.id))! as RelatedBookmark;
      expect(relatedAfter.preferredOrder, RelatedPostsOrder.oldest);
      expect(relatedAfter.snapshot.details, localRelated.snapshot.details);
      expect(
        (await groups.getGroup(poolGroupA))!.addedAt[localRelated.id],
        relatedA,
      );
      expect(
        (await groups.getGroup(poolGroupB))!.addedAt[localRelated.id],
        relatedB,
      );
      expect(
        contentMap(storage.metadataBox.get('idReservation'))['nextId'],
        counterBefore + 1,
      );
    },
  );
  for (final replace in [false, true]) {
    for (final decodeBeforeHint in [false, true]) {
      test(
        'v1 opaque Post hint remapping stays independent (replace=$replace decodeBeforeHint=$decodeBeforeHint)',
        () async {
          final legacySource = await Hive.openBox<BookmarkHiveObject>(
            'incoming_v1',
          );
          final legacySnapshot = StoredPostSnapshot(
            origin: localPost.snapshot.origin,
            common: {...localPost.snapshot.common, 'schemaVersion': 1},
            custom: const {
              'retained': {
                'unknown': [1, null, 'kept'],
              },
            },
            codecVersion: 2,
          );
          final raw = favoriteToHiveObject(localPost)
            ..postSnapshot = legacySnapshot.toJson()
            ..snapshotSchemaVersion = 1
            ..createdAt = DateTime.utc(2018, 8, 9)
            ..updatedAt = DateTime.utc(2020, 2, 3);
          await legacySource.put(7001, raw);
          final migrated =
              tryMapBookmarkHiveObjectToBookmark(
                raw,
                (_) => const DefaultImageUrlResolver(),
              ).fold(
                (error) => throw StateError('Fixture failed migration: $error'),
                (record) => record,
              );
          expect(migrated.postId, isNull);
          expect(migrated.post.origin.sourceHost, isEmpty);
          expect(
            migrated.snapshot.origin.sourceHost,
            localPost.snapshot.origin.sourceHost,
          );
          expect(migrated.post.id, localPost.post.id);
          final date = DateTime.utc(2026, 8, 9, 10, 11, 12, 345, 678);
          BookmarkBackupData dataFor(PostBookmark record) =>
              BookmarkBackupData.unified(
                records: [record],
                groups: [
                  BookmarkGroupBackup(
                    id: _newGroupId,
                    name: 'Independent opaque',
                    bookmarkIds: [record.id],
                    addedAt: {record.id: date},
                  ),
                ],
              );
          final codec = BookmarkBackupCodec();
          BookmarkBackupData transfer(BookmarkBackupData data) => codec.parse(
            decodeData(
              data: encodeData(
                version: 10,
                exportDate: DateTime.utc(2026),
                exportVersion: null,
                payload: codec.encode(data),
                extraFields: data.extraFields,
              ),
            ),
          );
          final incoming = decodeBeforeHint
              ? transfer(dataFor(migrated)).records.single as PostBookmark
              : migrated;
          final mapped = bookmarkRecordWithProfileHint(
            incoming,
            '00000000-0000-4000-8000-000000000021',
          ) as PostBookmark;
          final data = dataFor(mapped);
          final importPlan = await plan(data);
          final currentRecords = await bookmarks.readAll();
          final currentGroups = await groups.getGroups();
          final currentFolders = await groups.getFolders();
          final preview = BookmarkImportPreparation.prepare(
            plan: importPlan,
            currentRecords: currentRecords,
            currentGroups: currentGroups,
            currentFolders: currentFolders,
            normalize: (record, {previous}) => record,
            replace: replace,
          );
          final projected = const ImportPlannedChangeProjector().bookmarks(
            local: BookmarkImportLocalSnapshot(
              records: currentRecords,
              groups: currentGroups,
              folders: currentFolders,
            ),
            incoming: dataFor(incoming),
            resolution: ResolvedImportSource(
              id: 'bookmarks',
              action: replace
                  ? ImportAction.replace
                  : ImportAction.configureItems,
              items: [
                ResolvedImportItem(
                  id: 'group:$_newGroupId',
                  action: ImportAction.copy,
                ),
              ],
            ),
            profileMappings: {
              ProfileReferenceKey.fromReference(
                bookmarkRecordProfileReference(incoming),
              ): '00000000-0000-4000-8000-000000000021',
            },
          )!;
          final counterBefore =
              contentMap(storage.metadataBox.get('idReservation'))['nextId']!
                  as int;
          final actual = BookmarkImportPreparation.prepare(
            plan: importPlan,
            currentRecords: currentRecords,
            currentGroups: currentGroups,
            currentFolders: currentFolders,
            normalize: bookmarks.normalizeRecord,
            replace: replace,
          );
          if (replace) {
            await service().replace(data);
          } else {
            await service().apply(importPlan);
          }
          expect(actual.alreadyExistedCount, 0);
          expect(projected.entitySummaries['bookmark']!.created, 1);
          expect(
            projected.entitySummaries['bookmark']!.deleted,
            replace ? currentRecords.length : 0,
          );
          expect(
            contentMap(storage.metadataBox.get('idReservation'))['nextId'],
            counterBefore + 1,
          );
          expect(preview.alreadyExistedCount, actual.alreadyExistedCount);
          expect(preview.newIds, hasLength(1));
          final savedGroup = (await groups.getGroups()).singleWhere(
            (g) => g.name == 'Independent opaque',
          );
          final freshId = savedGroup.bookmarkIds.single;
          expect(freshId, isNot(localPost.id));
          expect(freshId, isNot(migrated.id));
          final saved = (await bookmarks.read(freshId))! as PostBookmark;
          expect(saved.postId, isNull);
          expect(bookmarkContentIdentity(saved), isNull);
          expect(saved.snapshot.common, migrated.snapshot.common);
          expect(saved.snapshot.custom, migrated.snapshot.custom);
          expect(saved.snapshot.codecVersion, migrated.snapshot.codecVersion);
          expect(
            saved.snapshot.origin.sourceHost,
            migrated.snapshot.origin.sourceHost,
          );
          expect(
            saved.snapshot.origin.profileIdHint,
            '00000000-0000-4000-8000-000000000021',
          );
          expect(saved.createdAt, migrated.createdAt);
          expect(saved.updatedAt, migrated.updatedAt);
          expect(savedGroup.addedAt[freshId], date);
          expect(
            await bookmarks.read(localPost.id),
            replace ? null : localPost,
          );
          await restart();
          final reopened = (await bookmarks.read(freshId))! as PostBookmark;
          expect(reopened, saved);
          expect(reopened.postId, isNull);
          expect(bookmarkContentIdentity(reopened), isNull);
          final reopenedGroup = (await groups.getGroups()).singleWhere(
            (g) => g.name == 'Independent opaque',
          );
          expect(reopenedGroup.bookmarkIds, {freshId});
          expect(reopenedGroup.addedAt[freshId], date);
          expect(
            await bookmarks.read(localPost.id),
            replace ? null : localPost,
          );
        },
      );
    }
  }
}
