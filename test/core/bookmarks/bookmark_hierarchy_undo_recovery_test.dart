import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';

import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/related/related_posts_order_value.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;

import 'pool_bookmark_test_utils.dart';

void main() {
  test(
    'hierarchy Undo recovers after every durable sync using cold checkpoint reopen',
    () async {
      for (var boundary = 1; boundary <= 5; boundary++) {
        final fixtureDirectory = await Directory.systemTemp.createTemp(
          'bookmark-hierarchy-undo-$boundary-',
        );
        final powerCut = _PowerCutCapture(fixtureDirectory);
        Directory? checkpointDirectory;
        var hiveOpen = false;
        try {
          var workspace = await _openWorkspace(
            fixtureDirectory,
            powerCut.sync,
          );
          hiveOpen = true;
          expect(_activeOrganizationVersion(workspace), 3);

          final parent = await workspace.service.createGroup('Parent');
          final child = await workspace.service.createGroup(
            'Empty child',
            parentGroupId: parent.id,
          );
          final initialParent = (await workspace.groupRepository.getGroup(
            parent.id,
          ))!;
          final initialChild = (await workspace.groupRepository.getGroup(
            child.id,
          ))!;

          final reserved = await workspace.repository.reserveIds(2);
          final postCreated = DateTime.utc(2022, 3, 4, 5, 6, 7, 123, 456);
          final postUpdated = DateTime.utc(2023, 4, 5, 6, 7, 8, 234, 567);
          final orphanPost = testPoolPost(77).copyWith(
            id: reserved[0],
            postId: () => null,
            createdAt: postCreated,
            updatedAt: postUpdated,
          );
          final related = _relatedBookmark(reserved[1]);
          await workspace.repository.upsertAll([orphanPost, related]);

          final postMembershipDate = DateTime.utc(
            2024,
            5,
            6,
            7,
            8,
            9,
            345,
            678,
          );
          final relatedMembershipDate = DateTime.utc(
            2025,
            6,
            7,
            8,
            9,
            10,
            456,
            789,
          );
          final parentWithRecords = await workspace.groupRepository
              .replaceMemberships(
                parent.id,
                {orphanPost.id, related.id},
                addedAt: {
                  orphanPost.id: postMembershipDate,
                  related.id: relatedMembershipDate,
                },
              );
          expect(parentWithRecords.bookmarkIds, {orphanPost.id, related.id});
          expect(initialParent.bookmarkIds, isEmpty);
          expect(initialChild.bookmarkIds, isEmpty);

          final receipt = await workspace.service.deleteHierarchy({parent.id});
          expect(await workspace.groupRepository.getGroup(parent.id), isNull);
          expect(
            (await workspace.groupRepository.getGroup(child.id))!.parentGroupId,
            isNull,
          );
          expect(await workspace.repository.readAll(), isEmpty);

          powerCut.arm(boundary);
          try {
            await workspace.service.undoHierarchyDeletion(receipt);
          } catch (_) {
            // The injected failure may be recovered by the mutation's own
            // confirmation read, or escape before the caller can confirm it.
          }

          expect(powerCut.captured, isTrue, reason: 'sync boundary $boundary');
          checkpointDirectory = powerCut.checkpointDirectory;
          expect(checkpointDirectory, isNotNull);
          expect(powerCut.copiedHiveFiles, greaterThan(0));

          await Hive.close();
          hiveOpen = false;

          // Reopen the exact post-fsync checkpoint. Never inspect the live
          // directory that the interrupted helper may have further changed.
          workspace = await _openWorkspace(
            checkpointDirectory!,
            _syncDurably,
          );
          hiveOpen = true;
          var restoredParent = await workspace.groupRepository.getGroup(
            parent.id,
          );
          if (restoredParent == null) {
            expect(
              boundary,
              1,
              reason: 'Only the reservation boundary may need Undo retry',
            );
            await workspace.service.undoHierarchyDeletion(receipt);
            restoredParent = await workspace.groupRepository.getGroup(
              parent.id,
            );
          }
          expect(restoredParent, isNotNull, reason: 'sync boundary $boundary');

          final first = await _verifyRestored(
            workspace,
            parentId: parent.id,
            childId: child.id,
            originalRecordIds: {orphanPost.id, related.id},
            parentPosition: initialParent.position,
            childPosition: initialChild.position,
            postCreated: postCreated,
            postUpdated: postUpdated,
            postMembershipDate: postMembershipDate,
            related: related,
            originalPost: orphanPost,
            relatedMembershipDate: relatedMembershipDate,
            reason: 'sync boundary $boundary',
          );
          final firstNextId = (await workspace.repository.reserveIds(1)).single;
          expect(
            firstNextId,
            greaterThan(
              [
                orphanPost.id,
                related.id,
                ...first.records.map((r) => r.id),
              ].reduce((a, b) => a > b ? a : b),
            ),
            reason: 'sync boundary $boundary',
          );

          await Hive.close();
          hiveOpen = false;
          workspace = await _openWorkspace(
            checkpointDirectory,
            _syncDurably,
          );
          hiveOpen = true;
          final second = await _verifyRestored(
            workspace,
            parentId: parent.id,
            childId: child.id,
            originalRecordIds: {orphanPost.id, related.id},
            parentPosition: initialParent.position,
            childPosition: initialChild.position,
            postCreated: postCreated,
            postUpdated: postUpdated,
            postMembershipDate: postMembershipDate,
            related: related,
            originalPost: orphanPost,
            relatedMembershipDate: relatedMembershipDate,
            reason: 'second cold reopen at boundary $boundary',
          );
          expect(
            second.records,
            first.records,
            reason: 'sync boundary $boundary',
          );
          expect(
            second.parent,
            first.parent,
            reason: 'sync boundary $boundary',
          );
          expect(
            second.child,
            first.child,
            reason: 'sync boundary $boundary',
          );
          expect(
            (await workspace.repository.reserveIds(1)).single,
            greaterThan(firstNextId),
            reason: 'sync boundary $boundary',
          );
        } finally {
          if (hiveOpen) await Hive.close();
          if (checkpointDirectory != null && checkpointDirectory.existsSync()) {
            await checkpointDirectory.delete(recursive: true);
          }
          if (fixtureDirectory.existsSync()) {
            await fixtureDirectory.delete(recursive: true);
          }
        }
      }
    },
  );
}

