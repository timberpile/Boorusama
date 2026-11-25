import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/backups/mitemite/bookmark_mirror_engine.dart';
import 'package:boorusama/core/backups/mitemite/catalog.dart';
import 'package:boorusama/core/backups/mitemite/following_package.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:boorusama/core/backups/mitemite/publication.dart';
import 'package:boorusama/core/backups/mitemite/retention.dart';
import 'package:boorusama/core/backups/mitemite/revision_transport.dart';
import 'package:boorusama/core/backups/mitemite/storage.dart';
import 'package:boorusama/core/backups/sources/following_topic_backup_data.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';

const source = '11111111-1111-4111-8111-111111111111';
const other = '22222222-2222-4222-8222-222222222222';
const foreign = '33333333-3333-4333-8333-333333333333';

void main() {
  late Directory directory;
  late DirectoryMiteMiteStorage storage;
  late SyncSigningIdentity identity;
  late SyncPublicationWriter writer;
  late _Store preferences;
  late List<SyncRevision> revisions;
  late List<SyncCatalog> catalogs;
  Future<SyncRevision> publish(int number) async =>
      writer.publishFollowingRevision(
        await const SyncFollowingPackageBuilder(fs: IoFileSystem()).build(
          collection: SyncCollectionId(
            publisher: identity.id,
            kind: 'following_topics',
            source: source,
          ),
          data: FollowingTopicBackupData(
            records: const [],
            folders: [
              FollowingTopicFolderBackupRecord(
                id: source,
                name: 'Folder $number',
                position: 0,
                searchIds: const [],
                feedEnabled: true,
              ),
            ],
          ),
          appVersion: 'test',
          createdAt: DateTime.utc(2026),
        ),
      );
  SyncOwnedRetention pruner({int budget = 128, MiteMiteStorage? adapter}) =>
      SyncOwnedRetention(
        storage: adapter ?? storage,
        identity: identity,
        preferences: preferences,
        maxDeletes: budget,
      );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('owned_retention_');
    storage = DirectoryMiteMiteStorage(directory.path);
    identity = await SyncSigningIdentity.create();
    preferences = _Store();
    writer = SyncPublicationWriter(
      identity: identity,
      storage: storage,
      sequences: SyncPublicationSequences(
        store: preferences,
        mutations: DataMutationCoordinator(),
      ),
    );
    revisions = [];
    catalogs = [];
    for (var number = 1; number <= 6; number++) {
      final revision = await publish(number);
      revisions.add(revision);
      catalogs.add(
        await writer.publishCatalog(
          name: 'Publisher',
          publicationRoots: {revision.collection},
          entries: [
            SyncCatalogEntry(
              id: revision.collection,
              name: 'Folder $number',
              state: SyncPublicationState.active,
              revision: revision,
            ),
          ],
        ),
      );
    }
  });
  tearDown(() => Future.sync(() => directory.delete(recursive: true)));

  test('keeps two complete catalogs and referenced revisions while preserving identities and foreign/unknown files', () async {
    final ownIdentity = (await storage.read(
      'devices/${identity.id}/identity.json',
    ))!;
    const foreignPath =
        'devices/$foreign/collections/following_topics/$source/1.json';
    final unknownPath =
        'devices/${identity.id}/collections/following_topics/$other/1.json';
    final marker = Uint8List.fromList([7, 8, 9]);
    await storage.writeImmutable(foreignPath, marker);
    await storage.writeImmutable(unknownPath, marker);
    final result = await pruner().prune(catalogs.last);
    expect(result.deletedFiles, 12);
    expect(result.hasMore, isFalse);
    for (final revision in revisions.take(4)) {
      expect(await storage.read(revision.payloadPath), isNull);
      expect(await storage.read(revision.descriptorPath), isNull);
    }
    for (final revision in revisions.skip(4)) {
      expect(
        await SyncRevisionTransport(storage)
            .read(expected: revision, publisherKey: identity.publicKey),
        isNotNull,
      );
    }
    expect(await storage.read(catalogs[4].path), isNotNull);
    expect(await storage.read(catalogs[5].path), isNotNull);
    expect(
      await storage.read('devices/${identity.id}/identity.json'),
      ownIdentity,
    );
    expect(await storage.read(foreignPath), marker);
    expect(await storage.read(unknownPath), marker);
    expect((await pruner().prune(catalogs.last)).deletedFiles, 0);
  });
  test(
    'bounded deletion resumes safely until only retained data remains',
    () async {
      var finished = false;
      for (var attempt = 0; attempt < 20; attempt++) {
        final result = await pruner(budget: 2).prune(catalogs.last);
        expect(result.deletedFiles, lessThanOrEqualTo(2));
        expect(await storage.read(revisions.last.payloadPath), isNotNull);
        if (!result.hasMore) {
          finished = true;
          break;
        }
      }
      expect(finished, isTrue);
      expect(await storage.list('devices/${identity.id}/catalog'), [
        '5.json',
        '6.json',
      ]);
      expect(
        await storage.list(
          'devices/${identity.id}/collections/following_topics/$source',
        ),
        hasLength(4),
      );
    },
  );
  test('an incomplete newest payload prevents any cleanup', () async {
    await storage.deleteOwnedRevision(
      revisions.last.payloadPath,
      owner: identity.id,
    );
    await expectLater(
      pruner().prune(catalogs.last),
      throwsA(isA<SyncRevisionUnavailable>()),
    );
    expect(await storage.read(catalogs.first.path), isNotNull);
    expect(await storage.read(revisions.first.payloadPath), isNotNull);
  });
  test(
    'provider I/O is not mistaken for an obsolete incomplete catalog',
    () async {
      await expectLater(
        pruner(adapter: _ReadFailure(storage, catalogs[4].path))
            .prune(catalogs.last),
        throwsA(isA<FileSystemException>()),
      );
      expect(await storage.read(catalogs.first.path), isNotNull);
      expect(await storage.read(revisions.first.payloadPath), isNotNull);
    },
  );
  test(
    'a partial previous catalog retains the next latest complete snapshot',
    () async {
      await File('${storage.root.path}/${catalogs[4].path}')
          .writeAsBytes([123], flush: true);
      await pruner().prune(catalogs.last);
      expect(await storage.read(catalogs[3].path), isNotNull);
      expect(await storage.read(catalogs[4].path), isNull);
      expect(
        await SyncRevisionTransport(storage)
            .read(expected: revisions[3], publisherKey: identity.publicKey),
        isNotNull,
      );
    },
  );
  test('cached complete revisions and recent reservation tails are protected', () async {
    final cached = await publish(7);
    await preferences.put(
      'mitemite.v1.outgoing.${cached.collection.key}.published',
      canonicalSyncJson(cached.toJson()),
    );
    await writer.sequences.reserve(identity.id, collection: cached.collection);
    await writer.sequences.reserve(identity.id, collection: cached.collection);
    final tail =
        'devices/${identity.id}/collections/following_topics/$source/8.bsexport';
    await storage.writeImmutable(tail, Uint8List.fromList([123]));
    await pruner().prune(catalogs.last);
    expect(await storage.read(cached.payloadPath), isNotNull);
    expect(await storage.read(tail), [123]);
    expect(await storage.read(revisions.first.payloadPath), isNull);
  });
  test(
    'a newer durable catalog intent blocks cleanup of an older candidate',
    () async {
      final next = await publish(7);
      final sequence = await writer.sequences.reserve(identity.id);
      await writer.sequences.stageCatalog(
        SyncCatalog(
          publisher: identity.id,
          sequence: sequence,
          name: 'Publisher',
          publicationRoots: {next.collection},
          entries: [
            SyncCatalogEntry(
              id: next.collection,
              name: 'Next',
              state: SyncPublicationState.active,
              revision: next,
            ),
          ],
        ),
      );
      await expectLater(
        pruner().prune(catalogs.last),
        throwsA(isA<SyncConflict>()),
      );
      expect(await storage.read(catalogs.first.path), isNotNull);
      expect(await storage.read(revisions.first.payloadPath), isNotNull);
    },
  );
  test('a bounded scan discards only confirmed incomplete catalogs until another complete snapshot is found', () async {
    for (var number = 7; number <= 12; number++) {
      expect(await writer.sequences.reserve(identity.id), number);
      await storage.writeImmutable(
        'devices/${identity.id}/catalog/$number.json',
        Uint8List.fromList([123]),
      );
    }
    final current = await writer.publishCatalog(
      name: 'Publisher',
      publicationRoots: {revisions.last.collection},
      entries: [
        SyncCatalogEntry(
          id: revisions.last.collection,
          name: 'Folder 6',
          state: SyncPublicationState.active,
          revision: revisions.last,
        ),
      ],
    );
    final result = await SyncOwnedRetention(
      storage: storage,
      identity: identity,
      preferences: preferences,
      maxCatalogChecks: 3,
    ).prune(current);
    expect(result.deletedFiles, 2);
    expect(result.hasMore, isTrue);
    expect(await storage.read(catalogs.last.path), isNotNull);
    expect(await storage.read(revisions.first.payloadPath), isNotNull);
  });

  test(
    'new local reservations revoke prepared cleanup before its next deletion',
    () async {
      var changed = false;
      final adapter = _AfterDelete(storage, () async {
        if (!changed) {
          changed = true;
          await writer.sequences.reserve(identity.id);
        }
      });
      await expectLater(
        pruner(adapter: adapter).prune(catalogs.last),
        throwsA(isA<SyncConflict>()),
      );
      expect(await storage.read(revisions.first.payloadPath), isNotNull);
      expect(await storage.read(revisions.last.payloadPath), isNotNull);
      expect(await storage.read(catalogs.last.path), isNotNull);
      expect(
        await storage.list('devices/${identity.id}/catalog'),
        hasLength(5),
      );
    },
  );
}

