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
    String id,
    BooruConfigData booruConfigData,
  ) => coordinator.runExclusive(() => delegate.update(id, booruConfigData));

  Future<BooruConfig?> updateAtomically(
    String id,
    BooruConfigData? Function(BooruConfig current) transform,
  ) => coordinator.runExclusive(() async {
    final current = await _findById(delegate, id);
    if (current == null) return null;
    final update = transform(current);
    if (update == null) return null;
    return delegate.update(id, update);
  });
}

Future<BooruConfig?> updateBooruConfigAtomically({
  required BooruConfigRepository repository,
  required String id,
  required BooruConfigData? Function(BooruConfig current) transform,
}) async {
  if (repository case final CoordinatedBooruConfigRepository coordinated) {
    return coordinated.updateAtomically(id, transform);
  }
  final current = await _findById(repository, id);
  if (current == null) return null;
  final update = transform(current);
  if (update == null) return null;
  return repository.update(id, update);
}

Future<BooruConfig?> _findById(
  BooruConfigRepository repository,
  String id,
) async {
  for (final config in await repository.getAll()) {
    if (config.id == id) return config;
  }
  return null;
}
