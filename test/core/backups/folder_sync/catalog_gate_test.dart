import 'dart:convert';
import 'dart:typed_data';

import 'package:boorusama/core/backups/folder_sync/catalog_gate.dart';
import 'package:boorusama/core/backups/folder_sync/protocol.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SyncSigningIdentity identity;
  late _Store store;
  late DataMutationCoordinator mutations;
  late SyncCatalogGate gate;

  setUp(() async {
    identity = await SyncSigningIdentity.create();
    store = _Store();
    mutations = DataMutationCoordinator();
    gate = SyncCatalogGate(store: store, mutations: mutations);
  });

  Future<Uint8List> catalog(int sequence, {String name = 'Publisher'}) =>
      identity.sign({
        'protocol': folderSyncProtocol,
        'publisher': identity.id,
        'sequence': sequence,
        'deviceName': name,
        'collections': <Object>[],
      });

  Future<void> approve() => gate.approvePublisher(
    publisher: identity.id,
    publicKey: identity.publicKey,
  );

  Future<VerifiedSyncCatalog> accept(
    int sequence, {
    SyncCatalogGate? through,
    String name = 'Publisher',
  }) async => (through ?? gate).verifyAndCheckpoint(
    publisher: identity.id,
    expectedSequence: sequence,
    bytes: await catalog(sequence, name: name),
  );

  test('signature alone cannot approve a publisher', () async {
    await expectLater(accept(1), throwsA(isA<SyncTrustRequired>()));
    expect(store.values, isEmpty);
  });

  test(
    'checkpoint survives gate recreation and rejects older signed catalogs',
    () async {
      await approve();
      final accepted = await accept(7);
      final reopened = SyncCatalogGate(store: store, mutations: mutations);
      await expectLater(
        accept(6, through: reopened),
        throwsA(isA<SyncReplayRejected>()),
      );
      final retried = await accept(7, through: reopened);
      expect(retried.digest, accepted.digest);
      expect(retried.sequence, 7);
      expect((await accept(8, through: reopened)).sequence, 8);
    },
  );

  test(
    'an identical retry repeats a failed cache-visible durability barrier',
    () async {
      await approve();
      store.failAfterCache = true;
      await expectLater(accept(1), throwsStateError);
      // Cached OBSERVED is already advanced, but still not durable.
      await expectLater(accept(1), throwsStateError);
      store.failAfterCache = false;
      final ticket = await accept(1);
      var applied = false;
      await gate.withCurrentCatalog(ticket, () async {
        applied = true;
      });
      expect(applied, isTrue);
    },
  );

  test('same sequence with different signed content is equivocation', () async {
    await approve();
    await accept(3);
    await expectLater(
      accept(3, name: 'Different'),
      throwsA(isA<SyncReplayRejected>()),
    );
  });

  test(
    'reapproval does not erase the high-water mark or replace the key',
    () async {
      await approve();
      await accept(3);
      await approve();
      await expectLater(accept(2), throwsA(isA<SyncReplayRejected>()));
      final attacker = await SyncSigningIdentity.create();
      await expectLater(
        gate.approvePublisher(
          publisher: identity.id,
          publicKey: attacker.publicKey,
        ),
        throwsFormatException,
      );
      expect((await accept(3)).sequence, 3);
    },
  );

  test(
    'bad signature and filename mismatch cannot advance the checkpoint',
    () async {
      await approve();
      final envelope = jsonDecode(utf8.decode(await catalog(99))) as Map;
      (envelope['content'] as Map)['deviceName'] = 'Forged';
      await expectLater(
        gate.verifyAndCheckpoint(
          publisher: identity.id,
          expectedSequence: 99,
          bytes: syncJsonBytes(envelope),
        ),
        throwsFormatException,
      );
      await expectLater(
        gate.verifyAndCheckpoint(
          publisher: identity.id,
          expectedSequence: 100,
          bytes: await catalog(99),
        ),
        throwsFormatException,
      );
      expect((await accept(1)).sequence, 1);
    },
  );

  test(
    'checkpoint write failure returns no authority to apply a catalog',
    () async {
      await approve();
      final before = Map<String, String>.of(store.values);
      store.failWrites = true;
      await expectLater(accept(4), throwsStateError);
      expect(store.values, before);
      store.failWrites = false;
      expect((await accept(4)).sequence, 4);
    },
  );

  test(
    'two gate instances serialize through the shared mutation coordinator',
    () async {
      await approve();
      final other = SyncCatalogGate(store: store, mutations: mutations);
      final high = gate.verifyAndCheckpoint(
        publisher: identity.id,
        expectedSequence: 9,
        bytes: await catalog(9),
      );
      final lowBytes = await catalog(8);
      final low = other.verifyAndCheckpoint(
        publisher: identity.id,
        expectedSequence: 8,
        bytes: lowBytes,
      );
      await expectLater(low, throwsA(isA<SyncReplayRejected>()));
      expect((await high).sequence, 9);
    },
  );

  test(
    'damaged local trust never silently resets to a fresh checkpoint',
    () async {
      await approve();
      store.values[store.values.keys.single] = '{broken';
      await expectLater(accept(1), throwsFormatException);
      await expectLater(approve(), throwsFormatException);
    },
  );

  test(
    'verified data is deeply immutable; unknown source kinds stay visible',
    () async {
      await approve();
      final accepted = await gate.verifyAndCheckpoint(
        publisher: identity.id,
        expectedSequence: 1,
        bytes: await identity.sign({
          'protocol': folderSyncProtocol,
          'publisher': identity.id,
          'sequence': 1,
          'deviceName': 'Publisher',
          'collections': [
            {'kind': 'future-kind', 'state': 'active'},
          ],
        }),
      );
      final entries = accepted.content['collections'] as List;
      expect((entries.single as Map)['kind'], 'future-kind');
      expect(() => entries.clear(), throwsUnsupportedError);
      expect(
        () => (entries.single as Map)['state'] = 'withdrawn',
        throwsUnsupportedError,
      );
    },
  );

  test(
    'canonical ordering does not change signatures or content digest',
    () async {
      expect(
        canonicalSyncJson({
          'z': 1,
          'a': {'b': 2, 'a': 1},
        }),
        canonicalSyncJson({
          'a': {'a': 1, 'b': 2},
          'z': 1,
        }),
      );
      final original = {'protocol': folderSyncProtocol, 'value': 5};
      final signed = await identity.sign(original);
      expect(await verifySyncDocument(signed, identity.publicKey), original);
      final other = await SyncSigningIdentity.create();
      await expectLater(
        verifySyncDocument(signed, other.publicKey),
        throwsFormatException,
      );
    },
  );
}

final class _Store implements MiscDataStore {
  final values = <String, String>{};
  var failWrites = false;
  var failAfterCache = false;
  @override
  String? get(String key) => values[key];
  @override
  Future<void> put(String key, String value) async {
    if (failWrites) throw StateError('Injected metadata write failure');
    values[key] = value;
    if (failAfterCache) throw StateError('Injected durability failure');
  }
}