class _Store implements MiscDataStore {
  final values = <String, String>{};
  @override
  String? get(String key) => values[key];
  @override
  Future<void> put(String key, String value) async {
    values[key] = value;
  }
}

class _ReadFailure implements MiteMiteStorage {
  _ReadFailure(this.delegate, this.path);
  final MiteMiteStorage delegate;
  final String path;
  @override
  Future<List<String>> list(String path) => delegate.list(path);
  @override
  Future<Uint8List?> read(String path, {int maxBytes = miteMiteMaxBytes}) {
    if (path == this.path) {
      throw const FileSystemException('Controlled provider failure');
    }
    return delegate.read(path, maxBytes: maxBytes);
  }

  @override
  Future<void> writeImmutable(String path, Uint8List bytes) =>
      delegate.writeImmutable(path, bytes);
  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) =>
      delegate.deleteOwnedRevision(path, owner: owner);
  @override
  Future<void> deleteOwnedDirectory(String path, {required String owner}) =>
      delegate.deleteOwnedDirectory(path, owner: owner);
}

class _AfterDelete implements MiteMiteStorage {
  _AfterDelete(this.delegate, this.changed);
  final MiteMiteStorage delegate;
  final Future<void> Function() changed;
  @override
  Future<List<String>> list(String path) => delegate.list(path);
  @override
  Future<Uint8List?> read(String path, {int maxBytes = miteMiteMaxBytes}) =>
      delegate.read(path, maxBytes: maxBytes);
  @override
  Future<void> writeImmutable(String path, Uint8List bytes) =>
      delegate.writeImmutable(path, bytes);
  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) async {
    await delegate.deleteOwnedRevision(path, owner: owner);
    await changed();
  }

  @override
  Future<void> deleteOwnedDirectory(String path, {required String owner}) =>
      delegate.deleteOwnedDirectory(path, owner: owner);
}
