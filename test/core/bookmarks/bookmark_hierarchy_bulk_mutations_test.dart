import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'pool_bookmark_test_utils.dart';

void main() {
  late Directory directory;
  late BookmarkHiveRepository repository;
  late BookmarkGroupRepository groupRepository;
  late BookmarkLibraryService service;

  Future<void> attachRepository() async {
    final posts = await Hive.openBox<BookmarkHiveObject>('posts');
    final payloads = await Hive.openBox<dynamic>('posts_unified_payloads');
    final metadata = await Hive.openBox<dynamic>('posts_unified_metadata');
    await Hive.openBox<BookmarkGroupHiveObject>('groups');
    final organization = await Hive.openBox<dynamic>('organization');
    if (!organization.containsKey('version')) {
      await organization.put('version', 1);
      await organization.put('poolBookmarks', []);
    }
    repository = BookmarkHiveRepository(
      posts,
      groupPayloadBox: payloads,
      metadataBox: metadata,
      coordinator: DataMutationCoordinator(),
      legacyGroupBoxName: 'groups',
      legacyOrganizationBoxName: 'organization',
    );
    groupRepository = await repository.openOrganization();
    service = BookmarkLibraryService(
      bookmarkRepository: repository,
      groupRepository: groupRepository,
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    );
  }

  Future<void> initialize() async {
    directory = await Directory.systemTemp.createTemp(
      'bookmark-hierarchy-bulk-mutations-',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    await attachRepository();
  }

  setUp(initialize);
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<BookmarkGroup> createGroup(
    String name, {
    String? parentGroupId,
  }) => service.createGroup(name, parentGroupId: parentGroupId);

  Future<PostBookmark> addPost(int sourceId) async {
    final localId = (await repository.reserveIds(1)).single;
    final bookmark = testPoolPost(sourceId).copyWith(id: localId);
    await repository.upsert(bookmark);
    return bookmark;
  }

  Future<void> addMembership(String groupId, PostBookmark bookmark) async {
    await groupRepository.addBookmarks(groupId, {bookmark.id});
  }

  test(
    'overlapping parent and child selections delete the subtree exactly once',
    () async {
      final ancestor = await createGroup('Surviving ancestor');
      final parent = await createGroup(
        'Selected parent',
        parentGroupId: ancestor.id,
      );
      final child = await createGroup(
        'Selected child',
        parentGroupId: parent.id,
      );
      final grandchild = await createGroup(
        'Deleted grandchild',
        parentGroupId: child.id,
      );
      final saved = await addPost(201);
      await addMembership(grandchild.id, saved);

      final preview = await service.previewDeleteSelection(
        folderIds: const {},
        groupIds: {parent.id, child.id},
      );
      expect(preview.groupIds, {parent.id, child.id, grandchild.id});
      expect(preview.orphanBookmarkIds, {saved.id});
      await service.deleteSelection(preview);

      final groups = await groupRepository.getGroups();
      expect(groups.map((group) => group.id).toSet(), {
        defaultBookmarkGroupId,
        ancestor.id,
      });
      expect(await groupRepository.getGroup(grandchild.id), isNull);
      expect(await repository.read(saved.id), isNull);
    },
  );

  test(
    'single parent deletion removes child and grandchild payloads',
    () async {
      final parent = await createGroup('Parent');
      final child = await createGroup('Child', parentGroupId: parent.id);
      final grandchild = await createGroup(
        'Grandchild',
        parentGroupId: child.id,
      );
      final saved = await addPost(202);
      await addMembership(grandchild.id, saved);

      await service.deleteGroup(parent.id);

      expect((await groupRepository.getGroup(parent.id)), isNull);
      expect(await groupRepository.getGroup(child.id), isNull);
      expect(await groupRepository.getGroup(grandchild.id), isNull);
      expect(await repository.read(saved.id), isNull);
    },
  );

  test('moving a group to its current parent is a no-op', () async {
    final parent = await createGroup('Parent');
    final child = await createGroup('Child', parentGroupId: parent.id);
    final saved = await addPost(203);
    await addMembership(child.id, saved);
    final beforeGroups = await groupRepository.getGroups();
    final beforeRevision = await repository.readRevision();

    await service.moveGroups({child.id}, parentGroupId: parent.id);

    expect(await repository.readRevision(), beforeRevision);
    expect(await groupRepository.getGroups(), beforeGroups);
    expect(
      (await groupRepository.getGroup(child.id))!.addedAt[saved.id],
      beforeGroups
          .singleWhere((group) => group.id == child.id)
          .addedAt[saved.id],
    );
  });

  test(
    'duplicating a nested child keeps its parent and only direct members',
    () async {
      final root = await createGroup('Root');
      final parent = await createGroup('Parent', parentGroupId: root.id);
      final child = await createGroup('Child', parentGroupId: parent.id);
      final grandchild = await createGroup(
        'Grandchild',
        parentGroupId: child.id,
      );
      final direct = await addPost(204);
      final nested = await addPost(205);
      await addMembership(child.id, direct);
      await addMembership(grandchild.id, nested);
      final before = (await groupRepository.getGroup(child.id))!;

      final duplicate = await service.duplicateGroup(child.id, 'Child copy');

      expect(duplicate.parentGroupId, parent.id);
      expect(duplicate.bookmarkIds, {direct.id});
      expect(duplicate.addedAt, before.addedAt);
      expect(duplicate.bookmarkIds, isNot(contains(nested.id)));
    },
  );

  test(
    'direct group repository deletion removes the same complete subtree',
    () async {
      final ancestor = await createGroup('Ancestor');
      final deleted = await createGroup('Deleted', parentGroupId: ancestor.id);
      final child = await createGroup('Child', parentGroupId: deleted.id);
      final grandchild = await createGroup(
        'Grandchild',
        parentGroupId: child.id,
      );
      final saved = await addPost(206);
      await addMembership(child.id, saved);
      final preview = await groupRepository.previewDeleteGroup(deleted.id);
      expect(preview.descendantGroups.map((group) => group.id).toSet(), {
        child.id,
        grandchild.id,
      });
      expect(preview.orphanBookmarkIds, {saved.id});

      await groupRepository.deleteGroup(deleted.id);

      expect(await groupRepository.getGroup(ancestor.id), isNotNull);
      expect(await groupRepository.getGroup(deleted.id), isNull);
      expect(await groupRepository.getGroup(child.id), isNull);
      expect(await groupRepository.getGroup(grandchild.id), isNull);
      expect(await repository.read(saved.id), isNull);
    },
  );

  test('confirmed root preview remains valid for the notifier expanded subtree call', () async {
    final a = await createGroup('A');
    final b = await createGroup('B', parentGroupId: a.id);
    final c = await createGroup('C', parentGroupId: b.id);
    final preview = await service.previewDeleteSelection(
      folderIds: const {},
      groupIds: {a.id},
    );
    expect(preview.selectedGroupIds, {a.id});
    expect(preview.groupIds, {a.id, b.id, c.id});
    final receipt = await service.deleteHierarchy(
      preview.groupIds,
      expectedPreview: preview,
    );
    expect(
      receipt.deletedGroups.map((group) => group.id).toSet(),
      preview.groupIds,
    );
    for (final id in preview.groupIds) {
      expect(await groupRepository.getGroup(id), isNull);
    }
    await service.undoHierarchyDeletion(receipt);
    expect((await groupRepository.getGroup(c.id))!.parentGroupId, b.id);
  });

  test('two disjoint subtrees remove each member once and preserve outside membership', () async {
    final a = await createGroup('A');
    final b = await createGroup('B', parentGroupId: a.id);
    final c = await createGroup('C');
    final d = await createGroup('D', parentGroupId: c.id);
    final outside = await createGroup('Outside');
    final shared = await addPost(210);
    final firstOrphan = await addPost(211);
    final secondOrphan = await addPost(212);
    await addMembership(b.id, shared);
    await addMembership(d.id, shared);
    await addMembership(outside.id, shared);
    await addMembership(b.id, firstOrphan);
    await addMembership(d.id, secondOrphan);
    final outsideBefore = await groupRepository.getGroup(outside.id);
    final preview = await service.previewDeleteSelection(
      folderIds: const {},
      groupIds: {a.id, b.id, c.id},
    );
    expect(preview.groupIds, {a.id, b.id, c.id, d.id});
    expect(preview.orphanBookmarkIds, {firstOrphan.id, secondOrphan.id});
    await service.deleteSelection(preview);
    expect(await groupRepository.getGroup(outside.id), outsideBefore);
    expect(await repository.read(shared.id), isNotNull);
    expect(await repository.read(firstOrphan.id), isNull);
    expect(await repository.read(secondOrphan.id), isNull);
    for (final id in [a.id, b.id, c.id, d.id]) {
      expect(await groupRepository.getGroup(id), isNull);
    }
  });

  for (final change in ['new child', 'outside membership']) {
    for (final hierarchy in [false, true]) {
      test(
        'stale ${hierarchy ? 'hierarchy' : 'selection'} confirmation rejects $change',
        () async {
          final parent = await createGroup('Parent');
          final child = await createGroup('Child', parentGroupId: parent.id);
          final outside = await createGroup('Outside');
          final saved = await addPost(213);
          await addMembership(child.id, saved);
          final preview = await service.previewDeleteSelection(
            folderIds: const {},
            groupIds: {parent.id},
          );
          expect(preview.orphanBookmarkIds, {saved.id});
          if (change == 'new child') {
            await createGroup(
              'Added after confirmation',
              parentGroupId: child.id,
            );
          } else {
            await addMembership(outside.id, saved);
          }
          final before = await groupRepository.getGroups();
          final revision = await repository.readRevision();
          await expectLater(
            hierarchy
                ? service.deleteHierarchy({parent.id}, expectedPreview: preview)
                : service.deleteSelection(preview),
            throwsA(isA<BookmarkCollectionChangedException>()),
          );
          expect(await groupRepository.getGroups(), before);
          expect(await repository.readRevision(), revision);
          expect(await repository.read(saved.id), isNotNull);
        },
      );
    }
  }

  test(
    'legacy folder facade creates and renames ordinary hierarchy groups',
    () async {
      final parent = await createGroup('Parent');
      final folder = await service.createFolder(
        'Compatibility folder',
        parentId: parent.id,
      );

      expect(await groupRepository.getFolders(), isEmpty);
      final createdGroup = (await groupRepository.getGroup(folder.id))!;
      expect(createdGroup.id, folder.id);
      expect(createdGroup.name, 'Compatibility folder');
      expect(createdGroup.parentGroupId, parent.id);
      expect(createdGroup.bookmarkIds, isEmpty);

      await service.renameFolder(folder.id, 'Renamed compatibility group');

      expect(
        (await groupRepository.getGroup(folder.id))!.name,
        'Renamed compatibility group',
      );
      expect(await groupRepository.getFolders(), isEmpty);
    },
  );
}
