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

final _favoriteStatusLoaderProvider = FutureProvider.autoDispose
    .family<void, (BooruConfigAuth, int)>((ref, params) async {
      final (config, postId) = params;
      final status = ref.watch(favoriteStatusProvider(params));

      if (status != null ||
          !ref.watch(favoriteRepoProvider(config)).supportsFavoriteLookup) {
        return;
      }

      await ref.read(favoritesProvider(config).notifier).checkFavorites([
        postId,
      ]);
    });

final favoriteLookupPendingProvider = Provider.autoDispose
    .family<bool, (BooruConfigAuth, int)>((ref, params) {
      return ref.watch(favoriteStatusProvider(params)) == null &&
          ref.watch(favoriteRepoProvider(params.$1)).supportsFavoriteLookup &&
          ref.watch(_favoriteStatusLoaderProvider(params)).isLoading;
    });

final canFavoriteProvider = Provider.family<bool, BooruConfigAuth>((
  ref,
  config,
) {
  return ref.watch(favoriteRepoProvider(config)).canFavorite();
});

final favoriteNeedsWebsiteLoginProvider =
    Provider.family<bool, BooruConfigAuth>(
      (ref, config) =>
          ref.watch(favoriteRepoProvider(config)).needsWebsiteLogin,
    );

final class FavoriteRead {
  const FavoriteRead._(this._lifetime, this._mutationRevision, this._sequence);

  final Object? _lifetime;
  final int _mutationRevision;
  final int _sequence;
}

class FavoritesNotifier
    extends FamilyNotifier<IMap<int, bool>, BooruConfigAuth> {
  @override
  IMap<int, bool> build(BooruConfigAuth arg) {
    _lifetime = Object();
    _mutations = FavoriteMutationTracker<int>();
    _observedAt.clear();
    _mutatedAt.clear();
    ref.onDispose(() => _lifetime = null);
    return <int, bool>{}.lock;
  }

  Object? _lifetime;
  late FavoriteMutationTracker<int> _mutations;
  final _observedAt = <int, int>{};
  final _mutatedAt = <int, int>{};
  var _mutationRevision = 0;
  var _readSequence = 0;

  FavoriteRepository get repo => ref.read(favoriteRepoProvider(arg));

  /// Capture immediately before dispatching an authenticated source read.
  FavoriteRead beginRead() =>
      FavoriteRead._(_lifetime, _mutationRevision, ++_readSequence);

  void observeOwnFavorites(
    Iterable<int> postIds,
    FavoriteRead read, {
    required String owner,
    String? Function(BooruConfigAuth)? accountFromAuth,
  }) {
    if (!_accepts(read) || owner.isEmpty) return;
    final account = accountFromAuth == null ? arg.login : accountFromAuth(arg);
    if (owner != account) return;
    observeFavorites({for (final id in postIds) id: true}, read);
  }

  void observePostFavorites(Iterable<Post> posts, FavoriteRead read) {
    if (!_accepts(read)) return;
    final repository = repo;
    observeFavorites({
      for (final post in posts) post.id: ?repository.isPostFavorited(post),
    }, read);
  }

  /// Evidence from an account-specific response. Missing IDs stay unknown.
  void observeFavorites(Map<int, bool> observations, FavoriteRead read) {
    if (!_accepts(read)) return;

    var cache = state;
    for (final MapEntry(key: id, value: favorited) in observations.entries) {
      if (_mutations.isPending(id) ||
          (_mutatedAt[id] ?? 0) > read._mutationRevision ||
          (_observedAt[id] ?? 0) > read._sequence) {
        continue;
      }
      _observedAt[id] = read._sequence;
      if (cache[id] != favorited) cache = cache.add(id, favorited);
    }
    if (!identical(cache, state)) state = cache;
  }

  bool _accepts(FavoriteRead read) =>
      _lifetime != null &&
      identical(_lifetime, read._lifetime) &&
      arg.anonymousReadScope == null;

  Future<void> checkFavorites(List<int> postIds) async {
    final repository = repo;
    if (!repository.supportsFavoriteLookup || arg.anonymousReadScope != null) {
      return;
    }
    // Filter postIds not in cache
    final postIdsToCheck = postIds
        .where(
          (postId) =>
              !state.containsKey(postId) && !_mutations.isPending(postId),
        )
        .toSet()
        .toList();

    if (postIdsToCheck.isEmpty) return;

    final read = beginRead();
    final favoritedPosts = await repository.filterFavoritedPosts(
      postIdsToCheck,
    );
    if (favoritedPosts == null) return;
    final favoritedIds = favoritedPosts.toSet();
    if (favoritedIds.any((id) => !postIdsToCheck.contains(id))) return;
    observeFavorites({
      for (final id in postIdsToCheck) id: favoritedIds.contains(id),
    }, read);
  }

  Future<bool> setFavorite(
    int postId, {
    required bool favorited,
    String? profileId,
  }) async => favorited
      ? (await add(postId, profileId: profileId)).confirmed
      : remove(postId, profileId: profileId);

  Future<AddFavoriteStatus> add(int postId, {String? profileId}) async {
    final repository = _mutationRepo(profileId);
    if (repository.needsWebsiteLogin) {
      throw FavoriteActionFailure.websiteLoginRequired;
    }
    // Do not let an opposite command overtake a request already on the wire.
    if (!repository.canFavorite() || _mutations.isPending(postId)) {
      return AddFavoriteStatus.failure;
    }
    if (state[postId] ?? false) return AddFavoriteStatus.alreadyExists;
    final lifetime = _lifetime;
    _mutatedAt[postId] = ++_mutationRevision;
    final operation = _mutations.start(postId, state[postId], true);
    state = state.add(postId, true);
    var acknowledged = false;
    try {
      final status = await repository.addToFavorites(postId);
      acknowledged = status.confirmed;
      return status;
    } on FavoriteCompletedWithInterruption catch (error) {
      acknowledged = true;
      if (reportCompletedFavoriteInterruption(error)) {
        return AddFavoriteStatus.success;
      }
      rethrow;
    } finally {
      _finish(postId, operation, lifetime, acknowledged: acknowledged);
    }
  }

  Future<bool> remove(int postId, {String? profileId}) async {
    final repository = _mutationRepo(profileId);
    if (repository.needsWebsiteLogin) {
      throw FavoriteActionFailure.websiteLoginRequired;
    }
    if (!repository.canFavorite() || _mutations.isPending(postId)) return false;
    if (state[postId] == false) return true;
    final lifetime = _lifetime;
    _mutatedAt[postId] = ++_mutationRevision;
    final operation = _mutations.start(postId, state[postId], false);
    state = state.add(postId, false);
    var acknowledged = false;
    try {
      return acknowledged = await repository.removeFromFavorites(postId);
    } on FavoriteCompletedWithInterruption catch (error) {
      acknowledged = true;
      if (reportCompletedFavoriteInterruption(error)) return true;
      rethrow;
    } finally {
      _finish(postId, operation, lifetime, acknowledged: acknowledged);
    }
  }

  FavoriteRepository _mutationRepo(String? profileId) => profileId == null
      ? repo
      : ref.read(profileFavoriteRepoProvider((arg, profileId)));

  void _finish(
    int postId,
    int operation,
    Object? lifetime, {
    required bool acknowledged,
  }) {
    if (_lifetime == null || !identical(lifetime, _lifetime)) return;
    // A read can also start while the server mutation is pending.
    _mutatedAt[postId] = ++_mutationRevision;
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
    _mutatedAt[postId] = ++_mutationRevision;
    _mutations.forget(postId);
    final newData = state.add(postId, false);
    state = newData;
  }
}
