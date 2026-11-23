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

  Future<void> seed({bool collide = false}) async {
    final groupBox = groups;
    final folderBox = organization;
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

  for (final version in [2, 3]) {
    test('preserves unsupported development organization v$version', () async {
      await seed();
      final suffix = version == 2 ? '_unified_v2' : '_hierarchy_v3';
      final groupBox = await Hive.openBox<BookmarkGroupHiveObject>(
        'groups$suffix',
      );
      final folderBox = await Hive.openBox<dynamic>('organization$suffix');
      await groupBox.put(
        child,
        BookmarkGroupHiveObject(
          id: child,
          name: 'Development Group',
          bookmarkIds: const [],
        ),
      );
      await folderBox.put('version', version);
      final marker = {
        'version': version,
        'generation': {'groups': groupBox.name, 'organization': folderBox.name},
        'sourceRevision': 'development',
      };
      await storage.metadataBox.put('activeOrganization', marker);
      await expectLater(migration().open(), throwsFormatException);
      await restart();
      await expectLater(migration().open(), throwsFormatException);
      expect(storage.metadataBox.get('activeOrganization'), marker);
      expect(
        (await Hive.openBox<BookmarkGroupHiveObject>(groupBox.name))
            .get(child)!
            .name,
        'Development Group',
      );
      expect(
        (await Hive.openBox<dynamic>(folderBox.name)).get('version'),
        version,
      );
      expect(await Hive.boxExists('groups_hierarchy_v2'), isFalse);
    });
  }

  for (final phase in ['plan', 'organization', 'activation', 'cleanup']) {
    test(
      'released layout collision mapping replays $phase without replacing group UUIDs or reserving Bookmark IDs',
      () async {
        await seed(collide: true);
        await storage.repository(posts).reserveIds(50);
        interrupt = phase;
        await expectLater(migration().open(), throwsStateError);
        final pending = contentMap(
          storage.metadataBox.get('organizationMigration') ?? const {},
        );
        final mapping = contentMap(
          contentMap(pending['plan'] ?? const {})['folderIdMapping'] ??
              const {},
        );
        if (phase == 'plan' || phase == 'organization') {
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
        expect(
          contentMap(storage.metadataBox.get('activeOrganization'))['version'],
          2,
        );
        expect(await Hive.boxExists('groups_unified_v2'), isFalse);
        expect(await Hive.boxExists('groups_hierarchy_v3'), isFalse);
        final finalRows = List<BookmarkGroup>.of(result);
        await restart();
        expect(await (await migration().open()).getGroups(), finalRows);
      },
    );
  }
}
