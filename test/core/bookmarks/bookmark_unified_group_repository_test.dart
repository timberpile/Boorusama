import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/content_map.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;

import 'pool_bookmark_test_utils.dart';

void main() {
  late Directory directory;
  late Box<BookmarkHiveObject> posts;
  late Box<dynamic> payloads;
  late Box<dynamic> metadata;
  late Box<BookmarkGroupHiveObject> legacyGroups;
  late Box<dynamic> legacyOrganization;
  late Box<BookmarkGroupHiveObject> activeGroups;
  late Box<dynamic> activeOrganization;
  late BookmarkHiveRepository bookmarks;
  late UnifiedBookmarkGroupRepository groups;
  DateTime now = DateTime.utc(2026, 6, 1);

  Future<void> sync(Iterable<BoxBase<dynamic>> boxes) async {
    const fs = IoFileSystem();
    for (final box in boxes) {
      await box.flush();
      await fs.syncFile(box.path!);
      await fs.syncDirectory(p.dirname(box.path!));
    }
  }

  Future<void> openBoxes() async {
    posts = await Hive.openBox<BookmarkHiveObject>('posts');
    payloads = await Hive.openBox<dynamic>('posts_unified_payloads');
    metadata = await Hive.openBox<dynamic>('posts_unified_metadata');
    legacyGroups = await Hive.openBox<BookmarkGroupHiveObject>('groups');
    legacyOrganization = await Hive.openBox<dynamic>('organization');
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
    groups = UnifiedBookmarkGroupRepository(
      bookmarks: bookmarks,
      reader: reader,
      now: () => now,
    );
    final active = contentMap(metadata.get(BookmarkStorageMigration.activeKey));
    final generation = contentMap(active['generation']);
    activeGroups = await Hive.openBox<BookmarkGroupHiveObject>(
      generation['groups']! as String,
    );
    activeOrganization = await Hive.openBox<dynamic>(
      generation['organization']! as String,
    );
  }

  Future<void> initialize() async {
    directory = await Directory.systemTemp.createTemp(
      'unified-group-repository-',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    now = DateTime.utc(2026, 6, 1);
    await openBoxes();
    await posts.put(0, favoriteToHiveObject(testPoolPost(7).copyWith(id: 0)));
    await legacyOrganization.put('version', 1);
    await legacyOrganization.put('poolBookmarks', []);
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

  Uri provenSite() => Uri.parse('https://danbooru.donmai.us');

  CollectionBookmark nativeDraft({
    int poolId = 42,
    Set<String> groupIds = const {poolGroupA},
    DateTime? membershipDate,
  }) => testPool(id: poolId, groups: groupIds)
      .withGroups(
        groupIds,
        addedAt: {
          for (final id in groupIds) id: membershipDate ?? now,
        },
      )
      .copyWith(sourceSite: provenSite);

  Future<void> ensureGroup() async {
    await groups.createGroup('Saved pools', id: poolGroupA);
  }

  test(
    'native Group records project from memberships and survive restart',
    () async {
      await ensureGroup();
      final membershipDate = DateTime.utc(2025, 9, 10, 11, 12, 13, 456, 789);
      await groups.writePoolBookmarks([
        nativeDraft(membershipDate: membershipDate),
      ]);
      var view = (await groups.readPoolBookmarks()).single;
      final id = view.bookmarkId!;
      expect(await bookmarks.read(id), isA<ContentGroupBookmark>());
      expect(view.sourceSite, provenSite());
      expect(view.groupIds, {poolGroupA});
      expect(view.addedAt, {poolGroupA: membershipDate});
      expect(view.toJson().containsKey('bookmarkId'), isFalse);
      expect(view.toJson().containsKey('sourceSite'), isFalse);
      expect(legacyOrganization.get('poolBookmarks'), isEmpty);
      expect(activeOrganization.containsKey('poolBookmarks'), isFalse);

      final duplicate = await groups.duplicateGroup(poolGroupA, name: 'Copy');
      view = (await groups.readPoolBookmarks()).single;
      expect(view.groupIds, {poolGroupA, duplicate.id});
      expect(view.addedAt, {
        poolGroupA: membershipDate,
        duplicate.id: membershipDate,
      });

      await groups.createGroup('Another group', id: poolGroupB);
      await groups.addBookmarks(poolGroupB, {id});
      view = (await groups.readPoolBookmarks()).single;
      expect(view.groupIds, {poolGroupA, poolGroupB, duplicate.id});
      expect(view.addedAt[poolGroupA], membershipDate);
      expect(view.addedAt[duplicate.id], membershipDate);
      expect(view.addedAt[poolGroupB], now);

      await restart();
      view = (await groups.readPoolBookmarks()).single;
      expect(view.bookmarkId, id);
      expect(view.groupIds, {poolGroupA, poolGroupB, duplicate.id});
      expect(view.addedAt[poolGroupA], membershipDate);
      expect(view.addedAt[duplicate.id], membershipDate);
      expect(legacyOrganization.get('poolBookmarks'), isEmpty);
      expect(activeOrganization.containsKey('poolBookmarks'), isFalse);
    },
  );

  test('legacy Group DTO without a proven site remains legacy and uses common memberships', () async {
    await ensureGroup();
    final legacy = testPool(id: 43, groups: {poolGroupA}).withGroups(
      {poolGroupA},
      addedAt: {poolGroupA: DateTime.utc(2024, 1, 2)},
    );
    await groups.writePoolBookmarks([legacy]);
    var view = (await groups.readPoolBookmarks()).single;
    final id = view.bookmarkId!;
    expect(await bookmarks.read(id), isA<LegacyGroupBookmark>());
    expect(view.sourceSite, isNull);
    expect(view.groupIds, {poolGroupA});
    expect(view.addedAt[poolGroupA], DateTime.utc(2024, 1, 2));

    await groups.createGroup('Second', id: poolGroupB);
    await groups.replaceMemberships(
      poolGroupB,
      {id},
      addedAt: {id: DateTime.utc(2025, 2, 3)},
    );
    view = (await groups.readPoolBookmarks()).single;
    expect(view.groupIds, {poolGroupA, poolGroupB});
    expect(view.addedAt, {
      poolGroupA: DateTime.utc(2024, 1, 2),
      poolGroupB: DateTime.utc(2025, 2, 3),
    });
    expect(await bookmarks.read(id), isA<LegacyGroupBookmark>());
    expect(activeOrganization.containsKey('poolBookmarks'), isFalse);
  });

  test('incompatible source engine with a duplicate identity fails before reservation', () async {
    await ensureGroup();
    final valid = nativeDraft(poolId: 44);
    final incompatible = valid.copyWith(
      localId: '550e8400-e29b-41d4-a716-000000000044',
      origin: poolOrigin(type: BooruType.szurubooru),
    );
    final beforeReservation = metadata.get('idReservation');
    await expectLater(
      groups.writePoolBookmarks([valid, incompatible]),
      throwsFormatException,
    );
    expect(metadata.get('idReservation'), beforeReservation);
    expect(payloads, isEmpty);
    expect(await groups.readPoolBookmarks(), isEmpty);
    expect(activeGroups.get(poolGroupA)!.bookmarkIds, isEmpty);
  });

  test(
    'stale stored DTO is rejected after atomic record and membership deletion',
    () async {
      await ensureGroup();
      await groups.writePoolBookmarks([nativeDraft(poolId: 45)]);
      final stale = (await groups.readPoolBookmarks()).single;
      final id = stale.bookmarkId!;
      final group = (await groups.getGroup(poolGroupA))!;
      await bookmarks.commitOrganization(
        removeIds: {id},
        groups: [
          group.copyWith(
            bookmarkIds: group.bookmarkIds.difference({id}),
            addedAt: {
              for (final entry in group.addedAt.entries)
                if (entry.key != id) entry.key: entry.value,
            },
          ),
        ],
      );

      await expectLater(groups.writePoolBookmarks([stale]), throwsStateError);
      expect(await bookmarks.read(id), isNull);
      expect(await groups.readPoolBookmarks(), isEmpty);
      expect(payloads.containsKey(id), isFalse);
      expect(activeGroups.get(poolGroupA)!.bookmarkIds, isEmpty);
      expect(activeOrganization.containsKey('poolBookmarks'), isFalse);
    },
  );
  test(
    'unresolved records retain independent local IDs and membership dates',
    () async {
      await groups.createGroup('A', id: poolGroupA);
      final wire = testPool(groups: {poolGroupA}).toJson();
      wire['origin'] = {...contentMap(wire['origin']), 'booruTypeId': 777};
      final firstDate = DateTime.utc(2020);
      final secondDate = DateTime.utc(2021);
      final first = CollectionBookmark.fromJson(wire)
          .withGroups({poolGroupA}, addedAt: {poolGroupA: firstDate});
      final second = CollectionBookmark.fromJson({
        ...wire,
        'localId': '550e8400-e29b-41d4-a716-446655449999',
      }).withGroups({poolGroupA}, addedAt: {poolGroupA: secondDate});
      await groups.writePoolBookmarks([first, second]);
      final saved = await groups.readPoolBookmarks();
      expect(saved, hasLength(2));
      expect(saved.map((view) => view.bookmarkId).toSet(), hasLength(2));
      expect(
        (await bookmarks.readAll()).whereType<LegacyGroupBookmark>(),
        hasLength(2),
      );
      expect(saved.map((view) => view.addedAt[poolGroupA]), [
        firstDate,
        secondDate,
      ]);
      final duplicate = await groups.duplicateGroup(poolGroupA);
      expect(duplicate.addedAt, (await groups.getGroup(poolGroupA))!.addedAt);
      final repeated = await groups.readPoolBookmarks();
      final revision = metadata.get('recordRevision');
      final bound = metadata.get('idReservation');
      await groups.writePoolBookmarks(repeated);
      expect(metadata.get('recordRevision'), revision);
      expect(metadata.get('idReservation'), bound);
      expect(
        (await groups.readPoolBookmarks()).map((view) => view.bookmarkId),
        repeated.map((view) => view.bookmarkId),
      );
    },
  );
}