final class _PowerCutCapture {
  _PowerCutCapture(this.sourceDirectory);

  final Directory sourceDirectory;
  int? _targetOrdinal;
  int _ordinal = 0;
  Directory? checkpointDirectory;
  var captured = false;
  var copiedHiveFiles = 0;

  void arm(int ordinal) {
    _targetOrdinal = ordinal;
    _ordinal = 0;
  }

  Future<void> sync(Iterable<BoxBase<dynamic>> boxes) async {
    if (captured) throw StateError('Simulated power cut after checkpoint');
    final syncedDirectories = <String>{};
    const fs = IoFileSystem();
    for (final box in boxes) {
      await box.flush();
      final filePath = box.path!;
      await fs.syncFile(filePath);
      syncedDirectories.add(p.dirname(filePath));
    }
    for (final directoryPath in syncedDirectories) {
      await fs.syncDirectory(directoryPath);
    }

    final target = _targetOrdinal;
    if (target == null) return;
    _ordinal++;
    if (_ordinal != target) return;

    final checkpoint = await Directory.systemTemp.createTemp(
      'bookmark-hierarchy-undo-checkpoint-$target-',
    );
    checkpointDirectory = checkpoint;
    final checkpointDirectories = <String>{checkpoint.path};
    await for (final entity in sourceDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || p.extension(entity.path) != '.hive') continue;
      final relative = p.relative(entity.path, from: sourceDirectory.path);
      final destination = File(p.join(checkpoint.path, relative));
      await destination.parent.create(recursive: true);
      await entity.copy(destination.path);
      copiedHiveFiles++;
      const fs = IoFileSystem();
      await fs.syncFile(destination.path);
      checkpointDirectories.add(destination.parent.path);
    }
    for (final directoryPath in checkpointDirectories) {
      const fs = IoFileSystem();
      await fs.syncDirectory(directoryPath);
    }
    captured = true;
    throw StateError('Simulated power cut after durable sync $_ordinal');
  }
}

Future<_Workspace> _openWorkspace(
  Directory directory,
  Future<void> Function(Iterable<BoxBase<dynamic>>) syncBoxes,
) async {
  Hive.init(directory.path);
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(BookmarkHiveObjectAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
  }
  final posts = await Hive.openBox<BookmarkHiveObject>('posts');
  final payloads = await Hive.openBox<dynamic>('posts_unified_payloads');
  final metadata = await Hive.openBox<dynamic>('posts_unified_metadata');
  await Hive.openBox<BookmarkGroupHiveObject>('groups');
  final legacyOrganization = await Hive.openBox<dynamic>('organization');
  if (!legacyOrganization.containsKey('version')) {
    await legacyOrganization.put('version', 1);
    await legacyOrganization.put('poolBookmarks', []);
  }

  final repository = BookmarkHiveRepository(
    posts,
    groupPayloadBox: payloads,
    metadataBox: metadata,
    coordinator: DataMutationCoordinator(),
    legacyGroupBoxName: 'groups',
    legacyOrganizationBoxName: 'organization',
    syncBoxes: syncBoxes,
  );
  final groupRepository = await repository.openOrganization();
  return _Workspace(
    repository: repository,
    groupRepository: groupRepository,
    service: BookmarkLibraryService(
      bookmarkRepository: repository,
      groupRepository: groupRepository,
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    ),
    metadata: metadata,
  );
}

Future<void> _syncDurably(Iterable<BoxBase<dynamic>> boxes) async {
  const fs = IoFileSystem();
  final directories = <String>{};
  for (final box in boxes) {
    await box.flush();
    final path = box.path!;
    await fs.syncFile(path);
    directories.add(p.dirname(path));
  }
  for (final directory in directories) {
    await fs.syncDirectory(directory);
  }
}

