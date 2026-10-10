import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_planner.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_service.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart';
import '../search/subscriptions/subscription_test_utils.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

class FailingGroups extends BookmarkGroupRepositoryHive {
  FailingGroups(super.box, {required super.organizationBox});
  @override
  Future<BookmarkGroup> createGroup(String name, {String? id}) {
    if (name == 'Fail') throw StateError('Simulated group write failure');
    return super.createGroup(name, id: id);
  }
}

class FailingBookmarks extends BookmarkHiveRepository {
  FailingBookmarks(super.box);
  bool failRemoval = false;
  @override
  Future<void> removeBookmarks(Iterable<Bookmark> bookmarks) async {
    await super.removeBookmarks(bookmarks);
    if (failRemoval) {
      failRemoval = false;
      throw StateError('Simulated post-write failure');
    }
  }
}

class LegacyGroupAdapter extends TypeAdapter<BookmarkGroupHiveObject> {
  @override
  int get typeId => 5;
  @override
  BookmarkGroupHiveObject read(BinaryReader reader) =>
      throw UnimplementedError();
  @override
  void write(BinaryWriter writer, BookmarkGroupHiveObject value) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(value.id)
      ..writeByte(1)
      ..write(value.name)
      ..writeByte(2)
      ..write(value.bookmarkIds);
  }
}

