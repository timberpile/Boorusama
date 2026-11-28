import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:boorusama/core/backups/mitemite/seen_state.dart';
import 'package:boorusama/core/backups/mitemite/service.dart';
import 'package:boorusama/core/backups/mitemite/storage.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;

import 'scalability/fixtures.dart';

const _instrument = bool.fromEnvironment('MITEMITE_BENCHMARK_PROBE');
const _controlOnly = bool.fromEnvironment('MITEMITE_BENCHMARK_CONTROL_ONLY');
const _fs = IoFileSystem();
final _codec = BookmarkBackupCodec();
final _membershipDate = DateTime.utc(2024, 4, 21, 17, 18, 19, 123, 456);

void main() {
  if (!_controlOnly) {
    test('110 groups exchange portable edits', () async {
      final fixture = await _Fixture.open();
      final groups = await fixture.seed([
        ...List.filled(10, 10000),
        ...List.filled(100, 100),
      ]);
      final random = Random(193);
      List<int> draw(BookmarkGroup group, int count) =>
          (group.bookmarkIds.toList()..shuffle(random)).take(count).toList();
      final one = {groups[3].id: draw(groups[3], 1)};
      final concentrated = {groups[5].id: draw(groups[5], 100)};
      final spread = {
        for (final group in groups.take(10)) group.id: draw(group, 10),
      };
      final smallGroups = groups.skip(10).toList()..shuffle(random);
      final fanOut = {
        for (final group in smallGroups.take(50)) group.id: draw(group, 2),
      };
      final cases = [
        ('one_large', one),
        ('concentrated', concentrated),
        ('spread', spread),
        ('small_fan_out', fanOut),
      ];
      final selectionDigest = sha256.convert(
        utf8.encode(
          jsonEncode([
            for (final (name, edits) in cases) [name, edits],
          ]),
        ),
      );
      _emit({
        'fixture': 'mixed',
        'groups': groups.length,
        'posts': 110000,
        'selection_seed': 193,
        'selection_sha256': selectionDigest.toString(),
        'adapter_probe': _instrument,
      });
      await fixture.subscribe(groups);
      final localByKey = fixture.localByKey;
      await fixture.cleanSync();

      for (final (i, (name, edits)) in cases.indexed) {
        final sourceDate = DateTime.utc(2025, 1, i + 1);
        final edited = [
          for (final id in edits.values.expand((ids) => ids))
            scalabilityBookmark(id, upstreamId: id + 1, uploadedAt: sourceDate),
        ];
        final buckets = <(String, int)>{};
        for (final entry in edits.entries) {
          final group = groups.singleWhere((group) => group.id == entry.key);
          for (final id in entry.value) {
            final key = syncBookmarkMemberKey(
              scalabilityBookmark(id, upstreamId: id + 1),
            );
            final bucket = group.bookmarkIds.length == 100
                ? 0
                : sha256.convert(utf8.encode(key)).bytes.first >> 2;
            buckets.add((entry.key, bucket));
          }
        }
        final before = await fixture.revisions();
        await fixture.measure(
          name,
          'local_commit',
          fixture.sender,
          () => fixture.sender.repository.upsertAll(edited),
          edits: edited.length,
          touchedGroups: edits.length,
          expectedBuckets: buckets.length,
        );
        await fixture.measure(
          name,
          'publish',
          fixture.sender,
          () => fixture.sender.service.synchronize(
            trigger: SyncTrigger.localChange,
          ),
          edits: edited.length,
          touchedGroups: edits.length,
          expectedBuckets: buckets.length,
        );
        await fixture.measure(
          name,
          'receive',
          fixture.receiver,
          fixture.receiver.service.synchronize,
          edits: edited.length,
          touchedGroups: edits.length,
          expectedBuckets: buckets.length,
        );
        await fixture.expectChanged(before, edits.keys.toSet());
        for (final record in edited) {
          final key = syncBookmarkMemberKey(record);
          final id = localByKey[key];
          expect(id, isNotNull, reason: key);
          final received =
              (await fixture.receiver.repository.read(id!))! as PostBookmark;
          expect(syncBookmarkMemberKey(received), key);
          expect(received.post.createdAt, sourceDate, reason: key);
        }
        await fixture.expectMemberships(groups);
      }
    }, timeout: const Timeout(Duration(minutes: 45)));
  }

  test('membership removal preserves the receiver Favorites copy', () async {
    final fixture = await _Fixture.open();
    final groups = await fixture.seed([4000]);
    final root = groups.single;
    final removed = root.bookmarkIds.first;
    final favoriteId = (await fixture.receiver.repository.reserveIds(1)).single;
    final favorite = BookmarkGroup(
      id: _groupId(1000),
      name: 'Favorites',
      bookmarkIds: {favoriteId},
      addedAt: {favoriteId: _membershipDate},
    );
    await fixture.receiver.repository.commitOrganization(
      records: [scalabilityBookmark(favoriteId, upstreamId: removed + 1)],
      groups: [favorite],
    );
    _emit({
      'fixture': 'removal',
      'groups': 1,
      'posts': 4000,
      'adapter_probe': _instrument,
    });
    await fixture.subscribe(groups);
    final prior = await fixture.revisions();
    final survivors = root.copyWith(
      bookmarkIds: root.bookmarkIds.difference({removed}),
    );
    await fixture.measure(
      'removal',
      'local_commit',
      fixture.sender,
      () => fixture.sender.repository.commitOrganization(groups: [survivors]),
      edits: 1,
      touchedGroups: 1,
      expectedBuckets: 1,
    );
    await fixture.measure(
      'removal',
      'publish',
      fixture.sender,
      () =>
          fixture.sender.service.synchronize(trigger: SyncTrigger.localChange),
      edits: 1,
      touchedGroups: 1,
      expectedBuckets: 1,
    );
    await fixture.measure(
      'removal',
      'receive',
      fixture.receiver,
      fixture.receiver.service.synchronize,
      edits: 1,
      touchedGroups: 1,
      expectedBuckets: 1,
    );
    await fixture.expectChanged(prior, {root.id});
    await fixture.expectMemberships([survivors]);
    final peerGroups = await fixture.receiver.groups.getGroups();
    final current = peerGroups.singleWhere((group) => group.id == favorite.id);
    expect(current.bookmarkIds, {favoriteId});
    expect(current.addedAt, favorite.addedAt);
    expect(await fixture.receiver.repository.read(favoriteId), isNotNull);
    await fixture.cleanSync();
  }, timeout: const Timeout(Duration(minutes: 10)));
}

