// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../post/types.dart';
import '../data/providers.dart';
import '../types/types.dart';
import '../types/favorite_interruption.dart';
import '../types/favorite_mutation_tracker.dart';

final favoritesProvider =
    NotifierProvider.family<
      FavoritesNotifier,
      IMap<int, bool>,
      BooruConfigAuth
    >(
      FavoritesNotifier.new,
    );

final favoriteProvider = Provider.autoDispose
    .family<bool, (BooruConfigAuth, int)>(
      (ref, params) {
        final (config, postId) = params;
        return ref.watch(favoritesProvider(config))[postId] ?? false;
      },
    );

final favoriteStatusProvider = Provider.autoDispose
    .family<bool?, (BooruConfigAuth, int)>(
      (ref, params) {
        final (config, postId) = params;
        return ref.watch(favoritesProvider(config))[postId];
      },
    );

final favoriteStatusLoaderProvider = FutureProvider.autoDispose
    .family<void, (BooruConfigAuth, int)>((ref, params) async {
      final (config, postId) = params;
      final status = ref.watch(favoriteStatusProvider(params));

      if (status != null) return;

      await ref.read(favoritesProvider(config).notifier).checkFavorites([
        postId,
      ]);
    });

final canFavoriteProvider = Provider.family<bool, BooruConfigAuth>((
  ref,
  config,
) {
  return ref.watch(favoriteRepoProvider(config)).canFavorite();
});

class FavoritesNotifier
    extends FamilyNotifier<IMap<int, bool>, BooruConfigAuth> {
  @override
  IMap<int, bool> build(BooruConfigAuth arg) {
    return <int, bool>{}.lock;
  }

  final _mutations = FavoriteMutationTracker<int>();

  FavoriteRepository get repo => ref.read(favoriteRepoProvider(arg));

  void preload<T extends Post>(List<T> posts) => preloadInternal(
    posts,
    selfFavorited: (post) => repo.isPostFavorited(post),
  );

  Future<void> checkFavorites(List<int> postIds) async {
    // Filter postIds not in cache
    final postIdsToCheck = postIds
        .where((postId) => !state.containsKey(postId))
        .toList();

    if (postIdsToCheck.isEmpty) return;

    final cache = state.unlock;

    final favoritedPosts = await repo.filterFavoritedPosts(postIdsToCheck);

    // Update cache with results
    for (final postId in postIdsToCheck) {
      cache[postId] = favoritedPosts.contains(postId);
    }

    state = cache.lock;
  }

  Future<AddFavoriteStatus> add(int postId) async {
    if (state[postId] ?? false) return AddFavoriteStatus.alreadyExists;
    final operation = _mutations.start(postId, state[postId], true);
    state = state.add(postId, true);
    var acknowledged = false;
    try {
      final status = await repo.addToFavorites(postId);
      acknowledged =
          status == AddFavoriteStatus.success ||
          status == AddFavoriteStatus.alreadyExists;
      return status;
    } finally {
      _finish(postId, operation, acknowledged: acknowledged);
    }
  }

  Future<bool> remove(int postId) async {
    if (state[postId] == false) return true;
    final operation = _mutations.start(postId, state[postId], false);
    state = state.add(postId, false);
    var acknowledged = false;
    try {
      return acknowledged = await repo.removeFromFavorites(postId);
    } on FavoriteCompletedWithInterruption catch (error) {
      acknowledged = true;
      if (reportCompletedFavoriteInterruption(error)) return true;
      rethrow;
    } finally {
      _finish(postId, operation, acknowledged: acknowledged);
    }
  }

  void _finish(int postId, int operation, {required bool acknowledged}) {
    final result = _mutations.finish(
      postId,
      operation,
      acknowledged: acknowledged,
    );
    if (result == null) return;
    final prior = result.favorite;
    state = prior == null ? state.remove(postId) : state.add(postId, prior);
  }

  void removeLocalFavorite(int postId) {
    _mutations.forget(postId);
    final newData = state.add(postId, false);
    state = newData;
  }

  void preloadInternal<T extends Post>(
    List<T> posts, {
    bool Function(T post)? selfFavorited,
  }) {
    final data = state.unlock;

    for (final post in posts) {
      final favorited = selfFavorited != null ? selfFavorited(post) : false;
      _mutations.forget(post.id);
      data[post.id] = favorited;
    }

    state = data.lock;
  }
}
