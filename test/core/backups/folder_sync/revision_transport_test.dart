import 'dart:typed_data';

import 'package:boorusama/core/backups/folder_sync/protocol.dart';
import 'package:boorusama/core/backups/folder_sync/revision_transport.dart';
import 'package:boorusama/core/backups/folder_sync/storage.dart';
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
    storage.files[revision.descriptorPath] = await identity.sign(revision.toJson());
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
      (revision.descriptorPath, folderSyncMaxMetadataBytes),
      (revision.payloadPath, revision.length),
    ]);
    payload[0] = 99;
    expect(verified.bytes, [1, 2, 3]);
    expect(() => verified.bytes[0] = 42, throwsUnsupportedError);
  });

  test('missing descriptor does not inspect payload or fall back', () async {
    storage.files.remove(revision.descriptorPath);
    expect(await read(), isNull);
    expect(storage.reads, [(revision.descriptorPath, folderSyncMaxMetadataBytes)]);
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
    storage.files[revision.descriptorPath] = await other.sign(revision.toJson());
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

  for (final corrupt in <List<int>>[[1, 2], [1, 2, 3, 4], [1, 2, 4]]) {
    test('rejects corrupt bytes $corrupt even from a lax adapter', () async {
      storage.files[revision.payloadPath] = Uint8List.fromList(corrupt);
      await expectLater(read(), throwsFormatException);
    });
  }

  test('oversized descriptor is rejected even from a lax adapter', () async {
    storage.files[revision.descriptorPath] = Uint8List(folderSyncMaxMetadataBytes + 1);
    await expectLater(read(), throwsFormatException);
    expect(storage.reads.length, 1);
  });
}

final class _Storage implements FolderSyncStorage {
  final files = <String, Uint8List>{};
  final reads = <(String, int)>[];
  Object? failure;

  @override
  Future<Uint8List?> read(String path, {int maxBytes = folderSyncMaxBytes}) async {
    reads.add((path, maxBytes));
    final error = failure;
    if (error != null) throw error;
    // Deliberately does not enforce maxBytes: the transport must also validate.
    return files[path];
  }

  @override
  Future<List<String>> list(String path) async => throw StateError('No discovery');

  @override
  Future<void> writeImmutable(String path, Uint8List bytes) async =>
      throw StateError('Read-only boundary');

  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) async =>
      throw StateError('No deletion authority');
}
