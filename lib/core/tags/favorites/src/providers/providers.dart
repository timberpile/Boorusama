// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import '../../../../../foundation/data_mutation_coordinator.dart';
import '../../../../search/selected_tags/types.dart';
import '../data/favorite_tag_hive_object.dart';
import '../data/favorite_tag_repository_hive.dart';
import '../types/favorite_tag.dart';

final favoriteTagRepoProvider = FutureProvider<FavoriteTagRepository>((
  ref,
) async {
  final favoriteTagsBox = await Hive.openBox<FavoriteTagHiveObject>(
    'favorite_tags',
  );
  final favoriteTagsRepo = FavoriteTagRepositoryHive(
    favoriteTagsBox,
  );

  ref.onDispose(() async {
    await favoriteTagsBox.close();
  });

  return _CoordinatedFavoriteTagRepository(
    favoriteTagsRepo,
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
