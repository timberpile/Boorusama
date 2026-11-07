import 'dart:async';
import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_mutation_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/unified_bookmark_store.dart';
import 'package:boorusama/core/content/content_map.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/performance.dart';
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
  late BookmarkHiveRepository repository;
  late UnifiedBookmarkGroupRepository groups;
  late BookmarkLibraryState base;
  late List<Bookmark> records;
  late BookmarkGroup groupA;
  var failPayloadSync = false;
  BookmarkMutationRepository? activeMutation;
  var deltaVisibleBeforeDurableSync = false;
  var finalDurableSyncObserved = false;

  Future<void> sync(Iterable<BoxBase<dynamic>> boxes) async {
    final opened = boxes.toList();
    const fs = IoFileSystem();
    for (final box in opened) {
      await box.flush();
      await fs.syncFile(box.path!);
      await fs.syncDirectory(p.dirname(box.path!));
    }
    if (activeMutation != null) {
      if (activeMutation!.upserts.isNotEmpty ||
          activeMutation!.removedIds.isNotEmpty ||
          activeMutation!.revision != base.revision) {
        deltaVisibleBeforeDurableSync = true;
      }
      if (metadata.get('recordRevision') == base.revision + 1 &&
          !metadata.containsKey('pendingMutation')) {
        finalDurableSyncObserved = true;
      }
    }
    if (failPayloadSync && opened.any((box) => identical(box, payloads))) {
      failPayloadSync = false;
      throw StateError('Fixture payload sync failed after write');
    }
  }

  Future<void> initialize() async {
    directory = await Directory.systemTemp.createTemp(
      'bookmark-mutation-session-',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    posts = await Hive.openBox<BookmarkHiveObject>('posts');
    payloads = await Hive.openBox<dynamic>('payloads');
    metadata = await Hive.openBox<dynamic>('metadata');
    legacyGroups = await Hive.openBox<BookmarkGroupHiveObject>('legacy_groups');
    legacyOrganization = await Hive.openBox<dynamic>('legacy_organization');
    await legacyOrganization.put('version', 1);
    await legacyOrganization.put('poolBookmarks', []);
    repository = BookmarkHiveRepository(
      posts,
      groupPayloadBox: payloads,
      metadataBox: metadata,
      coordinator: DataMutationCoordinator(),
      syncBoxes: sync,
    );
    final reader = await BookmarkStorageMigration(
      bookmarks: repository,
      legacyGroups: legacyGroups,
      legacyOrganization: legacyOrganization,
      metadata: metadata,
    ).open();
    groups = UnifiedBookmarkGroupRepository(
      bookmarks: repository,
      reader: reader,
      now: () => DateTime.utc(2026, 11, 7),
    );
    groupA = await groups.createGroup('A', id: poolGroupA);
    await groups.createGroup('B', id: poolGroupB);

    final post = (await repository.addBookmarkWithBookmarks([
      testPoolPost(7),
    ])).single;
    await groups.addBookmarks(poolGroupA, {post.id});

    final savedGroup = testPool(groups: {poolGroupA})
        .withGroups(
          {poolGroupA},
          addedAt: {poolGroupA: DateTime.utc(2024, 1, 2)},
        )
        .copyWith(sourceSite: () => Uri.parse('https://danbooru.donmai.us'));
    final opaqueWire = testPool(id: 777, groups: {poolGroupA}).toJson();
    opaqueWire['origin'] = {
      ...contentMap(opaqueWire['origin']),
      'booruTypeId': 777,
    };
    final opaque = CollectionBookmark.fromJson(opaqueWire).withGroups(
      {poolGroupA},
      addedAt: {poolGroupA: DateTime.utc(2020, 2, 3)},
    );
    await groups.writePoolBookmarks([savedGroup, opaque]);

    records = await repository.readAll();
    groupA = (await groups.getGroup(poolGroupA))!;
    base = BookmarkLibraryState(
      bookmarks: records.whereType<PostBookmark>().toList(),
      records: records,
      groups: await groups.getGroups(),
      revision: await repository.readRevision(),
    );
  }

  setUp(() async {
    failPayloadSync = false;
    await initialize();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  BookmarkMutationRepository mutation() => BookmarkMutationRepository(
    delegate: repository,
    base: base,
  );

  ContentGroupBookmark nativeGroup() =>
      records.whereType<ContentGroupBookmark>().single;

  LegacyGroupBookmark opaqueGroup() =>
      records.whereType<LegacyGroupBookmark>().single;

  test(
    'canonical fixture includes Post, native Group and opaque legacy Group',
    () {
      expect(base.records, hasLength(3));
      expect(base.records.whereType<PostBookmark>(), hasLength(1));
      expect(base.records.whereType<ContentGroupBookmark>(), hasLength(1));
      expect(base.records.whereType<LegacyGroupBookmark>(), hasLength(1));
      expect(opaqueGroup().identity, isNull);
      expect(base.membershipsByBookmarkId[opaqueGroup().id], {poolGroupA});
    },
  );

  test(
    'core and organization writes publish one durable revision delta',
    () async {
      final writeView = mutation();
      activeMutation = writeView;
      deltaVisibleBeforeDurableSync = false;
      finalDurableSyncObserved = false;
      final updatedPost = (records.whereType<PostBookmark>().single).copyWith(
        updatedAt: DateTime.utc(2026, 11, 7, 1),
      );
      final groupRecord = nativeGroup();
      final updatedGroupRecord = groupRecord.copyWith(
        snapshot: groupRecord.snapshot.withSummary(
          ContentGroupSummary(
            reference: groupRecord.reference,
            title: 'Updated together',
          ),
        ),
      );
      final beforeRevision = base.revision;
      await writeView.commitOrganization(
        records: [updatedPost, updatedGroupRecord],
        groups: [
          groupA.copyWith(
            name: 'A updated',
            bookmarkIds: {...groupA.bookmarkIds, groupRecord.id},
            addedAt: {
              ...groupA.addedAt,
              groupRecord.id: DateTime.utc(2025, 4, 5),
            },
          ),
        ],
      );
      activeMutation = null;
      expect(finalDurableSyncObserved, isTrue);
      expect(deltaVisibleBeforeDurableSync, isFalse);
      expect(await repository.readRevision(), beforeRevision + 1);
      expect(writeView.revision, beforeRevision + 1);
      expect(writeView.upserts.map((record) => record.id).toSet(), {
        updatedPost.id,
        updatedGroupRecord.id,
      });
      expect(writeView.removedIds, isEmpty);
      expect(metadata.containsKey('pendingMutation'), isFalse);
    },
  );

  test('Group-only observed write updates content lookup without decoding all Posts', () async {
    final writeView = mutation();
    final before = nativeGroup();
    final updated = before.copyWith(
      snapshot: before.snapshot.withSummary(
        ContentGroupSummary(reference: before.reference, title: 'Only Group'),
      ),
    );
    final groupCount = base.records.whereType<ContentGroupBookmark>().length;
    performanceRecorder.clear();
    addTearDown(performanceRecorder.clear);
    performanceRecorder.start();
    await writeView.commitOrganization(records: [updated]);
    final found = await writeView.lookupContent(
      before.reference.identity,
      engine: before.reference.engine,
    );
    performanceRecorder.stop();

    expect(found, isA<ContentGroupBookmark>());
    expect((found as ContentGroupBookmark).summary.title, 'Only Group');
    expect(writeView.revision, base.revision + 1);
    expect(groupCount, 1);
    final operations =
        (performanceRecorder.snapshot()['summary'] as Map)['operations']
            as List;
    expect(
      operations.where((item) => (item as Map)['op'] == 'bookmarkDecodeAll'),
      isEmpty,
    );
  });

  test(
    'ambiguous payload sync invalidates delta and reads recovered delegate',
    () async {
      final writeView = mutation();
      final before = nativeGroup();
      final updated = before.copyWith(
        snapshot: before.snapshot.withSummary(
          ContentGroupSummary(reference: before.reference, title: 'Recovered'),
        ),
      );
      failPayloadSync = true;

      await expectLater(
        writeView.commitOrganization(records: [updated]),
        throwsA(isA<StateError>()),
      );
      expect(writeView.isValid, isFalse);
      expect(writeView.revision, base.revision);
      expect(writeView.upserts, isEmpty);

      final recovered = await writeView.read(before.id);
      expect(recovered, isA<ContentGroupBookmark>());
      expect((recovered as ContentGroupBookmark).summary.title, 'Recovered');
      expect(await repository.readRevision(), base.revision + 1);
    },
  );

  test(
    'deferred observer event is ignored after operation invalidation',
    () async {
      final writeView = mutation();
      final before = nativeGroup();
      final deferred = Completer<void>();
      final change = BookmarkCommittedChange(
        records: [
          before.copyWith(
            snapshot: before.snapshot.withSummary(
              ContentGroupSummary(reference: before.reference, title: 'Late'),
            ),
          ),
        ],
        removedIds: const {},
        revision: base.revision + 1,
      );

      observeBookmarkWrites(() {
        scheduleMicrotask(() {
          writeView.invalidate();
          publishBookmarkWrite(change);
          deferred.complete();
        });
      }, writeView.recordCommittedChange);
      await deferred.future;

      expect(writeView.isValid, isFalse);
      expect(writeView.revision, base.revision);
      expect(writeView.upserts, isEmpty);
    },
  );
}