String _groupId(int i) =>
    'd1930000-0000-4000-8000-${i.toRadixString(16).padLeft(12, '0')}';

void _emit(Map<String, Object?> fields) =>
    stdout.writeln('MITEMITE_BENCHMARK ${jsonEncode(fields)}');

final class _Fixture {
  _Fixture(this.shared, this.sender, this.receiver);

  final Directory shared;
  final _Device sender;
  final _Device receiver;
  final localByKey = <String, int>{};
  final _localBySourceId = <int, int>{};

  static Future<_Fixture> open() async {
    final root = await Directory.systemTemp.createTemp(
      'mitemite_group_benchmark_',
    );
    Hive.init(p.join(root.path, 'hive'));
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    addTearDown(() async {
      await Hive.close();
      await root.delete(recursive: true);
    });
    final shared = await Directory(p.join(root.path, 'shared')).create();
    return _Fixture(
      shared,
      await _Device.open('sender', shared.path),
      await _Device.open('receiver', shared.path),
    );
  }

  Future<List<BookmarkGroup>> seed(List<int> cardinalities) async {
    final seeded = <BookmarkGroup>[];
    for (final (index, count) in cardinalities.indexed) {
      final ids = await sender.repository.reserveIds(count);
      final group = BookmarkGroup(
        id: _groupId(index),
        name: 'Group $index',
        bookmarkIds: ids.toSet(),
        addedAt: {for (final id in ids) id: _membershipDate},
        position: index,
        parentGroupId: index == 0 ? null : _groupId(0),
      );
      await sender.repository.commitOrganization(
        records: [
          for (final id in ids) scalabilityBookmark(id, upstreamId: id + 1),
        ],
        groups: [group],
      );
      seeded.add(group);
    }
    return seeded;
  }