void main() {
  late Directory dir;
  late Box<BookmarkGroupHiveObject> groupBox;
  late Box<BookmarkHiveObject> bookmarkBox;
  late Box<dynamic> folderBox;
  late BookmarkGroupRepositoryHive groups;
  late FailingBookmarks bookmarks;
  late BookmarkLibraryService service;
  BookmarkImportService importer([BookmarkGroupRepository? repository]) =>
      BookmarkImportService(
        bookmarkRepository: bookmarks,
        groupRepository: repository ?? groups,
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      );
  Future<Bookmark> add(int n) async =>
      (await bookmarks.addBookmarkWithBookmarks([
        Bookmark.empty.copyWith(
          id: n,
          postId: () => n,
          sourceUrl: 'https://example.com',
        ),
      ])).single;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('object_folders_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(4))
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(6))
      Hive.registerAdapter(SearchSubscriptionHiveObjectAdapter());
    groupBox = await Hive.openBox('groups');
    bookmarkBox = await Hive.openBox('bookmarks');
    folderBox = await Hive.openBox('folders');
    groups = BookmarkGroupRepositoryHive(groupBox, organizationBox: folderBox);
    bookmarks = FailingBookmarks(bookmarkBox);
    service = BookmarkLibraryService(
      bookmarkRepository: bookmarks,
      groupRepository: groups,
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    );
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test(
    'pre-folder Hive group records reopen without changing UUIDs or memberships',
    () async {
      Hive.registerAdapter(LegacyGroupAdapter(), override: true);
      await groupBox.put(
        id(1),
        BookmarkGroupHiveObject(
          id: id(1),
          name: 'Literal//name',
          bookmarkIds: [1, 2],
        ),
      );
      await groupBox.close();
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter(), override: true);
      groupBox = await Hive.openBox('groups');
      groups = BookmarkGroupRepositoryHive(
        groupBox,
        organizationBox: folderBox,
      );
      await groups.initializeFolders();
      final group = (await groups.getGroups()).single;
      expect(group.id, id(1));
      expect(group.name, 'Literal//name');
      expect(group.bookmarkIds, {1, 2});
      expect(group.folderId, isNull);
      expect(group.position, 0);
    },
  );
  test(
    'flat migration keeps literal names, UUIDs, memberships and alphabetical order',
    () async {
      await groups.createGroup('Z//literal', id: id(1));
      await groups.createGroup('Alpha', id: id(2));
      await groups.addBookmarks(id(1), {10});
      await groups.initializeFolders();
      final before = await groups.getGroups();
      expect(before.map((g) => g.id), [id(2), id(1)]);
      expect(before.last.name, 'Z//literal');
      expect(before.last.bookmarkIds, {10});
      expect(before.every((g) => g.folderId == null), isTrue);
      await groups.initializeFolders();
      expect(await groups.getGroups(), before);
    },
  );
  test(
    'empty folders and nested group placements survive closing and reopening Hive',
    () async {
      await groups.initializeFolders();
      final root = await service.createFolder('Cookie');
      final child = await service.createFolder('Empty', parentId: root.id);
      await groups.createGroup('Literal//Name', id: id(1));
      await service.moveFolderItems(groupIds: {id(1)}, destination: child.id);
      await groupBox.close();
      await folderBox.close();
      groupBox = await Hive.openBox('groups');
      folderBox = await Hive.openBox('folders');
      groups = BookmarkGroupRepositoryHive(
        groupBox,
        organizationBox: folderBox,
      );
      await groups.initializeFolders();
      expect(
        FolderTree(await groups.getFolders()).path(child.id),
        'Cookie / Empty',
      );
      expect((await groups.getGroup(id(1)))!.folderId, child.id);
      expect((await groups.getGroup(id(1)))!.name, 'Literal//Name');
    },
  );
  test(
    'moving selected folders and groups plans one coherent destination',
    () async {
      final root = await service.createFolder('Root');
      final child = await service.createFolder('Child', parentId: root.id);
      final destination = await service.createFolder('Destination');
      await groups.createGroup('Inside', id: id(1));
      await groups.createGroup('Outside', id: id(2));
      await service.moveFolderItems(groupIds: {id(1)}, destination: child.id);
      await service.moveFolderItems(
        folderIds: {root.id, child.id},
        groupIds: {id(1), id(2)},
        destination: destination.id,
      );
      final tree = FolderTree(await groups.getFolders());
      expect(tree.byId[root.id]!.parentId, destination.id);
      expect(tree.byId[child.id]!.parentId, root.id);
      expect((await groups.getGroup(id(1)))!.folderId, child.id);
      expect((await groups.getGroup(id(2)))!.folderId, destination.id);
      final old = await groups.getFolders();
      await expectLater(
        service.moveFolderItems(folderIds: {root.id}, destination: child.id),
        throwsFormatException,
      );
      expect(await groups.getFolders(), old);
    },
  );
  test(
    'recursive deletion counts unique orphans and preserves shared and ungrouped bookmarks',
    () async {
      final only = await add(1),
          shared = await add(2),
          ungrouped = await add(3);
      final root = await service.createFolder('Root');
      final child = await service.createFolder('Child', parentId: root.id);
      for (var i = 1; i <= 3; i++) {
        await groups.createGroup('Group', id: id(i));
      }
      await groups.replaceMemberships(id(1), {only.id, shared.id});
      await groups.replaceMemberships(id(2), {only.id});
      await groups.replaceMemberships(id(3), {shared.id});
      await service.moveFolderItems(groupIds: {id(1)}, destination: root.id);
      await service.moveFolderItems(groupIds: {id(2)}, destination: child.id);
      final preview = await service.previewDeleteFolder(root.id);
      expect(preview.folderIds, hasLength(2));
      expect(preview.groupIds, hasLength(2));
      expect(preview.orphanBookmarkIds, {only.id});
      await service.deleteFolder(preview);
      final state = await service.load(const BookmarkTarget.defaultGroup());
      expect(state.groups.where((g) => !g.isDefault).map((g) => g.id), [id(3)]);
      expect(state.bookmarksById.keys, {shared.id, ungrouped.id});
      expect(state.folders, isEmpty);
    },
  );
  test('stale delete confirmations make no mutations', () async {
    final folder = await service.createFolder('Root');
    await groups.createGroup('Group', id: id(1));
    await service.moveFolderItems(groupIds: {id(1)}, destination: folder.id);
    final preview = await service.previewDeleteFolder(folder.id);
    await groups.renameGroup(id(1), 'Changed');
    await expectLater(
      service.deleteFolder(preview),
      throwsA(isA<BookmarkFolderChangedException>()),
    );
    expect(await groups.getFolders(), hasLength(1));
    expect(await groups.getGroup(id(1)), isNotNull);
  });
  test(
    'post-write deletion failure restores folders, memberships and bookmark identities',
    () async {
      final b = await add(1);
      final folder = await service.createFolder('Root');
      await groups.createGroup('Group', id: id(1));
      await groups.replaceMemberships(id(1), {b.id});
      await service.moveFolderItems(groupIds: {id(1)}, destination: folder.id);
      final before = await service.load(const BookmarkTarget.defaultGroup());
      bookmarks.failRemoval = true;
      await expectLater(
        service.deleteFolder(await service.previewDeleteFolder(folder.id)),
        throwsStateError,
      );
      expect(await service.load(const BookmarkTarget.defaultGroup()), before);
    },
  );
  test(
    'mixed Copy, Update, Merge into and Skip reconstruct only copied source branches',
    () async {
      final local = await service.createFolder('Local');
      for (var n = 1; n <= 3; n++) {
        await groups.createGroup('Local $n', id: id(n));
        await service.moveFolderItems(groupIds: {id(n)}, destination: local.id);
      }
      final data = BookmarkBackupData(
        bookmarks: [],
        folders: [
          CollectionFolder(id: id(10), name: 'Cookie'),
          CollectionFolder(id: id(11), name: 'Anime', parentId: id(10)),
          CollectionFolder(id: id(12), name: 'Manga', parentId: id(10)),
          CollectionFolder(id: id(13), name: 'Another'),
        ],
        groups: [
          BookmarkGroupBackup(
            id: id(1),
            name: 'A',
            bookmarkIds: [],
            folderId: id(11),
          ),
          BookmarkGroupBackup(
            id: id(2),
            name: 'B',
            bookmarkIds: [],
            folderId: id(12),
          ),
          BookmarkGroupBackup(
            id: id(4),
            name: 'C',
            bookmarkIds: [],
            folderId: id(13),
          ),
          BookmarkGroupBackup(id: id(5), name: 'Skipped', bookmarkIds: []),
          BookmarkGroupBackup(
            id: id(6),
            name: 'Merged',
            bookmarkIds: [],
            folderId: id(12),
          ),
        ],
      );
      final plan = const BookmarkImportPlanner().plan(
        data: data,
        currentBookmarks: [],
        currentGroups: await groups.getGroups(),
      );
      final actions = {
        for (final g in plan.groups)
          g.id: g.resolveAction(
            g.id == id(1) || g.id == id(4)
                ? ImportAction.copy
                : g.id == id(2)
                ? ImportAction.update
                : g.id == id(6)
                ? ImportAction.mergeIntoTarget
                : ImportAction.skip,
            targetId: g.id == id(6) ? id(3) : null,
            destinationId: g.id == id(1) ? id(20) : g.id,
          ),
      };
      await importer().apply(plan.resolveActions(actions));
      final tree = FolderTree(await groups.getFolders());
      expect(
        tree.path((await groups.getGroup(id(20)))!.folderId),
        'Imported Groups / Cookie / Anime',
      );
      expect(
        tree.path((await groups.getGroup(id(4)))!.folderId),
        'Imported Groups / Another',
      );
      expect(tree.folders.any((f) => f.name == 'Manga'), isFalse);
      expect((await groups.getGroup(id(2)))!.folderId, local.id);
      expect((await groups.getGroup(id(2)))!.name, 'Local 2');
      expect((await groups.getGroup(id(3)))!.folderId, local.id);
      expect(await groups.getGroup(id(5)), isNull);
      expect(
        tree.children(null).where((f) => f.name.startsWith('Imported')),
        hasLength(1),
      );
    },
  );
  test(
    'updates and merges retain local folders and never create import wrappers',
    () async {
      final folder = await service.createFolder('Local');
      await groups.createGroup('Keep', id: id(1));
      await service.moveFolderItems(groupIds: {id(1)}, destination: folder.id);
      final data = BookmarkBackupData(
        bookmarks: [],
        folders: [CollectionFolder(id: id(10), name: 'Remote')],
        groups: [
          BookmarkGroupBackup(
            id: id(1),
            name: 'Incoming',
            bookmarkIds: [],
            folderId: id(10),
          ),
        ],
      );
      for (final action in [ImportAction.update, ImportAction.merge]) {
        final plan = const BookmarkImportPlanner().plan(
          data: data,
          currentBookmarks: [],
          currentGroups: await groups.getGroups(),
        );
        await importer().apply(
          plan.resolveActions({
            id(1): plan.groups.single.resolveAction(action),
          }),
        );
      }
      expect(await groups.getFolders(), [folder]);
      expect((await groups.getGroup(id(1)))!.folderId, folder.id);
      expect((await groups.getGroup(id(1)))!.name, 'Keep');
    },
  );
  test(
    'failed copies remove the wrapper and restore the previous hierarchy',
    () async {
      final folder = await service.createFolder('Existing');
      await groups.createGroup('Keep', id: id(1));
      await service.moveFolderItems(groupIds: {id(1)}, destination: folder.id);
      final data = BookmarkBackupData(
        bookmarks: [],
        folders: [CollectionFolder(id: id(10), name: 'Remote')],
        groups: [
          BookmarkGroupBackup(
            id: id(2),
            name: 'First',
            bookmarkIds: [],
            folderId: id(10),
          ),
          BookmarkGroupBackup(
            id: id(3),
            name: 'Fail',
            bookmarkIds: [],
            folderId: id(10),
          ),
        ],
      );
      final plan = const BookmarkImportPlanner().plan(
        data: data,
        currentBookmarks: [],
        currentGroups: await groups.getGroups(),
      );
      await expectLater(
        importer(
          FailingGroups(groupBox, organizationBox: folderBox),
        ).apply(plan),
        throwsStateError,
      );
      expect(await groups.getFolders(), [folder]);
      expect((await groups.getGroups()).map((g) => g.id), [id(1)]);
      expect((await groups.getGroup(id(1)))!.folderId, folder.id);
    },
  );
  test(
    'full category Replace restores nested and empty folders without a wrapper',
    () async {
      await service.createFolder('Discard');
      await groups.createGroup('Old', id: id(1));
      final data = BookmarkBackupData(
        bookmarks: [],
        folders: [
          CollectionFolder(id: id(10), name: 'Root'),
          CollectionFolder(
            id: id(11),
            name: 'Empty',
            parentId: id(10),
            position: 4,
          ),
        ],
        groups: [
          BookmarkGroupBackup(
            id: id(2),
            name: 'Group',
            bookmarkIds: [],
            folderId: id(10),
            position: 3,
          ),
        ],
      );
      await importer().replace(data);
      expect(await groups.getFolders(), data.folders);
      expect((await groups.getGroup(id(2)))!.folderId, id(10));
      expect((await groups.getGroup(id(2)))!.position, 3);
      expect(await groups.getGroup(id(1)), isNull);
      await importer().replace(
        BookmarkBackupData(
          bookmarks: [],
          groups: [
            BookmarkGroupBackup(id: id(3), name: 'Flat', bookmarkIds: []),
          ],
        ),
      );
      expect(await groups.getFolders(), isEmpty);
      expect((await groups.getGroup(id(3)))!.folderId, isNull);
    },
  );
  test(
    'failed category Replace restores old folder placements and memberships',
    () async {
      final b = await add(1);
      final folder = await service.createFolder('Keep');
      await groups.createGroup('Group', id: id(1));
      await groups.addBookmarks(id(1), {b.id});
      await service.moveFolderItems(groupIds: {id(1)}, destination: folder.id);
      final data = BookmarkBackupData(
        bookmarks: [],
        groups: [BookmarkGroupBackup(id: id(2), name: 'Fail', bookmarkIds: [])],
      );
      await expectLater(
        importer(
          FailingGroups(groupBox, organizationBox: folderBox),
        ).replace(data),
        throwsStateError,
      );
      final state = await service.load(const BookmarkTarget.defaultGroup());
      expect(state.folders, [folder]);
      expect(
        state.groups.where((g) => !g.isDefault).single.folderId,
        folder.id,
      );
      expect(
        state.groups.where((g) => !g.isDefault).single.bookmarkIds,
        state.items.map((b) => b.id).toSet(),
      );
      expect(state.items.single.transferIdentity, b.transferIdentity);
    },
  );
  test(
    'selective export keeps ancestors and excludes unrelated sibling groups',
    () async {
      final root = await service.createFolder('Root');
      final child = await service.createFolder('Child', parentId: root.id);
      final other = await service.createFolder('Other');
      await groups.createGroup('Chosen', id: id(1));
      await groups.createGroup('Excluded', id: id(2));
      await service.moveFolderItems(groupIds: {id(1)}, destination: child.id);
      await service.moveFolderItems(groupIds: {id(2)}, destination: root.id);
      final data = buildBookmarkBackupData(
        bookmarks: [],
        groups: await groups.getGroups(),
        folders: await groups.getFolders(),
        scope: BookmarkExportScope.selected(groupIds: {id(1)}),
      );
      expect(data.groups.map((g) => g.id), [id(1)]);
      expect(data.folders.map((f) => f.id).toSet(), {root.id, child.id});
      final empty = buildBookmarkBackupData(
        bookmarks: [],
        groups: await groups.getGroups(),
        folders: await groups.getFolders(),
        scope: BookmarkExportScope.selected(
          groupIds: {},
          folderIds: {other.id},
        ),
      );
      expect(empty.folders, [other]);
      expect(empty.groups, isEmpty);
    },
  );
  test(
    'legacy search organization migrates once without touching runtime records or empty folders',
    () async {
      final box = MemorySubscriptionBox(), organization = MemoryBox<dynamic>();
      final repository = HiveSearchSubscriptionRepository(
        box: box,
        organizationBox: organization,
      );
      final search = await repository.create(
        profileId: id(30),
        query: 'cat',
        name: 'Name',
        id: id(1),
      );
      await repository.markRead(search.id);
      final before = await repository.getById(search.id);
      await organization.put('search:organization', {
        'folders': [
          {
            'id': id(10),
            'name': 'Existing',
            'searchIds': [search.id],
          },
          {'id': id(11), 'name': 'Empty', 'searchIds': <String>[]},
        ],
        'homeSearchIds': <String>[],
      });
      final writes = box.mutationCount;
      final migrated = await repository.getOrganization();
      expect(migrated.folders.map((f) => f.id), [id(10), id(11)]);
      expect(migrated.directIds(id(10)), [search.id]);
      expect(migrated.folders.every((f) => f.parentId == null), isTrue);
      expect(box.mutationCount, writes);
      expect(await repository.getById(search.id), before);
      final json = organization.get('search:organization') as Map;
      expect(json['version'], 2);
      expect(json.containsKey('homeSearchIds'), isFalse);
      expect(
        (json['folders'] as List).every(
          (f) => !(f as Map).containsKey('searchIds'),
        ),
        isTrue,
      );
      expect(await repository.getOrganization(), migrated);
    },
  );
  test(
    'search folder moves and recursive deletion preserve unrelated searches and feed sources',
    () async {
      final repository = memorySubscriptionRepository();
      final first = await repository.create(
        profileId: id(30),
        query: 'cat',
        name: null,
      );
      final outside = await repository.create(
        profileId: id(30),
        query: 'dog',
        name: null,
      );
      final feed = await repository.saveFeed(
        profileId: id(30),
        name: 'Feed',
        queries: ['birds'],
      );
      await repository.replaceOrganization(
        SearchOrganization(
          folders: [
            SharedSearchFolder(id: id(10), name: 'Root'),
            SharedSearchFolder(
              id: id(11),
              name: 'Child',
              parentId: id(10),
              searchIds: [first.id],
            ),
          ],
          homeSearchIds: [outside.id],
        ),
      );
      final org = await repository.getOrganization();
      expect(org.recursiveIds(id(10)), [first.id]);
      await repository.replaceOrganization(
        org.move(folderIds: {id(11)}, destination: null),
      );
      expect(
        (await repository.getOrganization()).folders
            .singleWhere((f) => f.id == id(11))
            .parentId,
        isNull,
      );
      await repository.replaceOrganization(
        (await repository.getOrganization()).move(
          folderIds: {id(11)},
          destination: id(10),
        ),
      );
      await repository.deleteSharedFolderAndPins(id(10));
      expect(await repository.getById(first.id), isNull);
      expect(await repository.getById(outside.id), outside);
      expect(await repository.getFeeds(), [feed]);
      expect(await repository.getById(feed.sourceIds.single), isNotNull);
      expect((await repository.getOrganization()).folders, isEmpty);
    },
  );
}
