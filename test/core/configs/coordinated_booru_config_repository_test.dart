import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/configs/config/data.dart';
import 'package:boorusama/core/configs/config/src/data/coordinated_booru_config_repository.dart';
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

    final write = repository.update(1, BooruConfig.empty.toBooruConfigData());
    await Future<void>.delayed(Duration.zero);
    expect(delegate.updateCalls, 0);

    release.complete();
    await transaction;
    await write;
    expect(delegate.updateCalls, 1);
  });
}

final class _RecordingRepository implements BooruConfigRepository {
  var updateCalls = 0;

  @override
  Future<BooruConfig?> update(int id, BooruConfigData booruConfigData) async {
    updateCalls++;
    return null;
  }

  @override
  Future<BooruConfig?> add(BooruConfigData booruConfigData) async => null;

  @override
  Future<List<BooruConfig>> addAll(List<BooruConfig> booruConfigs) async => [];

  @override
  Future<void> clear() async {}

  @override
  Future<List<BooruConfig>> getAll() async => [];

  @override
  Future<void> remove(BooruConfig booruConfig) async {}
}
