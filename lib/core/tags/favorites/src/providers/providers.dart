// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../foundation/data_mutation_coordinator.dart';
import '../../../../search/selected_tags/types.dart';
import '../types/favorite_tag.dart';
import '../types/favorite_tag_repository_factory.dart';

final favoriteTagRepositoryFactoryProvider =
    Provider<FavoriteTagRepositoryFactory>(
      (_) => throw UnimplementedError(
        'favoriteTagRepositoryFactoryProvider must be overridden',
      ),
      name: 'favoriteTagRepositoryFactoryProvider',
    );

final favoriteTagRepoProvider = FutureProvider<FavoriteTagRepository>((
  ref,
) async {
  final factory = ref.watch(favoriteTagRepositoryFactoryProvider);
  final repository = await factory.create();
  ref.onDispose(() => factory.dispose(repository));

  return _CoordinatedFavoriteTagRepository(
    repository,
    ref.watch(dataMutationCoordinatorProvider),
  );
});

final class _CoordinatedFavoriteTagRepository implements FavoriteTagRepository {
  const _CoordinatedFavoriteTagRepository(this.delegate, this.coordinator);

  final FavoriteTagRepository delegate;
  final DataMutationCoordinator coordinator;

  @override
  Future<FavoriteTag> create({
    required String name,
    List<String>? labels,
    QueryType? queryType,
  }) => coordinator.runExclusive(
    () => delegate.create(name: name, labels: labels, queryType: queryType),
  );

  @override
  Future<List<FavoriteTag>> createFrom(List<FavoriteTag> tags) =>
      coordinator.runExclusive(() => delegate.createFrom(tags));

  @override
  Future<FavoriteTag?> deleteFirst(String name) =>
      coordinator.runExclusive(() => delegate.deleteFirst(name));

  @override
  Future<List<FavoriteTag>> get(String name) => delegate.get(name);

  @override
  Future<List<FavoriteTag>> getAll() => delegate.getAll();

  @override
  Future<FavoriteTag?> getFirst(String name) => delegate.getFirst(name);

  @override
  Future<void> replaceAll(List<FavoriteTag> tags) =>
      coordinator.runExclusive(() => delegate.replaceAll(tags));

  @override
  Future<FavoriteTag?> restore(FavoriteTag tag) =>
      coordinator.runExclusive(() => delegate.restore(tag));

  @override
  Future<FavoriteTag?> updateFirst(String name, FavoriteTag tag) =>
      coordinator.runExclusive(() => delegate.updateFirst(name, tag));
}
