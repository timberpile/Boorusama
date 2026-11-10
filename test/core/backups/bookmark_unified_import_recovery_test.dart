import 'dart:io';

import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_plan.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_planner.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_service.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/content_map.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;

import '../../support/fakes/bookmark_test_storage.dart';
import '../bookmarks/pool_bookmark_test_utils.dart';

void main() {
  late Directory directory;
  late Box<BookmarkHiveObject> posts;
  late Box<dynamic> payloads;
  late Box<dynamic> metadata;
  late Box<BookmarkGroupHiveObject> legacyGroups;
  late Box<dynamic> legacyOrganization;
  late BookmarkHiveRepository bookmarks;
  late BookmarkTestStorage storage;
  late UnifiedBookmarkGroupRepository groups;
  late Box<BookmarkGroupHiveObject> activeGroups;
  late int orphanId;
  late DateTime dateA;
  late DateTime dateB;
  String? failAfter;
  int? firstImportedId;
  var sawJournal = false;

  Future<void> sync(Iterable<BoxBase<dynamic>> boxes) async {
    final list = boxes.toList();
    const fs = IoFileSystem();
    for (final box in list) {
      await box.flush();
      await fs.syncFile(box.path!);
      await fs.syncDirectory(p.dirname(box.path!));
    }
    if (failAfter == null) return;
    final journalPending = metadata.containsKey('pendingMutation');
    if (journalPending) sawJournal = true;
    // Reservation and initialization syncs happen before the mutation journal;
    // they are never mistaken for the requested cleanup boundary.
    if (!sawJournal) return;
    final phase = switch (true) {
      _
          when list.any((box) => identical(box, posts)) ||
              list.any((box) => identical(box, payloads)) ||
              list.any((box) => identical(box, activeGroups)) =>
        'payload',
      _
          when journalPending &&
              metadata.get('record:$firstImportedId') == null =>
        'journal',
      _ when journalPending => 'index',
      _ => 'cleanup',
    };
    if (failAfter == phase) {
      failAfter = null;
      throw StateError('Fixture committed $phase failure');
    }
  }

  Future<void> openBoxes() async {
    posts = await Hive.openBox<BookmarkHiveObject>('posts');
    legacyGroups = await Hive.openBox<BookmarkGroupHiveObject>('groups');
    legacyOrganization = await Hive.openBox<dynamic>('organization');
    storage = await BookmarkTestStorage.open(posts);
    payloads = storage.groupPayloadBox;
    metadata = storage.metadataBox;
    bookmarks = BookmarkHiveRepository(
      posts,
      groupPayloadBox: payloads,
      metadataBox: metadata,
      coordinator: DataMutationCoordinator(),
      syncBoxes: sync,
    );
  }

  Future<void> attachActiveRepository() async {
    final reader = await BookmarkStorageMigration(
      bookmarks: bookmarks,
      legacyGroups: legacyGroups,
      legacyOrganization: legacyOrganization,
      metadata: metadata,
    ).open();
    final active = contentMap(metadata.get(BookmarkStorageMigration.activeKey));
    final generation = contentMap(active['generation']);
    activeGroups = await Hive.openBox<BookmarkGroupHiveObject>(
      generation['groups']! as String,
    );
    await Hive.openBox<dynamic>(generation['organization']! as String);
    groups = UnifiedBookmarkGroupRepository(
      bookmarks: bookmarks,
      reader: reader,
    );
  }

  Future<void> initialize() async {
    directory = await Directory.systemTemp.createTemp(
      'bookmark-import-recovery-',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    failAfter = null;
    firstImportedId = null;
    sawJournal = false;
    await openBoxes();
    final post = testPoolPost(7).copyWith(id: 0);
    await posts.put(0, favoriteToHiveObject(post));
    dateA = DateTime.utc(2024, 1, 2, 3, 4, 5, 123, 456);
    dateB = DateTime.utc(2025, 6, 7, 8, 9, 10, 789, 123);
    await legacyGroups.put(
      poolGroupA,
      BookmarkGroupHiveObject(
        id: poolGroupA,
        name: 'A',
        bookmarkIds: [0],
        addedAt: {0: dateA.toIso8601String()},
      ),
    );
    await legacyGroups.put(
      poolGroupB,
      BookmarkGroupHiveObject(
        id: poolGroupB,
        name: 'B',
        bookmarkIds: [0],
        addedAt: {0: dateB.toIso8601String()},
      ),
    );
    await legacyOrganization.put('version', 1);
    await legacyOrganization.put('poolBookmarks', []);
    final reader = await BookmarkStorageMigration(
      bookmarks: bookmarks,
      legacyGroups: legacyGroups,
      legacyOrganization: legacyOrganization,
      metadata: metadata,
    ).open();
    orphanId = (await bookmarks.reserveIds(1)).single;
    final orphan = LegacyGroupBookmark.fromMetadata(
      id: orphanId,
      metadata: PoolBookmark(
        localId: 'orphan-import-test',
        origin: poolOrigin(host: 'legacy.example', type: BooruType.unknown),
        sourceTypeId: 777,
        poolId: 777,
        category: BookmarkedPoolCategory.series,
        title: 'Orphan group',
        createdAt: DateTime.utc(2019, 1, 2),
        observedAt: DateTime.utc(2024, 1, 2),
        groupIds: const {},
        tags: const {'orphan'},
        coverage: PoolTagCoverage.partial,
        total: 4,
      ),
    );
    final groupA = (await reader.getGroup(poolGroupA))!;
    await bookmarks.commitOrganization(
      records: [orphan],
      groups: [
        groupA.copyWith(
          bookmarkIds: {...groupA.bookmarkIds, orphanId},
          addedAt: {...groupA.addedAt, orphanId: DateTime.utc(2024, 7, 8)},
        ),
      ],
    );
    await attachActiveRepository();
  }

  Future<void> restart() async {
    await Hive.close();
    Hive.init(directory.path);
    await openBoxes();
    await attachActiveRepository();
  }

  BookmarkImportService importService() => BookmarkImportService(
    bookmarkRepository: bookmarks,
    groupRepository: groups,
    imageUrlResolver: (_) => const DefaultImageUrlResolver(),
  );

  Future<BookmarkImportPlan> planFor(
    BookmarkBackupData data,
  ) async => const BookmarkImportPlanner().plan(
    data: data,
    currentBookmarks: await bookmarks.readAll(),
    currentGroups: await groups.getGroups(),
  );

  setUp(initialize);
  tearDown(() async {
    await Hive.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('journaled import resumes a complete common generation at every sync boundary', () async {
    const boundaries = ['journal', 'payload', 'index', 'cleanup'];
    for (final (index, boundary) in boundaries.indexed) {
      final newPost = testPoolPost(99).copyWith(id: 100);
      final reference = const ContentReferenceCodec().parse(
        engine: BooruType.danbooru,
        site: Uri.parse('https://danbooru.donmai.us/install'),
        kind: ContentKind.group,
        sourceKey: 'pool:43',
      );
      final newPool = ContentGroupBookmark(
        id: 101,
        snapshot: StoredGroupSnapshot(
          summary: ContentGroupSummary(reference: reference, title: 'Pool 43'),
        ),
        createdAt: DateTime.utc(2020, 2, 3),
        observedAt: DateTime.utc(2025, 4, 5),
      );
      final postDate = DateTime.utc(2026, 1, 2, 3, 4, 5, 111, 222);
      final poolDate = DateTime.utc(2026, 2, 3, 4, 5, 6, 333, 444);
      final data = BookmarkBackupData.unified(
        records: [newPost, newPool],
        groups: [
          BookmarkGroupBackup(
            id: poolGroupA,
            name: 'A import',
            bookmarkIds: [newPost.id, newPool.id],
            addedAt: {newPost.id: postDate, newPool.id: poolDate},
          ),
        ],
      );
      final initialPlan = await planFor(data);
      final plan = initialPlan.resolveActions({
        poolGroupA: initialPlan.groups.single.resolveAction(
          ImportAction.update,
        ),
      });
      final revisionBefore = await bookmarks.readRevision();
      final boundBefore =
          contentMap(metadata.get('idReservation'))['nextId']! as int;
      firstImportedId = boundBefore;
      sawJournal = false;
      failAfter = boundary;

      await expectLater(
        importService().apply(plan),
        throwsA(isA<StateError>()),
        reason: boundary,
      );
      expect(sawJournal, isTrue, reason: boundary);

      await restart();
      final records = await bookmarks.readAll();
      final savedPost = records.whereType<PostBookmark>().singleWhere(
        (record) => record.postId == 99,
      );
      final savedPool = records.whereType<ContentGroupBookmark>().single;
      expect(savedPost.id, boundBefore, reason: boundary);
      expect(savedPool.id, boundBefore + 1, reason: boundary);
      expect(await bookmarks.read(orphanId), isNull, reason: boundary);
      expect(metadata.get('record:$orphanId'), {
        'kind': 'deleted',
      }, reason: boundary);
      expect(
        metadata.containsKey('pendingMutation'),
        isFalse,
        reason: boundary,
      );
      expect(await bookmarks.read(0), isNotNull, reason: boundary);
      final groupA = (await groups.getGroup(poolGroupA))!;
      final groupB = (await groups.getGroup(poolGroupB))!;
      expect(groupA.bookmarkIds, {
        savedPost.id,
        savedPool.id,
      }, reason: boundary);
      expect(groupA.addedAt[savedPost.id], postDate, reason: boundary);
      expect(groupA.addedAt[savedPool.id], poolDate, reason: boundary);
      expect(groupB.bookmarkIds, {0}, reason: boundary);
      expect(groupB.addedAt[0], dateB, reason: boundary);
      expect(
        await bookmarks.readRevision(),
        revisionBefore + 1,
        reason: boundary,
      );
      expect(
        contentMap(metadata.get('idReservation'))['nextId'],
        boundBefore + 2,
        reason: boundary,
      );
      expect(legacyGroups.get(poolGroupA)!.bookmarkIds, [0], reason: boundary);
      expect(legacyGroups.get(poolGroupB)!.bookmarkIds, [0], reason: boundary);
      expect(
        legacyOrganization.get('poolBookmarks'),
        isEmpty,
        reason: boundary,
      );

      final retryPlanBase = await planFor(data);
      final retryPlan = retryPlanBase.resolveActions({
        poolGroupA: retryPlanBase.groups.single.resolveAction(
          ImportAction.update,
        ),
      });
      final retryDates = groupA.addedAt;
      await importService().apply(retryPlan);
      expect(
        contentMap(metadata.get('idReservation'))['nextId'],
        boundBefore + 2,
        reason: boundary,
      );
      expect(
        (await groups.getGroup(poolGroupA))!.addedAt,
        retryDates,
        reason: boundary,
      );
      expect(
        (await bookmarks.readAll())
            .whereType<PostBookmark>()
            .singleWhere(
              (record) => record.postId == 99,
            )
            .id,
        boundBefore,
        reason: boundary,
      );

      if (index < boundaries.length - 1) {
        await Hive.close();
        await directory.delete(recursive: true);
        await initialize();
      }
    }
  });
}
