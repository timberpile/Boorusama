import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:boorusama/core/backups/mitemite/revision_transport.dart';
import 'package:boorusama/core/backups/mitemite/storage.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_schema.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SyncSigningIdentity identity;
  late SyncRevision revision;
  late _Storage storage;
  late SyncRevisionTransport transport;
  late Uint8List payload;

  setUp(() async {
    identity = await SyncSigningIdentity.create();
    payload = Uint8List.fromList([1, 2, 3]);
    revision = SyncRevision(
      collection: SyncCollectionId(
        publisher: identity.id,
        kind: 'bookmarks',
        source: '2aeebd3d-50e9-44cc-a174-c8abbe0a2468',
      ),
      revision: 7,
      length: payload.length,
      sha256: syncDigest(payload),
      semanticHash: syncDigest([9]),
      schema: 10,
    );
    storage = _Storage();
    storage.files[revision.descriptorPath] = await identity.sign(
      revision.toJson(),
    );
    storage.files[revision.payloadPath] = payload;
    transport = SyncRevisionTransport(storage);
  });

  Future<VerifiedSyncPayload?> read() => transport.read(
    expected: revision,
    publisherKey: identity.publicKey,
  );

  test('reads only the exact bounded descriptor and payload', () async {
    final verified = (await read())!;
    expect(verified.revision, same(revision));
    expect(verified.bytes, [1, 2, 3]);
    expect(storage.reads, [
      (revision.descriptorPath, miteMiteMaxMetadataBytes),
      (revision.payloadPath, revision.length),
    ]);
    payload[0] = 99;
    expect(verified.bytes, [1, 2, 3]);
    expect(() => verified.bytes[0] = 42, throwsUnsupportedError);
  });

  test('missing descriptor does not inspect payload or fall back', () async {
    storage.files.remove(revision.descriptorPath);
    expect(await read(), isNull);
    expect(storage.reads, [
      (revision.descriptorPath, miteMiteMaxMetadataBytes),
    ]);
  });

  test('missing payload is unavailable, not a withdrawal', () async {
    storage.files.remove(revision.payloadPath);
    expect(await read(), isNull);
    expect(storage.reads.length, 2);
  });

  test('permission failure propagates without older fallback', () async {
    storage.failure = StateError('Permission revoked');
    await expectLater(read(), throwsStateError);
    expect(storage.reads.length, 1);
  });

  test('a different signing key is rejected before reading payload', () async {
    final other = await SyncSigningIdentity.create();
    storage.files[revision.descriptorPath] = await other.sign(
      revision.toJson(),
    );
    await expectLater(read(), throwsFormatException);
    expect(storage.reads.length, 1);
  });

  for (final entry in <String, Object>{
    'publisher': 'b3bbb205-793d-4d11-b1df-249e5b32b1fe',
    'source': 'b3bbb205-793d-4d11-b1df-249e5b32b1fe',
    'kind': 'following_topics',
    'revision': 8,
    'length': 4,
    'sha256': syncDigest([4]),
    'semanticHash': syncDigest([5]),
    'schema': 11,
  }.entries) {
    test('signed ${entry.key} mismatch never reaches payload', () async {
      storage.files[revision.descriptorPath] = await identity.sign({
        ...revision.toJson(),
        entry.key: entry.value,
      });
      await expectLater(read(), throwsFormatException);
      expect(storage.reads.length, 1);
    });
  }

  test('future descriptor protocol cannot authorize payload', () async {
    storage.files[revision.descriptorPath] = await identity.sign({
      ...revision.toJson(),
      'protocol': 2,
    });
    await expectLater(read(), throwsA(isA<SyncUpdateRequired>()));
    expect(storage.reads.length, 1);
  });

  for (final corrupt in <List<int>>[
    [1, 2],
    [1, 2, 3, 4],
    [1, 2, 4],
  ]) {
    test('rejects corrupt bytes $corrupt even from a lax adapter', () async {
      storage.files[revision.payloadPath] = Uint8List.fromList(corrupt);
      await expectLater(read(), throwsFormatException);
    });
  }

  test('oversized descriptor is rejected even from a lax adapter', () async {
    storage.files[revision.descriptorPath] = Uint8List(
      miteMiteMaxMetadataBytes + 1,
    );
    await expectLater(read(), throwsFormatException);
    expect(storage.reads.length, 1);
  });
  test('large length is reserved for streamed Bookmark revisions', () {
    final fields = {
      ...revision.toJson(),
      'schema': kBookmarksBackupVersion,
      'bookmarkTables': true,
      'length': miteMiteMaxBytes + 1,
    };
    final streamed = SyncRevision.fromJson(fields);
    expect(streamed.length, miteMiteMaxBytes + 1);
    expect(streamed.bookmarkTables, isTrue);
    expect(streamed.toJson(), fields);
    final legacy = {
      ...fields,
      'length': miteMiteMaxBytes,
    }..remove('bookmarkTables');
    final unmarked = SyncRevision.fromJson(legacy);
    expect(unmarked.bookmarkTables, isFalse);
    expect(unmarked.toJson(), legacy);
    expect(
      () => SyncRevision.fromJson({...legacy, 'length': miteMiteMaxBytes + 1}),
      throwsFormatException,
    );
    for (final marker in [null, false, 'true', 1]) {
      expect(
        () => SyncRevision.fromJson({...legacy, 'bookmarkTables': marker}),
        throwsFormatException,
      );
    }
    expect(
      () => SyncRevision.fromJson({...fields, 'kind': 'following_topics'}),
      throwsFormatException,
    );
    expect(
      () => SyncRevision.fromJson({...fields, 'schema': 6}),
      throwsFormatException,
    );
    expect(
      () => SyncRevision.fromJson({
        ...fields,
        'length': miteMiteMaxBookmarkArchiveBytes + 1,
      }),
      throwsFormatException,
    );
  });

  test(
    'a signed descriptor cannot substitute unmarked v7 for tables',
    () async {
      final fields = {
        ...revision.toJson(),
        'schema': kBookmarksBackupVersion,
        'bookmarkTables': true,
      };
      final expected = SyncRevision.fromJson(fields);
      final unmarked = Map<String, Object?>.of(fields)
        ..remove('bookmarkTables');
      storage.files[expected.descriptorPath] = await identity.sign(unmarked);
      final directory = await Directory.systemTemp.createTemp(
        'sync_marker_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      await expectLater(
        transport.readToFile(
          expected: expected,
          publisherKey: identity.publicKey,
          destination: '${directory.path}/output',
        ),
        throwsFormatException,
      );
      expect(storage.reads, [
        (expected.descriptorPath, miteMiteMaxMetadataBytes),
      ]);
    },
  );

  test('publishes and verifies a file larger than the byte transport limit', () async {
    final directory = await Directory.systemTemp.createTemp('sync_file_test_');
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/source');
    final output = File('${directory.path}/output');
    final opened = await source.open(mode: FileMode.writeOnly);
    const length = miteMiteMaxBytes + 1;
    await opened.truncate(length);
    await opened.close();
    final streamRevision = SyncRevision(
      collection: revision.collection,
      revision: revision.revision,
      length: length,
      sha256: (await sha256.bind(source.openRead()).single).toString(),
      semanticHash: revision.semanticHash,
      schema: kBookmarksBackupVersion,
      bookmarkTables: true,
    );
    final directoryStorage = DirectoryMiteMiteStorage(directory.path);
    final direct = SyncRevisionTransport(directoryStorage);
    await direct.writeFile(revision: streamRevision, sourcePath: source.path);
    Future<bool> fetch() => direct.readToFile(
      expected: streamRevision,
      publisherKey: identity.publicKey,
      destination: output.path,
    );
    expect(await fetch(), isFalse);
    expect(output.existsSync(), isFalse);
    await directoryStorage.writeImmutable(
      streamRevision.descriptorPath,
      await identity.sign(streamRevision.toJson()),
    );
    expect(await fetch(), isTrue);
    expect(await output.length(), length);
    expect(
      (await sha256.bind(output.openRead()).single).toString(),
      streamRevision.sha256,
    );
    // Reuse requires an immutable byte-for-byte match and cannot clobber either
    // the shared payload or an already occupied staging destination.
    await direct.writeFile(revision: streamRevision, sourcePath: source.path);
    await expectLater(fetch(), throwsA(isA<FileSystemException>()));
    expect(await output.length(), length);
    await source.writeAsBytes([3]);
    await expectLater(
      direct.writeFile(revision: streamRevision, sourcePath: source.path),
      throwsFormatException,
    );
    expect(
      await direct.verify(
        expected: streamRevision,
        publisherKey: identity.publicKey,
      ),
      isTrue,
    );
  });

  test('a corrupted published payload leaves no usable staging file', () async {
    final directory = await Directory.systemTemp.createTemp('sync_file_test_');
    addTearDown(() => directory.delete(recursive: true));
    final directoryStorage = DirectoryMiteMiteStorage(directory.path);
    final output = File('${directory.path}/output');
    await directoryStorage.writeImmutable(
      revision.descriptorPath,
      await identity.sign(revision.toJson()),
    );
    await directoryStorage.writeImmutable(
      revision.payloadPath,
      Uint8List.fromList([1, 2, 4]),
    );
    await expectLater(
      SyncRevisionTransport(directoryStorage).readToFile(
        expected: revision,
        publisherKey: identity.publicKey,
        destination: output.path,
      ),
      throwsFormatException,
    );
    expect(output.existsSync(), isFalse);
  });
}

final class _Storage implements MiteMiteStorage {
  final files = <String, Uint8List>{};
  final reads = <(String, int)>[];
  Error? failure;

  @override
  Future<Uint8List?> read(
    String path, {
    int maxBytes = miteMiteMaxBytes,
  }) async {
    reads.add((path, maxBytes));
    final error = failure;
    if (error != null) throw error;
    // Deliberately does not enforce maxBytes: the transport must also validate.
    return files[path];
  }

  @override
  Future<List<String>> list(String path) async =>
      throw StateError('No discovery');

  @override
  Future<void> writeImmutable(String path, Uint8List bytes) async =>
      throw StateError('Read-only boundary');

  @override
  Future<void> deleteOwnedRevision(
    String path, {
    required String owner,
  }) async => throw StateError('No deletion authority');
  @override
  Future<void> deleteOwnedDirectory(String path, {required String owner}) =>
      throw UnsupportedError('Directory cleanup');
}
