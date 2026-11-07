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
    'selected parent and child delete only those nodes and promote survivors to nearest ancestor',
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
        'Surviving grandchild',
        parentGroupId: child.id,
      );
      final saved = await addPost(201);
      await addMembership(grandchild.id, saved);
      final beforeGrandchild = (await groupRepository.getGroup(grandchild.id))!;

      final preview = await service.previewDeleteSelection(
        folderIds: const {},
        groupIds: {parent.id, child.id},
      );
      expect(preview.groupIds, {parent.id, child.id});
      await service.deleteSelection(preview);

      final groups = await groupRepository.getGroups();
      expect(groups.map((group) => group.id).toSet(), {
        defaultBookmarkGroupId,
        ancestor.id,
        grandchild.id,
      });
      final promoted = (await groupRepository.getGroup(grandchild.id))!;
      expect(promoted.parentGroupId, ancestor.id);
      expect(promoted.bookmarkIds, beforeGrandchild.bookmarkIds);
      expect(promoted.addedAt, beforeGrandchild.addedAt);
      expect(await repository.read(saved.id), isNotNull);
    },
  );

  test('deleting only a parent preserves its child and grandchild', () async {
    final parent = await createGroup('Parent');
    final child = await createGroup('Child', parentGroupId: parent.id);
    final grandchild = await createGroup(
      'Grandchild',
      parentGroupId: child.id,
    );
    final saved = await addPost(202);
    await addMembership(grandchild.id, saved);
    final before = (await groupRepository.getGroup(grandchild.id))!;

    await service.deleteGroup(parent.id);

    expect((await groupRepository.getGroup(parent.id)), isNull);
    expect((await groupRepository.getGroup(child.id))!.parentGroupId, isNull);
    final survivingGrandchild = (await groupRepository.getGroup(
      grandchild.id,
    ))!;
    expect(survivingGrandchild.parentGroupId, child.id);
    expect(survivingGrandchild.addedAt, before.addedAt);
    expect(await repository.read(saved.id), isNotNull);
  });

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
    'direct group repository deletion promotes children and preserves dates',
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
      final before = (await groupRepository.getGroup(child.id))!;

      await groupRepository.deleteGroup(deleted.id);

      final promoted = (await groupRepository.getGroup(child.id))!;
      expect(promoted.parentGroupId, ancestor.id);
      expect(promoted.addedAt, before.addedAt);
      expect(
        (await groupRepository.getGroup(grandchild.id))!.parentGroupId,
        child.id,
      );
      expect(await repository.read(saved.id), isNotNull);
    },
  );

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
