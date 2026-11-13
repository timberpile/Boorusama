import 'package:boorusama/core/backups/folder_sync/catalog_gate.dart';
import 'package:boorusama/core/backups/folder_sync/protocol.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prepared catalog cannot commit after newer catalog or trust loss', () async {
    final store = _Store();
    final mutations = DataMutationCoordinator();
    final gate = SyncCatalogGate(store: store, mutations: mutations);
    final identity = await SyncSigningIdentity.create();
    await gate.approvePublisher(publisher: identity.id, publicKey: identity.publicKey);
    Future<VerifiedSyncCatalog> receive(int sequence) async =>
        gate.verifyAndCheckpoint(
          publisher: identity.id,
          expectedSequence: sequence,
          bytes: await identity.sign({
            'protocol': folderSyncProtocol,
            'publisher': identity.id,
            'sequence': sequence,
            'deviceName': 'Publisher',
            'collections': <Object>[],
          }),
        );
    final first = await receive(1);
    var commits = 0;
    Future<int> commit() async {
      expect(mutations.isCurrentOwner, isTrue);
      return ++commits;
    }
    expect(await gate.withCurrentCatalog(first, commit), 1);
    final second = await receive(2);
    await expectLater(
      gate.withCurrentCatalog(first, commit),
      throwsA(isA<SyncReplayRejected>()),
    );
    expect(commits, 1);
    expect(await gate.withCurrentCatalog(second, commit), 2);
    await mutations.runExclusive(() async => store.values.clear());
    await expectLater(
      gate.withCurrentCatalog(second, commit),
      throwsA(isA<SyncTrustRequired>()),
    );
    expect(commits, 2);
  });
}

final class _Store implements MiscDataStore {
  final values = <String, String>{};
  @override
  String? get(String key) => values[key];
  @override
  Future<void> put(String key, String value) async {
    values[key] = value;
  }
}
