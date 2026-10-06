// Package imports:
import 'package:booru_clients/sankaku.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/posts/favorites/src/types/favorite_mutation_tracker.dart';
import '../client_provider.dart';
import '../posts/types.dart';

final sankakuFavoritesProvider =
    NotifierProvider.family<
      SankakuFavoritesNotifier,
      IMap<SankakuId, bool>,
      BooruConfigAuth
    >(SankakuFavoritesNotifier.new);

final sankakuFavoriteProvider = Provider.autoDispose
    .family<bool, (BooruConfigAuth, SankakuId)>(
      (ref, params) {
        final (config, postId) = params;
        return ref.watch(sankakuFavoritesProvider(config))[postId] ?? false;
      },
    );

final sankakuCanFavoriteProvider = Provider.family<bool, BooruConfigAuth>((
  ref,
  config,
) {
  final url = config.url.toLowerCase();
  final isIdol = url.contains('idol.') || url.contains('idolcomplex');

  if (isIdol) return false;

  final login = config.login;
  final password = config.apiKey;

  return login != null &&
      login.isNotEmpty &&
      password != null &&
      password.isNotEmpty;
});

class SankakuFavoritesNotifier
    extends FamilyNotifier<IMap<SankakuId, bool>, BooruConfigAuth> {
  @override
  IMap<SankakuId, bool> build(BooruConfigAuth arg) {
    return <SankakuId, bool>{}.lock;
  }

  final _mutations = FavoriteMutationTracker<SankakuId>();

  SankakuClient get client => ref.read(sankakuClientProvider(arg));

  void preload(List<Post> posts) {
    final cache = state.unlock;

    for (final post in posts) {
      final id = post.sankakuId;

      if (id == null) continue;

      _mutations.forget(id);
      cache[id] = post.isFavorited;
    }

    state = cache.lock;
  }

  Future<void> add(SankakuId id) async {
    if (state[id] ?? false) return;
    final operation = _mutations.start(id, state[id], true);
    state = state.add(id, true);
    var acknowledged = false;
    try {
      acknowledged = await client.addToFavorites(postId: id);
    } finally {
      _finish(id, operation, acknowledged: acknowledged);
    }
  }

  Future<void> remove(SankakuId id) async {
    if (state[id] == false) return;
    final operation = _mutations.start(id, state[id], false);
    state = state.add(id, false);
    var acknowledged = false;
    try {
      acknowledged = await client.removeFromFavorites(postId: id);
    } finally {
      _finish(id, operation, acknowledged: acknowledged);
    }
  }

  void _finish(SankakuId id, int operation, {required bool acknowledged}) {
    final result = _mutations.finish(id, operation, acknowledged: acknowledged);
    if (result == null) return;
    final prior = result.favorite;
    state = prior == null ? state.remove(id) : state.add(id, prior);
  }
}