int _activeOrganizationVersion(_Workspace workspace) =>
    (workspace.metadata.get('activeOrganization') as Map)['version'] as int;

RelatedBookmark _relatedBookmark(int id) {
  final reference = const ContentReferenceCodec().parse(
    engine: BooruType.danbooru,
    site: Uri.parse('https://danbooru.donmai.us'),
    kind: ContentKind.group,
    sourceKey: 'related:900',
  );
  final summary = ContentGroupSummary(
    reference: reference,
    title: 'Related Undo fixture',
  );
  return RelatedBookmark(
    id: id,
    snapshot: StoredGroupSnapshot(
      summary: summary,
      details: ContentGroupDetails(
        summary: summary,
        description: const GroupDescription(
          text: 'Retained offline details',
          format: GroupTextFormat.html,
        ),
        tags: GroupTags(
          values: [GroupTag(sourceId: 'undo-tag', name: 'undo fixture')],
          coverage: MetadataCoverage.complete,
        ),
      ),
    ),
    createdAt: DateTime.utc(2020, 1, 2, 3, 4, 5),
    observedAt: DateTime.utc(2024, 5, 6, 7, 8, 9),
    preferredOrder: RelatedPostsOrder.newest,
  );
}

Future<_RestoredSemanticState> _verifyRestored(
  _Workspace workspace, {
  required String parentId,
  required String childId,
  required Set<int> originalRecordIds,
  required int parentPosition,
  required int childPosition,
  required DateTime postCreated,
  required DateTime postUpdated,
  required DateTime postMembershipDate,
  required RelatedBookmark related,
  required PostBookmark originalPost,
  required DateTime relatedMembershipDate,
  required String reason,
}) async {
  final records = await workspace.repository.readAll();
  expect(records, hasLength(2), reason: reason);
  expect(
    workspace.metadata.containsKey('pendingMutation'),
    isFalse,
    reason: reason,
  );
  expect(
    records.map((record) => record.id).toSet().intersection(originalRecordIds),
    isEmpty,
    reason: reason,
  );
  final post = records.whereType<PostBookmark>().single;
  expect(post.postId, isNull, reason: reason);
  expect(post.uniqueId, isA<UnbookmarkablePostIdentity>(), reason: reason);
  expect(post.snapshot, originalPost.snapshot, reason: reason);
  expect(post.originalUrl, originalPost.originalUrl, reason: reason);
  expect(post.sampleUrl, originalPost.sampleUrl, reason: reason);
  expect(post.thumbnailUrl, originalPost.thumbnailUrl, reason: reason);
  expect(post.sourceUrl, originalPost.sourceUrl, reason: reason);
  expect(post.tags, originalPost.tags, reason: reason);
  expect(post.metadata, originalPost.metadata, reason: reason);
  expect(post.booruId, originalPost.booruId, reason: reason);
  expect(post.createdAt, postCreated, reason: reason);
  expect(post.updatedAt, postUpdated, reason: reason);

  final restoredRelated = records.whereType<RelatedBookmark>().single;
  expect(
    restoredRelated.snapshot.details,
    related.snapshot.details,
    reason: reason,
  );
  expect(
    restoredRelated.preferredOrder,
    RelatedPostsOrder.newest,
    reason: reason,
  );
  expect(restoredRelated.createdAt, related.createdAt, reason: reason);
  expect(restoredRelated.observedAt, related.observedAt, reason: reason);

  final parent = (await workspace.groupRepository.getGroup(parentId))!;
  final child = (await workspace.groupRepository.getGroup(childId))!;
  expect(parent.position, parentPosition, reason: reason);
  expect(parent.parentGroupId, isNull, reason: reason);
  expect(child.parentGroupId, parentId, reason: reason);
  expect(child.position, childPosition, reason: reason);
  expect(parent.bookmarkIds, {post.id, restoredRelated.id}, reason: reason);
  expect(parent.addedAt, {
    post.id: postMembershipDate,
    restoredRelated.id: relatedMembershipDate,
  }, reason: reason);
  expect(child.bookmarkIds, isEmpty, reason: reason);
  expect(child.addedAt, isEmpty, reason: reason);

  return _RestoredSemanticState(
    records: records,
    parent: parent,
    child: child,
  );
}

final class _Workspace {
  const _Workspace({
    required this.repository,
    required this.groupRepository,
    required this.service,
    required this.metadata,
  });

  final BookmarkHiveRepository repository;
  final BookmarkGroupRepository groupRepository;
  final BookmarkLibraryService service;
  final Box<dynamic> metadata;
}

final class _RestoredSemanticState {
  const _RestoredSemanticState({
    required this.records,
    required this.parent,
    required this.child,
  });

  final List<Bookmark> records;
  final BookmarkGroup parent;
  final BookmarkGroup child;
}
