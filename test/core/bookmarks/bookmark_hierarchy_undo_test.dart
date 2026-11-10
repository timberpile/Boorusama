import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/bookmarks/src/types/unified_bookmark_store.dart';
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

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'bookmark-hierarchy-undo-',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    await attachRepository();
    expect(
      (Hive.box<dynamic>('posts_unified_metadata').get('activeOrganization')
          as Map)['version'],
      3,
    );
    expect(
      Hive.box<dynamic>('organization').get('version'),
      1,
      reason: 'Legacy recovery input remains unchanged',
    );
  });

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

  Future<PostBookmark> addOpaquePost(
    int sourceId, {
    required String tag,
    required String search,
  }) async {
    final localId = (await repository.reserveIds(1)).single;
    final bookmark = testPoolPost(sourceId, tags: {tag}).copyWith(
      id: localId,
      postId: () => null,
      metadata: {'search': search},
    );
    await repository.upsert(bookmark);
    return bookmark;
  }

  Future<void> setMembership(
    String groupId,
    Set<int> ids, {
    required Map<int, DateTime> dates,
  }) async {
    await groupRepository.replaceMemberships(
      groupId,
      ids,
      addedAt: dates,
    );
  }

  test(
    'subtree deletion and Undo preserve hierarchy, outside memberships, dates and mixed payloads',
    () async {
      final root = await service.createGroup('Root');
      final otherRootChild = await service.createGroup(
        'Other child',
        parentGroupId: root.id,
      );
      final parent = await service.createGroup(
        'Parent',
        parentGroupId: root.id,
      );
      final child = await service.createGroup(
        'Child',
        parentGroupId: parent.id,
      );
      final grandchild = await service.createGroup(
        'Grandchild',
        parentGroupId: child.id,
      );
      final poolId = (await repository.reserveIds(1)).single;
      final poolDate = DateTime.utc(2024, 2, 2);
      final pool = ContentGroupBookmark(
        id: poolId,
        snapshot: StoredGroupSnapshot(
          summary: ContentGroupSummary(
            reference: const ContentReferenceCodec().parse(
              engine: BooruType.danbooru,
              site: Uri.parse('https://danbooru.donmai.us'),
              kind: ContentKind.group,
              sourceKey: 'pool:900',
            ),
            title: 'Offline Series',
          ),
        ),
        createdAt: poolDate,
        observedAt: poolDate,
      );
      await repository.upsert(pool);
      await setMembership(child.id, {poolId}, dates: {poolId: poolDate});
      final orphan = await addPost(201);
      final shared = await addPost(202);
      final orphanDate = DateTime.utc(2024, 2, 3, 4, 5, 6);
      final parentSharedDate = DateTime.utc(2024, 2, 4, 4, 5, 6);
      final childSharedDate = DateTime.utc(2024, 2, 5, 4, 5, 6);
      final otherSharedDate = DateTime.utc(2024, 2, 6, 4, 5, 6);
      await setMembership(
        parent.id,
        {orphan.id, shared.id},
        dates: {
          orphan.id: orphanDate,
          shared.id: parentSharedDate,
        },
      );
      await setMembership(
        grandchild.id,
        {shared.id},
        dates: {
          shared.id: childSharedDate,
        },
      );
      await setMembership(
        otherRootChild.id,
        {shared.id},
        dates: {
          shared.id: otherSharedDate,
        },
      );
      final originalParent = (await groupRepository.getGroup(parent.id))!;
      final originalChild = (await groupRepository.getGroup(child.id))!;
      final originalGrandchild = (await groupRepository.getGroup(
        grandchild.id,
      ))!;
      final nextIdBeforeUndo = (await repository.reserveIds(1)).single;

      final deletion = await service.deleteHierarchy({parent.id});
      expect(deletion.deletedGroups.map((group) => group.id).toSet(), {
        parent.id,
        child.id,
        grandchild.id,
      });
      expect(deletion.singlePreview.group.id, parent.id);
      expect(
        deletion.singlePreview.descendantGroups
            .map((group) => group.id)
            .toSet(),
        {child.id, grandchild.id},
      );
      expect(deletion.deletedRecordIds, containsAll([orphan.id, poolId]));
      expect(await repository.read(poolId), isNull);
      expect(deletion.deletedRecordIds, isNot(contains(shared.id)));
      expect(await repository.read(orphan.id), isNull);
      expect(await repository.read(shared.id), isNotNull);
      expect(await groupRepository.getGroup(child.id), isNull);
      expect(await groupRepository.getGroup(grandchild.id), isNull);
      expect(
        (await groupRepository.getGroup(otherRootChild.id))!.addedAt[shared.id],
        otherSharedDate,
      );

      await service.undoHierarchyDeletion(deletion);

      final restoredParent = (await groupRepository.getGroup(parent.id))!;
      final restoredChild = (await groupRepository.getGroup(child.id))!;
      expect(restoredParent.parentGroupId, originalParent.parentGroupId);
      expect(restoredParent.position, originalParent.position);
      expect(restoredChild.parentGroupId, originalChild.parentGroupId);
      expect(restoredChild.position, originalChild.position);
      final restoredGrandchild = (await groupRepository.getGroup(
        grandchild.id,
      ))!;
      expect(
        restoredGrandchild.parentGroupId,
        originalGrandchild.parentGroupId,
      );
      expect(restoredGrandchild.position, originalGrandchild.position);
      expect(restoredGrandchild.addedAt[shared.id], childSharedDate);
      final restoredPoolId = restoredChild.bookmarkIds.single;
      expect(restoredPoolId, greaterThan(nextIdBeforeUndo));
      expect(restoredChild.addedAt[restoredPoolId], poolDate);
      final restoredPool =
          (await repository.read(restoredPoolId))! as ContentGroupBookmark;
      expect(restoredPool.snapshot, pool.snapshot);
      expect(restoredPool.reference, pool.reference);
      expect(
        (await groupRepository.getGroup(otherRootChild.id))!.addedAt[shared.id],
        otherSharedDate,
      );
      expect(restoredParent.addedAt[shared.id], parentSharedDate);

      final restoredOrphanId = restoredParent.bookmarkIds.singleWhere(
        (id) => id != shared.id,
      );
      expect(restoredOrphanId, greaterThan(nextIdBeforeUndo));
      expect(restoredParent.addedAt[restoredOrphanId], orphanDate);
      expect(await repository.read(restoredOrphanId), isNotNull);
      expect(await repository.read(shared.id), isNotNull);
      expect(
        (await repository.reserveIds(1)).single,
        greaterThan(restoredOrphanId),
      );
    },
  );

  test(
    'a recreated descendant rejects Undo without overwriting newer memberships',
    () async {
      final root = await service.createGroup('Root');
      final parent = await service.createGroup(
        'Parent',
        parentGroupId: root.id,
      );
      final child = await service.createGroup(
        'Child',
        parentGroupId: parent.id,
      );
      final later = await addPost(204);
      final laterDate = DateTime.utc(2024, 3, 2);
      final deletion = await service.deleteHierarchy({parent.id});
      expect(await groupRepository.getGroup(child.id), isNull);
      final replacement = child.copyWith(
        name: 'Replacement descendant',
        parentGroupId: root.id,
        bookmarkIds: {later.id},
        addedAt: {later.id: laterDate},
      );
      await unifiedBookmarkStorage(repository)!
          .commitOrganization(groups: [replacement]);
      final beforeRevision = await repository.readRevision();
      final marker = (await repository.reserveIds(1)).single;
      await expectLater(
        service.undoHierarchyDeletion(deletion),
        throwsStateError,
      );
      expect(await repository.readRevision(), beforeRevision);
      expect(await groupRepository.getGroup(parent.id), isNull);
      expect(await groupRepository.getGroup(child.id), replacement);
      expect((await repository.reserveIds(1)).single, marker + 1);
    },
  );

  test(
    'a recreated descendant moved elsewhere rejects Undo before writes or ID allocation',
    () async {
      final root = await service.createGroup('Root');
      final parent = await service.createGroup(
        'Parent',
        parentGroupId: root.id,
      );
      final child = await service.createGroup(
        'Child',
        parentGroupId: parent.id,
      );
      final destination = await service.createGroup('Other destination');
      final deletion = await service.deleteHierarchy({parent.id});
      await unifiedBookmarkStorage(repository)!.commitOrganization(
        groups: [
          child.copyWith(parentGroupId: root.id),
        ],
      );
      await service.moveGroups({child.id}, parentGroupId: destination.id);
      final beforeRevision = await repository.readRevision();
      final beforeGroups = await groupRepository.getGroups();
      final marker = (await repository.reserveIds(1)).single;

      await expectLater(
        service.undoHierarchyDeletion(deletion),
        throwsA(anything),
      );

      expect(await repository.readRevision(), beforeRevision);
      expect(await groupRepository.getGroups(), beforeGroups);
      expect(
        (await groupRepository.getGroup(child.id))!.parentGroupId,
        destination.id,
      );
      expect((await repository.reserveIds(1)).single, marker + 1);
    },
  );

  test(
    'a globally deleted originally shared record is never resurrected',
    () async {
      final parent = await service.createGroup('Parent');
      final other = await service.createGroup('Other');
      final shared = await addPost(205);
      final date = DateTime.utc(2024, 4, 1);
      await setMembership(parent.id, {shared.id}, dates: {shared.id: date});
      await setMembership(other.id, {shared.id}, dates: {shared.id: date});
      final deletion = await service.deleteHierarchy({parent.id});
      await service.deleteBookmarks([shared]);
      final beforeRevision = await repository.readRevision();
      final marker = (await repository.reserveIds(1)).single;

      await expectLater(
        service.undoHierarchyDeletion(deletion),
        throwsA(anything),
      );

      expect(await repository.read(shared.id), isNull);
      expect(await repository.readRevision(), beforeRevision);
      expect(await groupRepository.getGroup(parent.id), isNull);
      expect((await repository.reserveIds(1)).single, marker + 1);
    },
  );

  test(
    'a recreated deleted group identity rejects undo without overwrite',
    () async {
      final root = await service.createGroup('Root');
      final parent = await service.createGroup(
        'Parent',
        parentGroupId: root.id,
      );
      final child = await service.createGroup(
        'Child',
        parentGroupId: parent.id,
      );
      final deletion = await service.deleteHierarchy({parent.id});
      final replacement = BookmarkGroup(
        id: parent.id,
        name: 'Replacement',
        parentGroupId: root.id,
        position: 5,
        bookmarkIds: const {},
      );
      final store = unifiedBookmarkStorage(repository)!;
      await store.commitOrganization(groups: [replacement]);
      final beforeRevision = await repository.readRevision();
      final beforeGroups = await groupRepository.getGroups();
      final marker = (await repository.reserveIds(1)).single;

      await expectLater(
        service.undoHierarchyDeletion(deletion),
        throwsA(anything),
      );

      expect(await repository.readRevision(), beforeRevision);
      expect(await groupRepository.getGroups(), beforeGroups);
      expect((await groupRepository.getGroup(parent.id))!.name, 'Replacement');
      expect(await groupRepository.getGroup(child.id), isNull);
      expect((await repository.reserveIds(1)).single, marker + 1);
    },
  );

  test(
    'reallocated opaque records keep metadata and remain distinct',
    () async {
      final parent = await service.createGroup('Parent');
      final other = await service.createGroup('Other');
      final opaque = await addOpaquePost(
        206,
        tag: 'opaque-deleted',
        search: 'original opaque metadata',
      );
      final survivor = await addOpaquePost(
        207,
        tag: 'opaque-survivor',
        search: 'survivor metadata',
      );
      final date = DateTime.utc(2024, 5, 1);
      await setMembership(parent.id, {opaque.id}, dates: {opaque.id: date});
      await setMembership(other.id, {survivor.id}, dates: {survivor.id: date});
      final deletion = await service.deleteHierarchy({parent.id});
      expect(opaque.postId, isNull);

      await service.undoHierarchyDeletion(deletion);

      final parentAfterUndo = (await groupRepository.getGroup(parent.id))!;
      final restoredOpaqueId = parentAfterUndo.bookmarkIds.single;
      expect(restoredOpaqueId, isNot(opaque.id));
      expect(parentAfterUndo.addedAt[restoredOpaqueId], date);
      final records = await repository.readAll();
      final restored = records.singleWhere(
        (record) => record.id == restoredOpaqueId,
      ) as PostBookmark;
      final stillSaved = records.singleWhere(
        (record) => record.id == survivor.id,
      ) as PostBookmark;
      expect(restored.postId, isNull);
      expect(restored.tags, {'opaque-deleted'});
      expect(restored.metadata['search'], 'original opaque metadata');
      expect(stillSaved.postId, isNull);
      expect(stillSaved.tags, {'opaque-survivor'});
      expect(stillSaved.metadata['search'], 'survivor metadata');
    },
  );

  test('repeating undo does not duplicate the restored record', () async {
    final parent = await service.createGroup('Parent');
    final orphan = await addPost(208);
    final date = DateTime.utc(2024, 6, 1);
    await setMembership(parent.id, {orphan.id}, dates: {orphan.id: date});
    final deletion = await service.deleteHierarchy({parent.id});
    await service.undoHierarchyDeletion(deletion);
    final beforeRecords = await repository.readAll();
    final restoredId = (await groupRepository.getGroup(parent.id))!
        .bookmarkIds
        .single;

    try {
      await service.undoHierarchyDeletion(deletion);
    } catch (_) {
      // Rejection is valid; the state assertion below is the contract.
    }

    final afterRecords = await repository.readAll();
    expect(
      afterRecords.map((record) => record.id).toSet(),
      beforeRecords.map((record) => record.id).toSet(),
    );
    expect(
      afterRecords.where((record) => record.id == restoredId),
      hasLength(1),
    );
    expect(
      (await groupRepository.getGroup(parent.id))!.bookmarkIds,
      {restoredId},
    );
  });
}
