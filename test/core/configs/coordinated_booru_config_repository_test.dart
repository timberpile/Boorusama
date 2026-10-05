import '../../profile_uuid_utils.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/configs/config/data.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';

void main() {
  test('profile writes wait for the active data transaction', () async {
    final coordinator = DataMutationCoordinator();
    final entered = Completer<void>();
    final release = Completer<void>();
    final delegate = _RecordingRepository();
    final repository = CoordinatedBooruConfigRepository(delegate, coordinator);

    final transaction = coordinator.runExclusive(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;

    final write = repository.update(
      profileUuid(1),
      BooruConfig.empty.toBooruConfigData(),
    );
    await Future<void>.delayed(Duration.zero);
    expect(delegate.updateCalls, 0);

    release.complete();
    await transaction;
    await write;
    expect(delegate.updateCalls, 1);
  });

  test(
    'atomic profile updates re-read data after an import finishes',
    () async {
      final coordinator = DataMutationCoordinator();
      final entered = Completer<void>();
      final release = Completer<void>();
      final delegate = _RecordingRepository(
        profile: BooruConfig.fromJson({
          ...BooruConfig.empty.toJson(),
          'id': profileUuid(1),
          'url': 'https://before.example',
          'apiKey': 'old-token',
        }),
      );
      final repository = CoordinatedBooruConfigRepository(
        delegate,
        coordinator,
      );

      final import = coordinator.runExclusive(() async {
        entered.complete();
        delegate.profile = BooruConfig.fromJson({
          ...delegate.profile!.toJson(),
          'url': 'https://imported.example',
        });
        await release.future;
      });
      await entered.future;

      final tokenUpdate = updateBooruConfigAtomically(
        repository: repository,
        id: profileUuid(1),
        transform: (current) =>
            current.toBooruConfigData().copyWith(apiKey: 'rotated-token'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(delegate.updateCalls, 0);

      release.complete();
      await import;
      await tokenUpdate;

      expect(delegate.profile!.url, 'https://imported.example');
      expect(delegate.profile!.apiKey, 'rotated-token');
    },
  );
}

final class _RecordingRepository implements BooruConfigRepository {
  _RecordingRepository({this.profile});

  BooruConfig? profile;
  var updateCalls = 0;

  @override
  Future<BooruConfig?> update(
    String id,
    BooruConfigData booruConfigData,
  ) async {
    updateCalls++;
    if (profile?.id != id) return null;
    return profile = booruConfigData.toBooruConfig(id: id);
  }

  @override
  Future<BooruConfig?> add(BooruConfigData booruConfigData) async => null;

  @override
  Future<List<BooruConfig>> addAll(List<BooruConfig> booruConfigs) async => [];

  @override
  Future<void> clear() async {}

  @override
  Future<List<BooruConfig>> getAll() async => [?profile];

  @override
  Future<void> remove(BooruConfig booruConfig) async {}
}
