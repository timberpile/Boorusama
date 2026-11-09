import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/content/content_map.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../support/fakes/bookmark_test_storage.dart';

const parent = '11111111-1111-4111-8111-111111111111';
const child = '22222222-2222-4222-8222-222222222222';
const empty = '33333333-3333-4333-8333-333333333333';

void main() {
  late Directory directory;
  late Box<BookmarkHiveObject> posts;
  late Box<BookmarkGroupHiveObject> groups;
  late Box<dynamic> organization;
  late BookmarkTestStorage storage;
  String? interrupt;

  Future<void> open() async {
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
    afterDurableBoundary: (phase) async {
      if (phase == interrupt) {
        interrupt = null;
        throw StateError('Power loss $phase');
      }
    },
  );

  Future<void> restart() async {
    await Hive.close();
    Hive.init(directory.path);
    await open();
  }

  Future<void> seed({bool activeV2 = false, bool collide = false}) async {
    final groupBox = activeV2
        ? await Hive.openBox<BookmarkGroupHiveObject>('groups_unified_v2')
        : groups;
    final folderBox = activeV2
        ? await Hive.openBox<dynamic>('organization_unified_v2')
        : organization;
    await groupBox.put(
      child,
      BookmarkGroupHiveObject(
        id: child,
        name: 'Same',
        bookmarkIds: const [],
        folderId: parent,
        position: 4,
      ),
    );
    if (collide) {
      await groupBox.put(
        parent,
        BookmarkGroupHiveObject(
          id: parent,
          name: 'Same',
          bookmarkIds: const [],
          position: 2,
        ),
      );
    }
    await folderBox.putAll({
      'version': 1,
      'folders': [
        {'id': parent, 'name': 'Same', 'parentId': null, 'position': 3},
        {'id': empty, 'name': 'Empty', 'parentId': parent, 'position': 0},
      ],
      'recentManualGroupIds': [child],
    });
    if (activeV2) {
      // Keep a real initialized payload authority, including a burned reservation.
      await storage.repository(posts).reserveIds(50);
      await storage.metadataBox.put('activeOrganization', {
        'version': 2,
        'generation': {'groups': groupBox.name, 'organization': folderBox.name},
        'mapping': const {},
        'sourceRevision': 'original-v2',
      });
    }
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hierarchy-migration-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4))
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    interrupt = null;
    await open();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final activeV2 in [false, true]) {
    test(
      '${activeV2 ? 'active v2' : 'legacy'} preserves empty nodes and parent IDs after cold reopen',
      () async {
        await seed(activeV2: activeV2);
        final sourceGroups =
            (activeV2
                    ? Hive.box<BookmarkGroupHiveObject>('groups_unified_v2')
                    : groups)
                .length;
        final migrated = await migration().open();
        final result = await migrated.getGroups();
        expect(await migrated.readRecentGroupIds(), [child]);
        expect(result.singleWhere((g) => g.id == child).parentGroupId, parent);
        expect(result.singleWhere((g) => g.id == empty).parentGroupId, parent);
        expect(result.where((g) => g.id == parent), hasLength(1));
        expect(result.every((g) => g.folderId == null), isTrue);
        expect(
          contentMap(storage.metadataBox.get('activeOrganization'))['version'],
          3,
        );
        if (activeV2)
          expect(
            contentMap(storage.metadataBox.get('idReservation'))['nextId'],
            50,
          );
        await restart();
        final reopened = await migration().open();
        expect(await reopened.getGroups(), result);
        expect(await reopened.readRecentGroupIds(), [child]);
        expect(
          (activeV2
                  ? await Hive.openBox<BookmarkGroupHiveObject>(
                      'groups_unified_v2',
                    )
                  : groups)
              .length,
          sourceGroups,
        );
      },
    );
  }

  for (final phase in [
    'hierarchy-plan',
    'hierarchy-organization',
    'hierarchy-activation',
    'hierarchy-cleanup',
  ]) {
    test(
      'v2 collision mapping replays $phase without replacing group UUIDs or reserving Bookmark IDs',
      () async {
        await seed(activeV2: true, collide: true);
        interrupt = phase;
        await expectLater(migration().open(), throwsStateError);
        final pending = contentMap(
          storage.metadataBox.get('organizationMigration') ?? const {},
        );
        final mapping = contentMap(
          contentMap(pending['plan'] ?? const {})['folderIdMapping'] ??
              const {},
        );
        if (phase == 'hierarchy-plan' || phase == 'hierarchy-organization') {
          expect(mapping[parent], isNot(parent));
        }
        await restart();
        final result = await (await migration().open()).getGroups();
        final convertedParent = result.singleWhere(
          (g) => g.id != parent && g.name == 'Same' && g.parentGroupId == null,
        );
        expect(
          result.singleWhere((g) => g.id == child).parentGroupId,
          convertedParent.id,
        );
        expect(
          result.singleWhere((g) => g.id == empty).parentGroupId,
          convertedParent.id,
        );
        expect(result.singleWhere((g) => g.id == parent).name, 'Same');
        expect(
          contentMap(storage.metadataBox.get('idReservation'))['nextId'],
          50,
        );
        expect(
          storage.metadataBox.containsKey('organizationMigration'),
          isFalse,
        );
        final finalRows = List<BookmarkGroup>.of(result);
        await restart();
        expect(await (await migration().open()).getGroups(), finalRows);
      },
    );
  }
}
