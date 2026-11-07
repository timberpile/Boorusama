import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/content/content_map.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../support/fakes/bookmark_test_storage.dart';
import 'pool_bookmark_test_utils.dart';

void main() {
  late Directory directory;
  late Box<BookmarkHiveObject> posts;
  late Box<BookmarkGroupHiveObject> groups;
  late Box<dynamic> organization;
  late BookmarkTestStorage storage;
  late PostBookmark originalPost;
  late CollectionBookmark originalPool;
  late DateTime firstDate;
  late DateTime secondDate;
  String? failAfter;

  Future<void> openBoxes() async {
    posts = await Hive.openBox<BookmarkHiveObject>('posts');
    groups = await Hive.openBox<BookmarkGroupHiveObject>('groups');
    organization = await Hive.openBox<dynamic>('organization');
    storage = await BookmarkTestStorage.open(posts);
  }

  BookmarkStorageMigration migration() => BookmarkStorageMigration(
    bookmarks: storage.repository(posts),
    legacyGroups: groups,
    legacyOrganization: organization,
    metadata: storage.metadataBox,
    afterDurableBoundary: (boundary) async {
      if (failAfter == boundary) {
        failAfter = null;
        throw StateError('Fixture interrupted after $boundary');
      }
    },
  );

  Future<void> restart() async {
    await Hive.close();
    Hive.init(directory.path);
    await openBoxes();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bookmark-upgrade-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    failAfter = null;
    await openBoxes();
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> seed() async {
    originalPost = testPoolPost(7).copyWith(id: 0);
    await posts.put(0, favoriteToHiveObject(originalPost));
    firstDate = DateTime.utc(2024, 3, 4, 5, 6, 7, 123, 456);
    secondDate = DateTime.utc(2025, 6, 7, 8, 9, 10, 789, 123);
    await groups.put(
      poolGroupA,
      BookmarkGroupHiveObject(
        id: poolGroupA,
        name: 'A',
        bookmarkIds: [0],
        addedAt: {0: firstDate.toIso8601String()},
      ),
    );
    await groups.put(
      poolGroupB,
      BookmarkGroupHiveObject(
        id: poolGroupB,
        name: 'B',
        bookmarkIds: [0],
        addedAt: {0: secondDate.toIso8601String()},
      ),
    );
    originalPool = testPool(groups: {poolGroupA, poolGroupB}).withGroups(
      {poolGroupA, poolGroupB},
      addedAt: {poolGroupA: firstDate, poolGroupB: secondDate},
    );
    await organization.put('version', 1);
    await organization.put('poolBookmarks', [originalPool.toJson()]);
    await organization.put('recentManualGroupIds', [poolGroupB]);
  }

  Map<String, Object?> rawGroup(BookmarkGroupHiveObject group) => {
    'id': group.id,
    'name': group.name,
    'bookmarkIds': group.bookmarkIds,
    'addedAt': group.addedAt,
    'folderId': group.folderId,
    'position': group.position,
  };

  test(
    'migration replays every durable boundary into one complete generation',
    () async {
      const boundaries = [
        'reservation',
        'plan',
        'payloads',
        'organization',
        'activation',
        'cleanup',
      ];

      for (final boundary in boundaries) {
        await seed();
        final originalRows = groups.values.map(rawGroup).toList();
        final originalOrganization = organization.toMap();
        final oldPoolRows = organization.get('poolBookmarks');
        failAfter = boundary;
        await expectLater(migration().open(), throwsA(isA<StateError>()));

        int? plannedPoolId;
        if (boundary != 'reservation') {
          final pending = storage.metadataBox.get(
            BookmarkStorageMigration.pendingKey,
          );
          final mapping = pending == null
              ? contentMap(
                  contentMap(
                    storage.metadataBox.get(BookmarkStorageMigration.activeKey),
                  )['mapping'],
                )
              : contentMap(
                  contentMap(contentMap(pending)['plan'])['mapping'],
                );
          plannedPoolId = mapping.values.single! as int;
        }

        await restart();
        final active = await migration().open();
        final records = await storage.repository(posts).readAll();
        final savedPost = records.whereType<PostBookmark>().single;
        final savedPool = records.whereType<LegacyGroupBookmark>().single;
        expect(savedPost.id, 0, reason: boundary);
        expect(savedPost, originalPost, reason: boundary);
        expect(savedPool.id, plannedPoolId ?? savedPool.id, reason: boundary);
        expect(
          savedPool.metadata.origin,
          originalPool.origin,
          reason: boundary,
        );
        expect(
          savedPool.metadata.sourceTypeId,
          originalPool.sourceTypeId,
          reason: boundary,
        );
        expect(
          savedPool.createdAt,
          originalPool.createdAt.toUtc(),
          reason: boundary,
        );
        expect(
          savedPool.observedAt,
          originalPool.observedAt.toUtc(),
          reason: boundary,
        );
        expect(savedPool.metadata.tags, originalPool.tags, reason: boundary);
        expect(savedPool.metadata.groupIds, isEmpty, reason: boundary);
        expect(savedPool.metadata.addedAt, isEmpty, reason: boundary);
        expect(savedPool.index.tags, originalPool.tags, reason: boundary);
        expect(
          savedPool.index.coverage.name,
          originalPool.coverage.name,
          reason: boundary,
        );
        expect(records, hasLength(2), reason: boundary);
        expect((await active.getGroups()).map((group) => group.id).toSet(), {
          poolGroupA,
          poolGroupB,
          defaultBookmarkGroupId,
        }, reason: boundary);
        final groupA = (await active.getGroup(poolGroupA))!;
        final groupB = (await active.getGroup(poolGroupB))!;
        expect(groupA.bookmarkIds, {0, savedPool.id}, reason: boundary);
        expect(groupB.bookmarkIds, {0, savedPool.id}, reason: boundary);
        expect(groupA.addedAt[0], firstDate);
        expect(groupB.addedAt[0], secondDate);
        expect(groupA.addedAt[savedPool.id], originalPool.addedAt[poolGroupA]);
        expect(groupB.addedAt[savedPool.id], originalPool.addedAt[poolGroupB]);
        expect(
          groups.values.map(rawGroup).toList(),
          originalRows,
          reason: boundary,
        );
        expect(
          organization.get('poolBookmarks'),
          oldPoolRows,
          reason: boundary,
        );
        expect(organization.toMap(), originalOrganization, reason: boundary);
        expect(
          storage.metadataBox.containsKey(BookmarkStorageMigration.pendingKey),
          isFalse,
          reason: boundary,
        );
        expect(
          storage.metadataBox.containsKey(BookmarkStorageMigration.activeKey),
          isTrue,
          reason: boundary,
        );

        // Each phase starts from the same legacy source, but does not reuse its
        // source files or migration metadata from the previous iteration.
        if (boundary != boundaries.last) {
          await Hive.close();
          await directory.delete(recursive: true);
          directory = await Directory.systemTemp.createTemp(
            'bookmark-upgrade-',
          );
          Hive.init(directory.path);
          await openBoxes();
        }
      }
    },
  );

  test(
    'invalid legacy membership fails before activation and preserves source',
    () async {
      await seed();
      await groups.put(
        poolGroupA,
        BookmarkGroupHiveObject(
          id: poolGroupA,
          name: 'A',
          bookmarkIds: [99],
          addedAt: {99: DateTime.utc(2024).toIso8601String()},
        ),
      );
      final sourceRows = groups.values.map(rawGroup).toList();
      final sourceOrganization = organization.toMap();

      await expectLater(migration().open(), throwsFormatException);

      expect(
        storage.metadataBox.containsKey(BookmarkStorageMigration.activeKey),
        isFalse,
      );
      expect(
        storage.metadataBox.containsKey(BookmarkStorageMigration.pendingKey),
        isFalse,
      );
      expect(groups.values.map(rawGroup).toList(), sourceRows);
      expect(organization.toMap(), sourceOrganization);
      expect(posts.containsKey(0), isTrue);
    },
  );
  test(
    'unsupported local organization versions fail before reserving Group IDs',
    () async {
      await seed();
      await organization.put('version', 99);
      await storage.repository(posts).reserveIds(0);
      final bound = storage.metadataBox.get('idReservation');
      final source = organization.toMap();
      await expectLater(migration().open(), throwsFormatException);
      expect(storage.metadataBox.get('idReservation'), bound);
      expect(
        storage.metadataBox.containsKey(BookmarkStorageMigration.pendingKey),
        isFalse,
      );
      expect(
        storage.metadataBox.containsKey(BookmarkStorageMigration.activeKey),
        isFalse,
      );
      expect(organization.toMap(), source);
    },
  );

  test('incompatible engines for one Group identity fail before reservation or staging', () async {
    await seed();
    final other = originalPool.toJson();
    other['localId'] = '550e8400-e29b-41d4-a716-446655449999';
    other['origin'] = {
      ...contentMap(other['origin']),
      'booruTypeId': BooruType.szurubooru.id,
    };
    await organization.put('poolBookmarks', [originalPool.toJson(), other]);
    await storage.repository(posts).reserveIds(0);
    final bound = storage.metadataBox.get('idReservation');
    final source = organization.toMap();
    await expectLater(migration().open(), throwsFormatException);
    expect(storage.metadataBox.get('idReservation'), bound);
    expect(
      storage.metadataBox.containsKey(BookmarkStorageMigration.pendingKey),
      isFalse,
    );
    expect(
      storage.metadataBox.containsKey(BookmarkStorageMigration.activeKey),
      isFalse,
    );
    expect(organization.toMap(), source);
    expect(await storage.repository(posts).readAll(), [originalPost]);
  });
  test(
    'a changed source blocks pending migration without rewriting either source',
    () async {
      await seed();
      failAfter = 'plan';
      await expectLater(migration().open(), throwsStateError);
      final changed = originalPool.toJson()
        ..['title'] = 'Changed by another writer';
      await organization.put('poolBookmarks', [changed]);
      final source = organization.toMap();
      final groupRows = groups.values.map(rawGroup).toList();
      await restart();
      await expectLater(migration().open(), throwsFormatException);
      expect(organization.toMap(), source);
      expect(groups.values.map(rawGroup).toList(), groupRows);
      await expectLater(storage.repository(posts).readAll(), throwsStateError);
      final bound = storage.metadataBox.get('idReservation');
      await expectLater(
        storage.repository(posts).reserveIds(1),
        throwsStateError,
      );
      expect(storage.metadataBox.get('idReservation'), bound);
      expect(posts.length, 1);
      expect(posts.get(0)!.postSnapshot, originalPost.snapshot.toJson());
      expect(
        storage.metadataBox.containsKey(BookmarkStorageMigration.activeKey),
        isFalse,
      );
      expect(
        storage.metadataBox.containsKey(BookmarkStorageMigration.pendingKey),
        isTrue,
      );
    },
  );
}