  Future<void> subscribe(List<BookmarkGroup> groups) async {
    await sender.service.configure(
      shared.path,
      deviceName: 'Benchmark publisher',
    );
    await measure(
      'initial',
      'publish',
      sender,
      () => sender.service.publishRoots({groups.first.id}),
      touchedGroups: groups.length,
    );
    await receiver.service.configure(
      shared.path,
      deviceName: 'Benchmark subscriber',
    );
    final publisher = receiver.service.devices.singleWhere(
      (device) => device.id == sender.service.identity.id,
    );
    await receiver.service.approve(publisher);
    await measure(
      'initial',
      'receive',
      receiver,
      () => receiver.service.subscribe(publisher.id, {groups.first.id}),
      touchedGroups: groups.length,
    );
    await receiver.repository.visitTransferRecords((row) async {
      final post = row as PostBookmark;
      localByKey[syncBookmarkMemberKey(post)] = post.id;
      _localBySourceId[post.post.id - 1] = post.id;
    });
    await expectMemberships(groups);
  }

  Future<void> cleanSync() async {
    final epoch = (await receiver.repository.readMirrorState()).epoch;
    await measure(
      'clean',
      'resume',
      sender,
      () => sender.service.synchronize(trigger: SyncTrigger.resume),
    );
    await measure(
      'clean',
      'poll',
      receiver,
      () => receiver.service.synchronize(trigger: SyncTrigger.poll),
    );
    expect((await receiver.repository.readMirrorState()).epoch, epoch);
  }

  Future<Map<String, int>> revisions() async => {
    for (final owner
        in (await receiver.repository.readMirrorState()).owners.values)
      owner.source: owner.revision,
  };

  Future<void> expectChanged(
    Map<String, int> before,
    Set<String> changed,
  ) async {
    final after = await revisions();
    expect(after.keys.toSet(), before.keys.toSet());
    expect({
      for (final id in after.keys)
        if (after[id] != before[id]) id,
    }, changed);
    expect(changed.every((id) => after[id]! > before[id]!), isTrue);
  }

  Future<void> expectMemberships(List<BookmarkGroup> groups) async {
    final state = await receiver.repository.readMirrorState();
    expect(state.owners, hasLength(groups.length));
    final current = {
      for (final group in await receiver.groups.getGroups()) group.id: group,
    };
    for (final group in groups) {
      final id = state.localIdFor(sender.service.identity.id, group.id);
      expect(id, isNotNull, reason: group.name);
      final mirror = current[id]!;
      expect(
        mirror.bookmarkIds,
        {for (final id in group.bookmarkIds) _localBySourceId[id]!},
        reason: group.name,
      );
      expect(
        mirror.addedAt.keys.toSet(),
        mirror.bookmarkIds,
        reason: group.name,
      );
      expect(mirror.addedAt.values.toSet(), {
        _membershipDate,
      }, reason: group.name);
      final parent = group.parentGroupId;
      expect(
        mirror.parentGroupId,
        parent == null
            ? null
            : state.localIdFor(sender.service.identity.id, parent),
      );
    }
  }

  Future<Map<String, int>> inventory() async => {
    await for (final entry in shared.list(recursive: true, followLinks: false))
      if (entry is File)
        p.relative(entry.path, from: shared.path): await entry.length(),
  };

  Future<void> measure(
    String scenario,
    String phase,
    _Device device,
    Future<void> Function() operation, {
    int edits = 0,
    int touchedGroups = 0,
    int expectedBuckets = 0,
  }) async {
    final before = await inventory();
    device.operations.clear();
    device.repository.reads = 0;
    device.projections = 0;
    final watch = Stopwatch()..start();
    await operation();
    watch.stop();
    final service = device.service;
    expect(service.failure, isNull, reason: '$scenario $phase service failure');
    expect(
      service.outgoingFailure,
      isNull,
      reason: '$scenario $phase publication failure',
    );
    expect(
      service.deviceFailures,
      isEmpty,
      reason: '$scenario $phase peer failure',
    );
    expect(
      service.reloadFailure,
      isNull,
      reason: '$scenario $phase projection failure',
    );
    final after = await inventory();
    final added = after.keys
        .where((path) => !before.containsKey(path))
        .toList();
    _emit({
      'scenario': scenario,
      'phase': phase,
      'elapsed_us': watch.elapsedMicroseconds,
      'record_edits': edits,
      'touched_groups': touchedGroups,
      'fixture_distinct_buckets': expectedBuckets,
      'new_files': added.length,
      'new_shared_bytes': added.fold<int>(
        0,
        (total, path) => total + after[path]!,
      ),
      'new_chunk_files': added
          .where((path) => path.contains('/chunks/'))
          .length,
      'projection_callbacks': device.projections,
      if (_instrument) 'repository_point_reads': device.repository.reads,
      if (_instrument) 'adapter_calls': Map.of(device.operations),
    });
  }
}

