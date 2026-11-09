import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_service.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_journal_hash.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/stored_bookmark_codec.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_mutation_repository.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'pool_bookmark_test_utils.dart';

void main() {
  late Directory directory;
  late Box<BookmarkHiveObject> posts;
  late Box<dynamic> groups;
  late Box<dynamic> metadata;
  late _RecordingBox<BookmarkHiveObject> postWrites;
  late _RecordingBox<dynamic> groupWrites;
  late DataMutationCoordinator coordinator;
  late BookmarkHiveRepository repository;

  Future<void> open() async {
    posts = await Hive.openBox<BookmarkHiveObject>('posts');
    groups = await Hive.openBox<dynamic>('payloads');
    metadata = await Hive.openBox<dynamic>('metadata');
    postWrites = _RecordingBox(posts);
    groupWrites = _RecordingBox(groups);
    coordinator = DataMutationCoordinator();
    repository = BookmarkHiveRepository(
      postWrites,
      groupPayloadBox: groupWrites,
      metadataBox: metadata,
      coordinator: coordinator,
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'bookmark-storage-apply-',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    await open();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<List<PostBookmark>> seed(int count) async {
    await posts.putAll({
      for (var id = 0; id < count; id++)
        id: favoriteToHiveObject(testPoolPost(id + 1).copyWith(id: id)),
    });
    return (await repository.readAll()).cast<PostBookmark>();
  }

  ContentGroupBookmark gallery(int id) => ContentGroupBookmark(
    id: id,
    snapshot: StoredGroupSnapshot(
      summary: ContentGroupSummary(
        reference: const ContentReferenceCodec().parse(
          engine: BooruType.danbooru,
          site: Uri.parse('https://example.test'),
          kind: ContentKind.group,
          sourceKey: 'pool:${id + 1}',
        ),
      ),
    ),
    createdAt: DateTime.utc(2020),
    observedAt: DateTime.utc(2026),
  );

  test('replace of 18000 unchanged records writes only organization and advances one observer revision', () async {
    final records = await seed(18000);
    final organization = await repository.openOrganization();
    final before = await repository.readRevision();
    postWrites.batches.clear();
    groupWrites.batches.clear();
    final notifications = <BookmarkCommittedChange>[];
    final originalGroups = await organization.getGroups();
    final data = BookmarkBackupData.unified(
      records: records,
      groups: [
        for (final group in originalGroups)
          BookmarkGroupBackup(
            id: group.id,
            name: group.name,
            bookmarkIds: group.bookmarkIds.toList(),
            addedAt: group.addedAt,
            parentGroupId: group.parentGroupId,
            position: group.position,
          ),
        const BookmarkGroupBackup(
          id: poolGroupA,
          name: 'New empty group',
          bookmarkIds: [],
        ),
      ],
    );
    await observeBookmarkWrites(
      () => BookmarkImportService(
        bookmarkRepository: repository,
        groupRepository: organization,
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      ).replace(data),
      notifications.add,
    );
    expect(postWrites.batches, isEmpty);
    expect(groupWrites.batches, isEmpty);
    expect(notifications, hasLength(1));
    expect(notifications.single.records, isEmpty);
    expect(notifications.single.revision, before + 1);
    expect(await repository.readRevision(), before + 1);
    expect(
      (await organization.getGroup(defaultBookmarkGroupId))!.bookmarkIds,
      records.map((record) => record.id).toSet(),
    );
    expect((await organization.getGroup(poolGroupA))!.name, 'New empty group');
    expect(metadata.containsKey('pendingMutation'), isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('import normalization yields before materialization while reusing each validated record', () async {
    final records = await seed(150);
    final organization = await repository.openOrganization();
    final library = await BookmarkLibraryService(
      bookmarkRepository: repository,
      groupRepository: organization,
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    ).load();
    final counted = _CountingMutationRepository(
      delegate: repository,
      base: library,
    );
    final eventCount = Completer<int>();
    counted.onFirstNormalize = () =>
        Timer.run(() => eventCount.complete(counted.normalizations));
    final data = BookmarkBackupData.unified(
      records: records,
      groups: [
        for (final group in library.groups)
          BookmarkGroupBackup(
            id: group.id,
            name: group.name,
            bookmarkIds: group.bookmarkIds.toList(),
            addedAt: group.addedAt,
            parentGroupId: group.parentGroupId,
            position: group.position,
          ),
      ],
    );
    await BookmarkImportService(
      bookmarkRepository: counted,
      groupRepository: organization,
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    ).replace(data);
    expect(await eventCount.future, 64);
    expect(counted.normalizations, 150);
    expect(postWrites.batches, isEmpty);
    expect(metadata.containsKey('pendingMutation'), isFalse);
  });

  test('unchanged-only upserts do not write, publish or advance revision; duplicate unchanged inputs still reject', () async {
    final records = await seed(2);
    final revision = await repository.readRevision();
    final events = <BookmarkCommittedChange>[];
    await observeBookmarkWrites(
      () => repository.upsertAll(records),
      events.add,
    );
    expect(events, isEmpty);
    expect(postWrites.batches, isEmpty);
    expect(await repository.readRevision(), revision);
    await expectLater(
      repository.upsertAll([records.first, records.first]),
      throwsFormatException,
    );
    await expectLater(
      repository.upsertAll([
        records.first,
        records.first.copyWith(id: records.last.id),
      ]),
      throwsFormatException,
    );
    expect(postWrites.batches, isEmpty);
    expect(await repository.readRevision(), revision);
    expect(metadata.containsKey('pendingMutation'), isFalse);
  });

  test('full wire changes in local dates, source URL, hint and opaque fields are never skipped', () async {
    var record = (await seed(1)).single;
    final variants = <PostBookmark Function(PostBookmark)>[
      (record) => record.copyWith(createdAt: record.createdAt.toLocal()),
      (record) =>
          record.copyWith(updatedAt: DateTime.utc(2030, 1, 1, 0, 0, 0, 0, 1)),
      (record) => record.copyWith(
        sourceUrl: 'https://local.example/retained?key=value',
      ),
      (record) => record.copyWith(
        snapshot: StoredPostSnapshot(
          origin: PostOriginSnapshot(
            booruTypeId: record.snapshot.origin.booruTypeId,
            booruId: record.snapshot.origin.booruId,
            sourceHost: record.snapshot.origin.sourceHost,
            profileIdHint: poolGroupB,
          ),
          common: record.snapshot.common,
          custom: record.snapshot.custom,
          codecVersion: record.snapshot.codecVersion,
        ),
      ),
      for (final value in <num>[1, 1.0, -0.0, 0.0])
        (record) => record.copyWith(
          snapshot: StoredPostSnapshot(
            origin: record.snapshot.origin,
            common: {
              ...record.snapshot.common,
              'unknownCommon': {'number': value},
            },
            custom: {
              ...record.snapshot.custom,
              'opaque': [
                value,
                const {'retained': true},
              ],
            },
            codecVersion: record.snapshot.codecVersion,
          ),
        ),
    ];
    for (final change in variants) {
      final updated = change(record);
      final before = await repository.readRevision();
      final events = <BookmarkCommittedChange>[];
      postWrites.batches.clear();
      await observeBookmarkWrites(() => repository.upsert(updated), events.add);
      expect(postWrites.batches, [1]);
      expect(events.single.records, hasLength(1));
      record = (await repository.read(record.id))! as PostBookmark;
      expect(
        const StoredBookmarkCodec().encode(record),
        const StoredBookmarkCodec().encode(updated),
      );
      expect(await repository.readRevision(), before + 1);
    }
  });

  for (final groupPayload in [false, true]) {
    test(
      'partial ${groupPayload ? 'Group' : 'Post'} batches replay under the same durable journal',
      () async {
        final ids = await repository.reserveIds(150);
        final records = <Bookmark>[
          for (final id in ids)
            groupPayload ? gallery(id) : testPoolPost(id + 1).copyWith(id: id),
        ];
        final writes = groupPayload ? groupWrites : postWrites;
        writes.failAfterBatch = 1;
        final revision = await repository.readRevision();
        await expectLater(repository.upsertAll(records), throwsStateError);
        expect(writes.batches, [64]);
        expect(metadata.containsKey('pendingMutation'), isTrue);
        final pending = Map<String, Object?>.from(
          metadata.get('pendingMutation') as Map,
        );
        expect(pending['version'], 1);
        expect(
          await bookmarkJournalHash(
            Map<String, Object?>.from(pending['plan']! as Map),
          ),
          pending['hash'],
        );
        expect(metadata.get('recordRevision'), revision);
        expect(groupPayload ? groups.length : posts.length, 64);
        await Hive.close();
        await open();
        expect(await repository.readAll(), records);
        expect(await repository.readRevision(), revision + 1);
        expect(metadata.containsKey('pendingMutation'), isFalse);
        expect((groupPayload ? groupWrites : postWrites).batches, [64, 64, 22]);
      },
    );
  }

  test('invalid late row causes no journal, payload or revision effects after earlier valid chunks', () async {
    final ids = await repository.reserveIds(150);
    final records = [
      for (final id in ids) testPoolPost(id + 1).copyWith(id: id),
    ];
    final before = await repository.readRevision();
    final invalid = records.last.copyWith(
      snapshot: StoredPostSnapshot(
        origin: records.last.snapshot.origin,
        common: {...records.last.snapshot.common, 'schemaVersion': 999},
        custom: records.last.snapshot.custom,
        codecVersion: records.last.snapshot.codecVersion,
      ),
    );
    await expectLater(
      repository.upsertAll([...records.take(149), invalid]),
      throwsFormatException,
    );
    expect(postWrites.batches, isEmpty);
    expect(posts, isEmpty);
    expect(metadata.containsKey('pendingMutation'), isFalse);
    expect(await repository.readRevision(), before);
  });

  test('identical non-JSON legacy opaque values still fail before journal admission', () async {
    for (final value in [double.nan, double.infinity, DateTime.utc(2020)]) {
      final source = testPoolPost(1).copyWith(id: 0);
      final record = source.copyWith(
        snapshot: StoredPostSnapshot(
          origin: source.snapshot.origin,
          common: source.snapshot.common,
          custom: {'opaque': value},
          codecVersion: source.snapshot.codecVersion,
        ),
      );
      await posts.put(0, favoriteToHiveObject(record));
      final current = (await repository.readAll()).single;
      final revision = await repository.readRevision();
      await expectLater(
        repository.upsert(current),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(postWrites.batches, isEmpty);
      expect(metadata.containsKey('pendingMutation'), isFalse);
      expect(await repository.readRevision(), revision);
    }
  });

  test(
    'late invalid recovery journal row is rejected before any payload batch',
    () async {
      final ids = await repository.reserveIds(150);
      final records = [
        for (final id in ids) testPoolPost(id + 1).copyWith(id: id),
      ];
      final before = await repository.readRevision();
      final guardedMetadata = _RecordingBox(metadata)
        ..failAfterPutKey = 'pendingMutation';
      repository = BookmarkHiveRepository(
        postWrites,
        groupPayloadBox: groupWrites,
        metadataBox: guardedMetadata,
        coordinator: coordinator,
      );
      await expectLater(repository.upsertAll(records), throwsStateError);
      expect(posts, isEmpty);
      final journal = jsonDecode(
        jsonEncode(metadata.get('pendingMutation')),
      ) as Map<String, dynamic>;
      final plan = journal['plan'] as Map<String, dynamic>;
      final row = (plan['upserts'] as List).last as Map;
      ((row['snapshot'] as Map)['common'] as Map)['schemaVersion'] = 999;
      journal['hash'] = await bookmarkJournalHash(plan);
      await metadata.put('pendingMutation', journal);
      await expectLater(repository.readAll(), throwsFormatException);
      expect(postWrites.batches, isEmpty);
      expect(posts, isEmpty);
      expect(metadata.get('recordRevision'), before);
      expect(metadata.containsKey('pendingMutation'), isTrue);
    },
  );

  test('large validation yields event turns without releasing the coordinator; revoked actor prevents journal write', () async {
    final ids = await repository.reserveIds(150);
    var current = true;
    final observedYield = Completer<void>();
    final foreignRead = Completer<void>();
    final records = [
      for (final id in ids) testPoolPost(id + 1).copyWith(id: id),
    ];
    final admitted = coordinator.runExclusive(() {
      Timer.run(() {
        expect(coordinator.isCurrentOwner, isTrue);
        current = false;
        observedYield.complete();
      });
      return withBookmarkCommitGuard(() => repository.upsertAll(records), () {
        if (!current) throw StateError('Captured actor revoked');
      });
    });
    final queued = coordinator.runExclusive(() async {
      foreignRead.complete();
      expect(metadata.containsKey('pendingMutation'), isFalse);
      expect(posts, isEmpty);
    });
    await observedYield.future;
    expect(foreignRead.isCompleted, isFalse);
    await expectLater(admitted, throwsStateError);
    await queued;
    expect(postWrites.batches, isEmpty);
    expect(metadata.containsKey('pendingMutation'), isFalse);
  });

  test(
    'service captured guard is rechecked after async storage preparation',
    () async {
      final organization = await repository.openOrganization();
      final service = BookmarkLibraryService(
        bookmarkRepository: repository,
        groupRepository: organization,
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      );
      var checks = 0;
      var current = true;
      await expectLater(
        service.createGroup(
          'Actor captured',
          beforeCommit: () {
            if (!current) throw StateError('Captured actor revoked');
            if (++checks == 1) scheduleMicrotask(() => current = false);
          },
        ),
        throwsStateError,
      );
      expect(
        (await organization.getGroups()).where(
          (group) => group.name == 'Actor captured',
        ),
        isEmpty,
      );
      expect(metadata.containsKey('pendingMutation'), isFalse);
      expect(postWrites.batches, isEmpty);
    },
  );

  test('expired captured guard cannot authorize a deferred write', () async {
    final id = (await repository.reserveIds(1)).single;
    final release = Completer<void>();
    late Future<void> deferred;
    await withBookmarkCommitGuard(() async {
      deferred = release.future.then(
        (_) => repository.upsert(testPoolPost(1).copyWith(id: id)),
      );
    }, () {});
    release.complete();
    await expectLater(deferred, throwsStateError);
    expect(posts, isEmpty);
    expect(metadata.containsKey('pendingMutation'), isFalse);
  });

  test('a fresh explicit guard does not inherit an expired callback', () async {
    final id = (await repository.reserveIds(1)).single;
    final release = Completer<void>();
    late Future<void> deferred;
    var expiredChecks = 0;
    var freshChecks = 0;
    await withBookmarkCommitGuard(() async {
      deferred = release.future.then(
        (_) => withBookmarkCommitGuard(
          () => repository.upsert(testPoolPost(1).copyWith(id: id)),
          () => freshChecks++,
        ),
      );
    }, () => expiredChecks++);
    release.complete();
    await deferred;
    expect(expiredChecks, 0);
    expect(freshChecks, 1);
    expect(await repository.read(id), isNotNull);
    expect(metadata.containsKey('pendingMutation'), isFalse);
  });

  test('actor loss after durable admission finishes all batches without reauthorizing recovery', () async {
    final ids = await repository.reserveIds(150);
    var current = true;
    var checks = 0;
    postWrites.afterBatch = () => current = false;
    final records = [
      for (final id in ids) testPoolPost(id + 1).copyWith(id: id),
    ];
    await withBookmarkCommitGuard(() => repository.upsertAll(records), () {
      checks++;
      if (!current) throw StateError('Captured actor revoked');
    });
    expect(checks, 1);
    expect(postWrites.batches, [64, 64, 22]);
    expect(await repository.readAll(), records);
    expect(metadata.containsKey('pendingMutation'), isFalse);
  });

  test('small and large journal digests remain exact with existing ordering and version fields', () async {
    for (final version in [1, 2, 3]) {
      for (final count in [1, 150]) {
        final plan = <String, Object?>{
          'upserts': [
            for (var i = 0; i < count; i++)
              const StoredBookmarkCodec().encode(
                testPoolPost(i + 1).copyWith(id: i),
              ),
          ],
          'deletes': <Object?>[],
          'previous': <String, Object?>{},
          'headers': <String, Object?>{},
          'expectedRevision': 7,
          'targetRevision': 8,
          if (version >= 2) 'organization': {'groups': [], 'retained': 'local'},
          if (version == 3) 'restoredIds': [1, 2],
        };
        expect(
          await bookmarkJournalHash(plan),
          sha256.convert(utf8.encode(jsonEncode(plan))).toString(),
        );
      }
    }
  });
}

/// Every operation still reaches the real Hive box; only putAll batch size and
/// a committed-then-throw boundary are observed here.
class _RecordingBox<T> implements Box<T> {
  _RecordingBox(this.delegate);
  final Box<T> delegate;
  final batches = <int>[];
  int? failAfterBatch;
  String? failAfterPutKey;
  void Function()? afterBatch;
  @override
  Future<void> putAll(Map<dynamic, T> values) async {
    batches.add(values.length);
    await delegate.putAll(values);
    afterBatch?.call();
    if (batches.length == failAfterBatch) {
      failAfterBatch = null;
      throw StateError('Fixture committed partial payload batch');
    }
  }

  @override
  T? get(dynamic key, {T? defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);
  @override
  Iterable<dynamic> get keys => delegate.keys;
  @override
  Iterable<T> get values => delegate.values;
  @override
  bool containsKey(dynamic key) => delegate.containsKey(key);
  @override
  Future<void> put(dynamic key, T value) async {
    await delegate.put(key, value);
    if (key == failAfterPutKey) {
      failAfterPutKey = null;
      throw StateError('Fixture committed journal write');
    }
  }

  @override
  Future<void> delete(dynamic key) => delegate.delete(key);
  @override
  Future<void> deleteAll(Iterable<dynamic> keys) => delegate.deleteAll(keys);
  @override
  Future<void> flush() => delegate.flush();
  @override
  String get name => delegate.name;
  @override
  String? get path => delegate.path;
  @override
  bool get isOpen => delegate.isOpen;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CountingMutationRepository extends BookmarkMutationRepository {
  _CountingMutationRepository({required super.delegate, required super.base});
  var normalizations = 0;
  void Function()? onFirstNormalize;

  @override
  Bookmark normalizeRecord(Bookmark record, {Bookmark? previous}) {
    if (++normalizations == 1) onFirstNormalize?.call();
    return super.normalizeRecord(record, previous: previous);
  }
}
