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
    await gate.approvePublisher(
      publisher: identity.id,
      publicKey: identity.publicKey,
    );
  });

  Future<Uint8List> catalog(
    int sequence, {
    Object? protocol = folderSyncProtocol,
    Object? collections = const <Object>[],
    String? publisher,
  }) => identity.sign({
    'protocol': protocol,
    'publisher': publisher ?? identity.id,
    'sequence': sequence,
    'deviceName': 'Publisher',
    'collections': collections,
  });

  Future<VerifiedSyncCatalog> accept(int sequence) async =>
      gate.verifyAndCheckpoint(
        publisher: identity.id,
        expectedSequence: sequence,
        bytes: await catalog(sequence),
      );

  test(
    'an unsupported signed protocol persists the observed high water',
    () async {
      await accept(2);
      final future = await catalog(
        8,
        protocol: 2,
        collections: {'future': true},
      );
      await expectLater(
        gate.verifyAndCheckpoint(
          publisher: identity.id,
          expectedSequence: 8,
          bytes: future,
        ),
        throwsA(isA<SyncUpdateRequired>()),
      );
      gate = SyncCatalogGate(store: store, mutations: mutations);
      await expectLater(accept(7), throwsA(isA<SyncReplayRejected>()));
      await expectLater(accept(8), throwsA(isA<SyncReplayRejected>()));
      await expectLater(
        gate.verifyAndCheckpoint(
          publisher: identity.id,
          expectedSequence: 8,
          bytes: future,
        ),
        throwsA(isA<SyncUpdateRequired>()),
      );
      expect((await accept(9)).sequence, 9);
    },
  );

  test('unsupported observation revokes a prepared older commit', () async {
    final prepared = await accept(2);
    await expectLater(
      gate.verifyAndCheckpoint(
        publisher: identity.id,
        expectedSequence: 3,
        bytes: await catalog(3, protocol: 2),
      ),
      throwsA(isA<SyncUpdateRequired>()),
    );
    var committed = false;
    await expectLater(
      gate.withCurrentCatalog(prepared, () async => committed = true),
      throwsA(isA<SyncReplayRejected>()),
    );
    expect(committed, isFalse);
  });

  test(
    'invalid version-specific body cannot resurrect an older catalog',
    () async {
      final prepared = await accept(2);
      await expectLater(
        gate.verifyAndCheckpoint(
          publisher: identity.id,
          expectedSequence: 3,
          bytes: await catalog(3, collections: {'not': 'a list'}),
        ),
        throwsFormatException,
      );
      await expectLater(accept(2), throwsA(isA<SyncReplayRejected>()));
      await expectLater(
        gate.withCurrentCatalog(prepared, () async => fail('Stale commit ran')),
        throwsA(isA<SyncReplayRejected>()),
      );
    },
  );

  test(
    'unsupported observation must finish its durable write before failing',
    () async {
      await accept(2);
      final before = Map<String, String>.of(store.values);
      final future = await catalog(3, protocol: 2);
      store.failWrites = true;
      await expectLater(
        gate.verifyAndCheckpoint(
          publisher: identity.id,
          expectedSequence: 3,
          bytes: future,
        ),
        throwsStateError,
      );
      expect(store.values, before);
      store.failWrites = false;
      await expectLater(
        gate.verifyAndCheckpoint(
          publisher: identity.id,
          expectedSequence: 3,
          bytes: future,
        ),
        throwsA(isA<SyncUpdateRequired>()),
      );
      await expectLater(accept(2), throwsA(isA<SyncReplayRejected>()));
    },
  );

  test(
    'an unsupported document still needs a bound authentic common header',
    () async {
      await accept(2);
      final future = await catalog(99, protocol: 2);
      await expectLater(
        gate.verifyAndCheckpoint(
          publisher: identity.id,
          expectedSequence: 100,
          bytes: future,
        ),
        throwsFormatException,
      );
      final other = await SyncSigningIdentity.create();
      await expectLater(
        gate.verifyAndCheckpoint(
          publisher: identity.id,
          expectedSequence: 99,
          bytes: await catalog(99, protocol: 2, publisher: other.id),
        ),
        throwsFormatException,
      );
      final forged = jsonDecode(utf8.decode(future)) as Map<String, dynamic>;
      (forged['content'] as Map<String, dynamic>)['sequence'] = 100;
      await expectLater(
        gate.verifyAndCheckpoint(
          publisher: identity.id,
          expectedSequence: 100,
          bytes: syncJsonBytes(forged),
        ),
        throwsFormatException,
      );
      expect((await accept(3)).sequence, 3);
    },
  );

  for (final protocol in <Object?>[null, 0, -1, '2', 2.0]) {
    test(
      'invalid common protocol $protocol cannot advance the checkpoint',
      () async {
        await accept(2);
        await expectLater(
          gate.verifyAndCheckpoint(
            publisher: identity.id,
            expectedSequence: 99,
            bytes: await catalog(99, protocol: protocol),
          ),
          throwsFormatException,
        );
        expect((await accept(3)).sequence, 3);
      },
    );
  }
}

final class _Store implements MiscDataStore {
  final values = <String, String>{};
  var failWrites = false;

  @override
  String? get(String key) => values[key];

  @override
  Future<void> put(String key, String value) async {
    if (failWrites) throw StateError('Injected metadata write failure');
    values[key] = value;
  }
}