final class _Device {
  _Device(this.repository, this.groups);
  final _ReadCountingRepository repository;
  final BookmarkGroupRepository groups;
  final operations = <String, int>{};
  late final MiteMiteService service;
  var projections = 0;

  static Future<_Device> open(String name, String path) async {
    final repository = _ReadCountingRepository(
      await Hive.openBox<BookmarkHiveObject>('${name}_posts'),
      groupPayloadBox: await Hive.openBox<dynamic>('${name}_payloads'),
      metadataBox: await Hive.openBox<dynamic>('${name}_metadata'),
      legacyGroupBoxName: '${name}_legacy_groups',
      legacyOrganizationBoxName: '${name}_legacy_folders',
      coordinator: DataMutationCoordinator(),
    );
    final device = _Device(repository, await repository.openOrganization());
    final storage = DirectoryMiteMiteStorage(path);
    device.service = MiteMiteService(
      preferences: _Preferences(),
      store: repository,
      groups: device.groups,
      identity: await SyncSigningIdentity.create(),
      fs: _fs,
      codec: _codec,
      mutations: repository.coordinator,
      storageFor: (_) async =>
          _instrument ? _Probe(storage, device.operations) : storage,
      onApplied: () async => device.projections++,
    );
    addTearDown(device.service.dispose);
    return device;
  }
}

final class _Preferences implements MiscDataStore {
  final _values = <String, String>{};
  @override
  String? get(String key) => _values[key];
  @override
  Future<void> put(String key, String value) async => _values[key] = value;
}

final class _ReadCountingRepository extends BookmarkHiveRepository {
  _ReadCountingRepository(
    super.posts, {
    required super.groupPayloadBox,
    required super.metadataBox,
    required super.legacyGroupBoxName,
    required super.legacyOrganizationBoxName,
    required super.coordinator,
  });

  var reads = 0;
  @override
  Future<Bookmark?> read(int id) {
    if (_instrument) reads++;
    return super.read(id);
  }
}

final class _Probe implements MiteMitePayloadStorage {
  const _Probe(this.storage, this.calls);
  final DirectoryMiteMiteStorage storage;
  final Map<String, int> calls;

  void _count(String operation, String path) {
    final type = path.contains('/catalog/')
        ? 'catalog'
        : path.contains('/manifests/')
        ? 'manifest'
        : path.endsWith('.bsexport') || path.contains('/chunks/')
        ? 'payload'
        : 'other';
    calls.update('$operation.$type', (value) => value + 1, ifAbsent: () => 1);
  }

  @override
  Future<List<String>> list(String path) {
    _count('list', path);
    return storage.list(path);
  }

  @override
  Future<Uint8List?> read(String path, {int maxBytes = miteMiteMaxBytes}) {
    _count('read', path);
    return storage.read(path, maxBytes: maxBytes);
  }

  @override
  Future<void> writeImmutable(String path, Uint8List bytes) {
    _count('write', path);
    return storage.writeImmutable(path, bytes);
  }

  @override
  Future<bool> copyPayload(
    String path, {
    String? destination,
    required int length,
    required String sha256,
  }) {
    _count(destination == null ? 'verify' : 'copy', path);
    return storage.copyPayload(
      path,
      destination: destination,
      length: length,
      sha256: sha256,
    );
  }

  @override
  Future<void> writePayload(
    String path, {
    required String sourcePath,
    required int length,
    required String sha256,
  }) {
    _count('write', path);
    return storage.writePayload(
      path,
      sourcePath: sourcePath,
      length: length,
      sha256: sha256,
    );
  }

  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) {
    _count('delete', path);
    return storage.deleteOwnedRevision(path, owner: owner);
  }

  @override
  Future<void> deleteOwnedDirectory(String path, {required String owner}) {
    _count('delete', path);
    return storage.deleteOwnedDirectory(path, owner: owner);
  }
}
