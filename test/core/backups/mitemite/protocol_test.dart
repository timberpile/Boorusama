import 'dart:typed_data';

import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final collection = SyncCollectionId(
    publisher: '10000000-0000-4000-8000-000000000001',
    kind: 'bookmarks',
    source: '10000000-0000-4000-8000-000000000002',
  );

  test(
    'descriptor round trip retains typed identity and exact payload binding',
    () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final revision = SyncRevision(
        collection: collection,
        revision: 1,
        length: bytes.length,
        sha256: syncDigest(bytes),
        semanticHash: syncDigest([7]),
        schema: 10,
      );
      final restored = SyncRevision.fromJson(
        Map<String, dynamic>.from(revision.toJson()),
      );
      expect(restored.collection, collection);
      expect(restored.payloadPath, '${collection.directory}/1.bsexport');
      expect(restored.descriptorPath, '${collection.directory}/1.json');
      restored.verifyPayload(bytes);
      expect(() => restored.verifyPayload([1, 2]), throwsFormatException);
      expect(() => restored.verifyPayload([1, 2, 4]), throwsFormatException);
      expect(
        () => SyncRevision.fromJson({...revision.toJson(), 'schema': 0}),
        throwsFormatException,
      );
    },
  );

  test(
    'identity signing freezes input before awaiting key operations',
    () async {
      final identity = await SyncSigningIdentity.create();
      final content = <String, Object?>{
        'protocol': miteMiteProtocol,
        'value': 1,
      };
      final pending = identity.sign(content);
      content['value'] = 2;
      expect(
        (await verifySyncDocument(await pending, identity.publicKey))['value'],
        1,
      );
      expect(identity.publicJson().containsKey('seed'), isFalse);
      expect(() => identity.publicKey[0] = 0, throwsUnsupportedError);
      final other = await SyncSigningIdentity.create();
      final mismatched = SyncSigningIdentity(
        id: identity.id,
        seed: identity.seed,
        publicKey: other.publicKey,
      );
      await expectLater(
        mismatched.sign({'protocol': miteMiteProtocol}),
        throwsFormatException,
      );
    },
  );

  test('payload hashing freezes exact bytes before worker admission', () async {
    final bytes = Uint8List.fromList([97, 98, 99]);
    final pending = syncPayloadDigestAsync(bytes);
    bytes[0] = 0;
    expect(
      await pending,
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('metadata byte and canonical nesting limits reject hostile input', () {
    expect(
      () => decodeSyncObject(Uint8List(miteMiteMaxMetadataBytes + 1)),
      throwsFormatException,
    );
    Object? nested;
    for (var i = 0; i < 70; i++) {
      nested = [nested];
    }
    expect(() => canonicalSyncJson(nested), throwsFormatException);
    expect(
      () => SyncCollectionId(
        publisher: collection.publisher,
        kind: 'bookmarks',
        source: '../unsafe',
      ),
      throwsFormatException,
    );
    expect(
      () => SyncCollectionId(
        publisher: collection.publisher,
        kind: 'future',
        source: collection.source,
      ),
      throwsA(isA<SyncUpdateRequired>()),
    );
  });
}
