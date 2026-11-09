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
      'bookmark-hierarchy-mutations-',
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

  Future<void> restart() async {
    await Hive.close();
    Hive.init(directory.path);
    await attachRepository();
  }

  setUp(initialize);
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<PostBookmark> addPost(int sourceId) async {
    final localId = (await repository.reserveIds(1)).single;
    final bookmark = testPoolPost(sourceId).copyWith(id: localId);
    await repository.upsert(bookmark);
    return bookmark;
  }

  Future<void> addMembership(String groupId, PostBookmark bookmark) async {
    await groupRepository.addBookmarks(groupId, {bookmark.id});
  }

  test('nested empty groups persist through repository reopen', () async {
    final root = await service.createGroup('Root');
    final child = await service.createGroup(
      'Empty child',
      parentGroupId: root.id,
    );

    expect(child.parentGroupId, root.id);
    expect(child.bookmarkIds, isEmpty);
    await restart();

    expect((await groupRepository.getGroup(root.id))!.parentGroupId, isNull);
    final reopenedChild = (await groupRepository.getGroup(child.id))!;
    expect(reopenedChild.parentGroupId, root.id);
    expect(reopenedChild.bookmarkIds, isEmpty);
  });

  test(
    'invalid parent creation fails without writing or reserving an ID',
    () async {
      final beforeGroups = await groupRepository.getGroups();
      final beforeRevision = await repository.readRevision();
      final beforeNextId = (await repository.reserveIds(1)).single;

      await expectLater(
        service.createGroup(
          'Invalid child',
          parentGroupId: '99999999-9999-4999-8999-999999999999',
        ),
        throwsA(anything),
      );

      expect(await groupRepository.getGroups(), beforeGroups);
      expect(await repository.readRevision(), beforeRevision);
      final afterNextId = (await repository.reserveIds(1)).single;
      expect(afterNextId, beforeNextId + 1);
      expect(await repository.readRevision(), beforeRevision);
    },
  );

  test('moves reject self and descendant cycles before writes', () async {
    final root = await service.createGroup('Root');
    final child = await service.createGroup('Child', parentGroupId: root.id);
    final beforeRevision = await repository.readRevision();

    await expectLater(
      service.moveGroups({root.id}, parentGroupId: child.id),
      throwsA(anything),
    );
    await expectLater(
      service.moveGroups({child.id}, parentGroupId: child.id),
      throwsA(anything),
    );

    expect(await repository.readRevision(), beforeRevision);
    expect((await groupRepository.getGroup(root.id))!.parentGroupId, isNull);
    expect((await groupRepository.getGroup(child.id))!.parentGroupId, root.id);
  });

  test(
    'moving an ancestor and descendant moves the ancestor only once',
    () async {
      final destination = await service.createGroup('Destination');
      final root = await service.createGroup('Root');
      final child = await service.createGroup('Child', parentGroupId: root.id);

      await service.moveGroups(
        {root.id, child.id},
        parentGroupId: destination.id,
      );

      expect(
        (await groupRepository.getGroup(root.id))!.parentGroupId,
        destination.id,
      );
      expect(
        (await groupRepository.getGroup(child.id))!.parentGroupId,
        root.id,
      );
    },
  );

  test('Default group cannot be moved, renamed, or deleted', () async {
    final defaultGroup = (await groupRepository.getGroup(
      defaultBookmarkGroupId,
    ))!;
    final destination = await service.createGroup('Destination');
    final beforeRevision = await repository.readRevision();

    await expectLater(
      service.moveGroups(
        {defaultGroup.id},
        parentGroupId: destination.id,
      ),
      throwsA(anything),
    );
    await expectLater(
      groupRepository.renameGroup(defaultGroup.id, 'Renamed Default'),
      throwsA(anything),
    );
    await expectLater(
      service.deleteGroup(defaultGroup.id),
      throwsA(anything),
    );

    expect(await repository.readRevision(), beforeRevision);
    expect(
      (await groupRepository.getGroup(defaultBookmarkGroupId))!.name,
      'Default',
    );
  });

  test(
    'deleting a parent removes its subtree and only exclusively held payloads',
    () async {
      final parent = await service.createGroup('Parent');
      final child = await service.createGroup(
        'Child',
        parentGroupId: parent.id,
      );
      final other = await service.createGroup('Other');
      final orphan = await addPost(101);
      final shared = await addPost(102);
      await addMembership(parent.id, orphan);
      await addMembership(child.id, shared);
      await addMembership(other.id, shared);
      final otherDate = (await groupRepository.getGroup(other.id))!
          .addedAt[shared.id];

      await service.deleteGroup(parent.id);

      expect(await groupRepository.getGroup(parent.id), isNull);
      expect(await groupRepository.getGroup(child.id), isNull);
      expect(
        (await groupRepository.getGroup(other.id))!.addedAt[shared.id],
        otherDate,
      );
      expect(await repository.read(orphan.id), isNull);
      expect(await repository.read(shared.id), isNotNull);
      await restart();
      expect(await groupRepository.getGroup(parent.id), isNull);
      expect(await groupRepository.getGroup(child.id), isNull);
      expect(await repository.read(orphan.id), isNull);
      expect(await repository.read(shared.id), isNotNull);
      expect(
        (await groupRepository.getGroup(other.id))!.addedAt[shared.id],
        otherDate,
      );
    },
  );

  test(
    'duplicate copies only direct memberships and keeps the same parent',
    () async {
      final parent = await service.createGroup('Parent');
      final child = await service.createGroup(
        'Child',
        parentGroupId: parent.id,
      );
      final direct = await addPost(103);
      final nested = await addPost(104);
      await addMembership(parent.id, direct);
      await addMembership(child.id, nested);
      final parentBefore = (await groupRepository.getGroup(parent.id))!;

      final duplicate = await service.duplicateGroup(parent.id, 'Parent copy');

      expect(duplicate.parentGroupId, parentBefore.parentGroupId);
      expect(duplicate.bookmarkIds, parentBefore.bookmarkIds);
      expect(duplicate.bookmarkIds, {direct.id});
      expect(duplicate.addedAt, parentBefore.addedAt);
      expect(
        (await groupRepository.getGroup(child.id))!.parentGroupId,
        parent.id,
      );
      expect(duplicate.bookmarkIds, isNot(contains(nested.id)));
    },
  );
}
