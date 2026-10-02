import '../../../../../foundation/data_mutation_coordinator.dart';
import '../types/booru_config.dart';
import '../types/booru_config_data.dart';
import '../types/booru_config_repository.dart';

final class CoordinatedBooruConfigRepository implements BooruConfigRepository {
  const CoordinatedBooruConfigRepository(this.delegate, this.coordinator);

  final BooruConfigRepository delegate;
  final DataMutationCoordinator coordinator;

  @override
  Future<BooruConfig?> add(BooruConfigData booruConfigData) =>
      coordinator.runExclusive(() => delegate.add(booruConfigData));

  @override
  Future<List<BooruConfig>> addAll(List<BooruConfig> booruConfigs) =>
      coordinator.runExclusive(() => delegate.addAll(booruConfigs));

  @override
  Future<void> clear() => coordinator.runExclusive(delegate.clear);

  @override
  Future<List<BooruConfig>> getAll() => delegate.getAll();

  @override
  Future<void> remove(BooruConfig booruConfig) =>
      coordinator.runExclusive(() => delegate.remove(booruConfig));

  @override
  Future<BooruConfig?> update(
    int id,
    BooruConfigData booruConfigData,
  ) => coordinator.runExclusive(() => delegate.update(id, booruConfigData));
}
