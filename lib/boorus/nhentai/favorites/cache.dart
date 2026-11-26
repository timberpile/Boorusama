import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/persistent/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/content/types.dart';

typedef NhentaiFavoriteState = ({Set<int> ids, Set<int> pending});
typedef NhentaiFavoriteOwner = ({String profileId, String fingerprint});

final nhentaiFavoriteCacheProvider =
    NotifierProvider.family<
      NhentaiFavoriteCache,
      NhentaiFavoriteState,
      NhentaiFavoriteOwner
    >(NhentaiFavoriteCache.new, dependencies: [persistentCacheStoreProvider]);

NhentaiFavoriteOwner nhentaiFavoriteOwner(ContentAccessContext access) => (
  profileId: access.key.profileId!,
  fingerprint: access.config!.auth.computeHash(),
);

final class NhentaiFavoritesRead {
  const NhentaiFavoritesRead._(this._lifetime, this._revision);

  final Object? _lifetime;
  final int _revision;
}

/// One in-memory index and ordered writer for each profile and account key.
class NhentaiFavoriteCache
    extends FamilyNotifier<NhentaiFavoriteState, NhentaiFavoriteOwner> {
  Object? _lifetime;
  var _revision = 0;
  final _confirmedAt = <int, int>{};
  Future<void> _writes = Future.value();

  String get _key => 'nhentai-favorites-v1/${arg.profileId}/${arg.fingerprint}';

  @override
  NhentaiFavoriteState build(NhentaiFavoriteOwner owner) {
    final store = ref.watch(persistentCacheStoreProvider);
    _lifetime = Object();
    _revision = 0;
    _confirmedAt.clear();
    ref.onDispose(() => _lifetime = null);
    try {
      final saved = store.get(_key);
      final decoded = saved == null ? null : jsonDecode(saved);
      if (decoded is List) {
        return (
          ids: Set.unmodifiable(decoded.whereType<int>().where((id) => id > 0)),
          pending: const {},
        );
      }
    } catch (_) {
      // The cache can be rebuilt from Favorites and confirmed changes.
    }
    return (ids: const {}, pending: const {});
  }

  NhentaiFavoritesRead beginRead() =>
      NhentaiFavoritesRead._(_lifetime, _revision);

  Future<void> observeFavorites(Iterable<int> ids, NhentaiFavoritesRead read) {
    if (_lifetime == null || !identical(_lifetime, read._lifetime)) {
      return Future.value();
    }
    final merged = {
      ...state.ids,
      for (final id in ids)
        if (!state.pending.contains(id) &&
            (_confirmedAt[id] ?? 0) <= read._revision)
          id,
    };
    if (merged.length == state.ids.length) return Future.value();
    return _replace(merged);
  }

  Future<bool> setFavorite(
    int id,
    bool favorited, {
    required Future<bool> Function() confirm,
  }) async {
    final lifetime = _lifetime;
    if (lifetime == null || state.pending.contains(id)) return false;
    if (state.ids.contains(id) == favorited) return true;
    state = (ids: state.ids, pending: Set.unmodifiable({...state.pending, id}));
    try {
      if (!await confirm() || !identical(_lifetime, lifetime)) return false;
      _confirmedAt[id] = ++_revision;
      final ids = {...state.ids};
      favorited ? ids.add(id) : ids.remove(id);
      await _replace(ids);
      return true;
    } finally {
      if (identical(_lifetime, lifetime)) {
        final pending = {...state.pending}..remove(id);
        state = (ids: state.ids, pending: Set.unmodifiable(pending));
      }
    }
  }

  Future<void> _replace(Set<int> ids) {
    state = (ids: Set.unmodifiable(ids), pending: state.pending);
    final store = ref.read(persistentCacheStoreProvider);
    final key = _key;
    return _writes = _writes.then((_) async {
      try {
        await store.put(key, jsonEncode(ids.toList()));
      } catch (_) {
        // A cache write cannot invalidate an acknowledged account change.
      }
    });
  }
}
