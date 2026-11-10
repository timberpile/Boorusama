import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/content_map.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
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
  late Box<BookmarkGroupHiveObject> activeGroups;
  String? failAfter;
  int? interruptedId;
  var deletionMode = false;

  Future<void> sync(Iterable<BoxBase<dynamic>> boxes) async {
    final list = boxes.toList();
    const fs = IoFileSystem();
    for (final box in list) {
      await box.flush();
      await fs.syncFile(box.path!);
      await fs.syncDirectory(p.dirname(box.path!));
    }
    if (failAfter == null) return;
    final phase = switch (true) {
      _
          when list.any((box) => identical(box, payloads)) ||
              list.any((box) => identical(box, posts)) ||
              list.any((box) => identical(box, activeGroups)) =>
        'payload',
      _
          when metadata.containsKey('pendingMutation') &&
              (deletionMode
                  ? contentMap(metadata.get('record:$interruptedId'))['kind'] !=
                        'deleted'
                  : metadata.get('record:$interruptedId') == null) =>
        'journal',
      _ when metadata.containsKey('pendingMutation') => 'index',
      _ => 'cleanup',
    };
    if (failAfter == phase) {
      failAfter = null;
      throw StateError('Fixture committed $phase failure');
    }
  }

  Future<void> openBoxes() async {
    posts = await Hive.openBox<BookmarkHiveObject>('posts');
    payloads = await Hive.openBox<dynamic>('posts_unified_payloads');
    metadata = await Hive.openBox<dynamic>('posts_unified_metadata');
    legacyGroups = await Hive.openBox<BookmarkGroupHiveObject>('groups');
    legacyOrganization = await Hive.openBox<dynamic>('organization');
    repository = BookmarkHiveRepository(
      posts,
      groupPayloadBox: payloads,
      metadataBox: metadata,
      coordinator: DataMutationCoordinator(),
      syncBoxes: sync,
    );
  }

  Future<void> initializeActiveGeneration() async {
    directory = await Directory.systemTemp.createTemp('unified-organization-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    failAfter = null;
    interruptedId = null;
    deletionMode = false;
    await openBoxes();
    await posts.put(0, favoriteToHiveObject(testPoolPost(7).copyWith(id: 0)));
    final sourceGroup = DateTime.utc(2024, 2, 3, 4, 5);
    await legacyGroups.put(
      poolGroupA,
      BookmarkGroupHiveObject(
        id: poolGroupA,
        name: 'A',
        bookmarkIds: [0],
        addedAt: {0: sourceGroup.toIso8601String()},
      ),
    );
    await legacyOrganization.put('version', 1);
    await (BookmarkStorageMigration(
      bookmarks: repository,
      legacyGroups: legacyGroups,
      legacyOrganization: legacyOrganization,
      metadata: metadata,
    )).open();
    final active = contentMap(metadata.get(BookmarkStorageMigration.activeKey));
    final generation = contentMap(active['generation']);
    activeGroups = await Hive.openBox<BookmarkGroupHiveObject>(
      generation['groups']! as String,
    );
    await Hive.openBox<dynamic>(generation['organization']! as String);
  }

  Future<void> restart() async {
    await Hive.close();
    Hive.init(directory.path);
    await openBoxes();
    final active = contentMap(metadata.get(BookmarkStorageMigration.activeKey));
    final generation = contentMap(active['generation']);
    activeGroups = await Hive.openBox<BookmarkGroupHiveObject>(
      generation['groups']! as String,
    );
    await Hive.openBox<dynamic>(generation['organization']! as String);
    await (BookmarkStorageMigration(
      bookmarks: repository,
      legacyGroups: legacyGroups,
      legacyOrganization: legacyOrganization,
      metadata: metadata,
    )).open();
  }

  setUp(initializeActiveGeneration);
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  LegacyGroupBookmark legacyRecord(int id) => LegacyGroupBookmark.fromMetadata(
    id: id,
    metadata: testPool(groups: {}),
  );

  BookmarkGroup updatedGroup(BookmarkGroup current, int id, DateTime date) =>
      current.copyWith(
        bookmarkIds: {...current.bookmarkIds, id},
        addedAt: {...current.addedAt, id: date},
      );

  ContentGroupBookmark nativeGroup(int id) {
    final reference = const ContentReferenceCodec().parse(
      engine: BooruType.danbooru,
      site: Uri.parse('https://danbooru.donmai.us/install'),
      kind: ContentKind.group,
      sourceKey: 'pool:42',
    );
    return ContentGroupBookmark(
      id: id,
      snapshot: StoredGroupSnapshot(
        summary: ContentGroupSummary(reference: reference, title: 'Pool 42'),
      ),
      createdAt: DateTime.utc(2020, 1, 2),
      observedAt: DateTime.utc(2025, 3, 4),
    );
  }

  Future<
    ({
      int targetId,
      int retainedId,
      DateTime targetDateA,
      DateTime targetDateB,
      DateTime retainedDateA,
      DateTime retainedDateB,
    })
  >
  prepareDirectDelete({required bool deleteGroupRecord}) async {
    final reader = await BookmarkStorageMigration(
      bookmarks: repository,
      legacyGroups: legacyGroups,
      legacyOrganization: legacyOrganization,
      metadata: metadata,
    ).open();
    final groupA = (await reader.getGroup(poolGroupA))!;
    final nextPosition = (await reader.getGroups())
        .where((group) => group.folderId == null)
        .fold(
          0,
          (next, group) => group.position >= next ? group.position + 1 : next,
        );
    final groupDateA = DateTime.utc(2024, 4, 5, 6, 7, 8);
    final groupDateB = DateTime.utc(2025, 6, 7, 8, 9, 10);
    final postDateB = DateTime.utc(2025, 1, 2, 3, 4, 5);
    final groupId = (await repository.reserveIds(1)).single;
    final savedGroup = nativeGroup(groupId);
    final (
      targetId,
      retainedId,
      targetDateA,
      targetDateB,
      retainedDateA,
      retainedDateB,
    ) = deleteGroupRecord
        ? (
            groupId,
            0,
            groupDateA,
            groupDateB,
            groupA.addedAt[0]!,
            postDateB,
          )
        : (
            0,
            groupId,
            groupA.addedAt[0]!,
            postDateB,
            groupDateA,
            groupDateB,
          );
    await repository.commitOrganization(
      records: [savedGroup],
      groups: [
        updatedGroup(groupA, groupId, groupDateA),
        BookmarkGroup(
          id: poolGroupB,
          name: 'B',
          position: nextPosition,
          bookmarkIds: {0, groupId},
          addedAt: {0: postDateB, groupId: groupDateB},
        ),
      ],
    );
    return (
      targetId: targetId,
      retainedId: retainedId,
      targetDateA: targetDateA,
      targetDateB: targetDateB,
      retainedDateA: retainedDateA,
      retainedDateB: retainedDateB,
    );
  }

  test('organization commit recovers its record and dated membership at every sync boundary', () async {
    const boundaries = ['journal', 'payload', 'index', 'cleanup'];
    for (final boundary in boundaries) {
      final group = (await (await BookmarkStorageMigration(
        bookmarks: repository,
        legacyGroups: legacyGroups,
        legacyOrganization: legacyOrganization,
        metadata: metadata,
      ).open()).getGroup(poolGroupA))!;
      final id = (await repository.reserveIds(1)).single;
      final date = DateTime.utc(2026, 7, 8, 9, 10, 11, 123, 456);
      interruptedId = id;
      failAfter = boundary;
      await expectLater(
        repository.commitOrganization(
          records: [legacyRecord(id)],
          groups: [updatedGroup(group, id, date)],
        ),
        throwsA(isA<StateError>()),
      );
      await restart();

      final records = await repository.readAll();
      final saved = records.whereType<LegacyGroupBookmark>().single;
      expect(saved.id, id, reason: boundary);
      expect(
        saved.metadata.origin,
        testPool(groups: {}).origin,
        reason: boundary,
      );
      expect(saved.metadata.groupIds, isEmpty, reason: boundary);
      expect(saved.metadata.addedAt, isEmpty, reason: boundary);
      expect(records.whereType<PostBookmark>().single.id, 0, reason: boundary);
      final recoveredGroup = activeGroups.get(poolGroupA)!;
      expect(recoveredGroup.bookmarkIds, {0, id}, reason: boundary);
      expect(
        DateTime.parse(recoveredGroup.addedAt![id] as String),
        date,
        reason: boundary,
      );
      expect(
        activeGroups.get(poolGroupA)!.bookmarkIds.where((value) => value == id),
        [id],
      );
      expect(
        metadata.containsKey('pendingMutation'),
        isFalse,
        reason: boundary,
      );
      expect(payloads.containsKey(id), isTrue, reason: boundary);
      expect(legacyGroups.get(poolGroupA)!.bookmarkIds, [0], reason: boundary);
      expect(legacyOrganization.toMap(), {'version': 1}, reason: boundary);

      if (boundary != boundaries.last) {
        await Hive.close();
        await directory.delete(recursive: true);
        await initializeActiveGeneration();
      }
    }
  });

  test(
    'combined removal leaves no group payload or membership behind',
    () async {
      final original = (await (await BookmarkStorageMigration(
        bookmarks: repository,
        legacyGroups: legacyGroups,
        legacyOrganization: legacyOrganization,
        metadata: metadata,
      ).open()).getGroup(poolGroupA))!;
      final id = (await repository.reserveIds(1)).single;
      final date = DateTime.utc(2026, 1, 2);
      final savedGroup = updatedGroup(original, id, date);
      await repository.commitOrganization(
        records: [legacyRecord(id)],
        groups: [savedGroup],
      );
      await repository.commitOrganization(
        removeIds: {id},
        groups: [
          savedGroup.copyWith(
            bookmarkIds: {0},
            addedAt: {0: original.addedAt[0]!},
          ),
        ],
      );

      expect(await repository.read(id), isNull);
      expect(await repository.readAll(), hasLength(1));
      expect(payloads.containsKey(id), isFalse);
      expect(activeGroups.get(poolGroupA)!.bookmarkIds, {0});
      expect(
        activeGroups.get(poolGroupA)!.addedAt!.keys.toSet(),
        {0},
      );
      expect(metadata.get('record:$id'), {'kind': 'deleted'});
      expect(metadata.containsKey('pendingMutation'), isFalse);
    },
  );

  test(
    'direct Group and Post deletions recover memberships at every sync boundary',
    () async {
      const boundaries = ['journal', 'payload', 'index', 'cleanup'];
      final scenarios = [
        for (final deleteGroupRecord in [true, false])
          for (final boundary in boundaries)
            (deleteGroupRecord: deleteGroupRecord, boundary: boundary),
      ];
      for (final (index, scenario) in scenarios.indexed) {
        final fixture = await prepareDirectDelete(
          deleteGroupRecord: scenario.deleteGroupRecord,
        );
        expect(
          DateTime.parse(
            activeGroups.get(poolGroupA)!.addedAt![fixture.targetId] as String,
          ),
          fixture.targetDateA,
        );
        expect(
          DateTime.parse(
            activeGroups.get(poolGroupB)!.addedAt![fixture.targetId] as String,
          ),
          fixture.targetDateB,
        );
        interruptedId = fixture.targetId;
        deletionMode = true;
        failAfter = scenario.boundary;
        final deletion = scenario.deleteGroupRecord
            ? repository.delete(fixture.targetId)
            : repository.removeBookmark(
                (await repository.read(fixture.targetId))! as PostBookmark,
              );
        await expectLater(
          deletion,
          throwsA(isA<StateError>()),
          reason:
              '${scenario.deleteGroupRecord ? 'Group' : 'Post'} ${scenario.boundary}',
        );

        await restart();
        expect(await repository.read(fixture.targetId), isNull);
        expect(
          metadata.get('record:${fixture.targetId}'),
          {'kind': 'deleted'},
          reason:
              '${scenario.deleteGroupRecord ? 'Group' : 'Post'} ${scenario.boundary}',
        );
        expect(metadata.containsKey('pendingMutation'), isFalse);
        expect(payloads.containsKey(fixture.targetId), isFalse);
        expect(posts.containsKey(fixture.targetId), isFalse);
        expect(activeGroups.get(poolGroupA)!.bookmarkIds, {fixture.retainedId});
        expect(activeGroups.get(poolGroupB)!.bookmarkIds, {fixture.retainedId});
        expect(
          DateTime.parse(
            activeGroups.get(poolGroupA)!.addedAt![fixture.retainedId]
                as String,
          ),
          fixture.retainedDateA,
        );
        expect(
          DateTime.parse(
            activeGroups.get(poolGroupB)!.addedAt![fixture.retainedId]
                as String,
          ),
          fixture.retainedDateB,
        );
        expect(
          activeGroups.get(poolGroupA)!.addedAt!.containsKey(fixture.targetId),
          isFalse,
        );
        expect(
          activeGroups.get(poolGroupB)!.addedAt!.containsKey(fixture.targetId),
          isFalse,
        );
        expect(legacyGroups.get(poolGroupA)!.bookmarkIds, [0]);
        expect(legacyOrganization.toMap(), {'version': 1});

        final bound =
            contentMap(
                  metadata.get('idReservation'),
                )['nextId']!
                as int;
        final nextId = (await repository.reserveIds(1)).single;
        expect(nextId, greaterThan(fixture.targetId));
        expect(nextId, greaterThanOrEqualTo(bound));

        if (index < scenarios.length - 1) {
          await Hive.close();
          await directory.delete(recursive: true);
          await initializeActiveGeneration();
        }
      }
    },
  );

  test(
    'invalid membership and default group deletion fail before writes',
    () async {
      final beforeGroups = activeGroups.toMap();
      final revision = metadata.get('recordRevision');
      final current = (await (await BookmarkStorageMigration(
        bookmarks: repository,
        legacyGroups: legacyGroups,
        legacyOrganization: legacyOrganization,
        metadata: metadata,
      ).open()).getGroup(poolGroupA))!;
      await expectLater(
        repository.commitOrganization(
          groups: [
            current.copyWith(
              bookmarkIds: {...current.bookmarkIds, 999},
              addedAt: {...current.addedAt, 999: DateTime.utc(2026)},
            ),
          ],
        ),
        throwsFormatException,
      );
      await expectLater(
        repository.commitOrganization(removeGroupIds: {defaultBookmarkGroupId}),
        throwsFormatException,
      );
      expect(activeGroups.toMap(), beforeGroups);
      expect(metadata.get('recordRevision'), revision);
      expect(metadata.containsKey('pendingMutation'), isFalse);
      expect(payloads, isEmpty);
    },
  );
}
