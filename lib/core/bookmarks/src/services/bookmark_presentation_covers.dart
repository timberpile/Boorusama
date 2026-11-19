import '../types/content_group_bookmark.dart';
import '../../../boorus/booru/types.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cache/persistent/providers.dart';
import '../../../cache/persistent_cache_store.dart';
import '../types/bookmark_library_state.dart';
import '../types/pool_bookmark.dart';
import '../types/pool_bookmark_cover.dart';

/// Receiver-owned presentation choices never enter signed payloads/read state.
/// Their durable identity excludes current account, policy and local tile sort.
String bookmarkPresentationCoverKey(
  BookmarkLibraryState library,
  CollectionBookmark pool,
) {
  final owners = [
    for (final id in pool.groupIds.toList()..sort())
      if (library.mirrors.owners[id] case final owner?)
        [owner.publisher, owner.source, owner.revision, owner.payloadDigest],
  ];
  return sha256
      .convert(
        utf8.encode(
          jsonEncode([
            pool.bookmarkId,
            pool.sourceTypeId,
            pool.origin.sourceHost,
            pool.isRelated,
            pool.referenceId,
            pool.observedAt.toUtc().toIso8601String(),
            owners,
          ]),
        ),
      )
      .toString();
}

String? nativeWorkPresentationCoverKey(
  BookmarkLibraryState library,
  ContentGroupBookmark bookmark,
) {
  if (bookmark.reference.engine != BooruType.pixiv) return null;
  final memberships = [
    for (final group in library.groups)
      if (group.bookmarkIds.contains(bookmark.id) &&
          library.mirrors.isReceived(group.id))
        group.id,
  ]..sort();
  final owners = [
    for (final id in memberships)
      if (library.mirrors.owners[id] case final owner?)
        [owner.publisher, owner.source, owner.revision, owner.payloadDigest],
  ];
  if (owners.isEmpty) return null;
  return sha256
      .convert(
        utf8.encode(
          jsonEncode([
            'pixiv-work',
            bookmark.id,
            bookmark.reference.siteNamespace,
            bookmark.reference.sourceKey,
            bookmark.observedAt.toIso8601String(),
            owners,
          ]),
        ),
      )
      .toString();
}

final bookmarkPresentationCoversProvider = Provider(
  (ref) => BookmarkPresentationCovers(ref.watch(persistentCacheStoreProvider)),
  dependencies: [persistentCacheStoreProvider],
);

class BookmarkPresentationCovers {
  BookmarkPresentationCovers(this.store);
  final PersistentCacheStore store;
  static const storageKey = 'bookmarkPresentationCovers';
  Future<void> _tail = Future.value();
  Map<String, dynamic>? _confirmed;
  bool _writeFailed = false;

  Map<String, dynamic> _read() => Map.of(_confirmed ??= _load());

  Map<String, dynamic> _load() {
    try {
      final raw = store.get(storageKey);
      return raw == null
          ? {}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  PoolBookmarkCover? selected(String key) {
    try {
      final wire = _read()[key];
      return wire == null
          ? null
          : PoolBookmarkCover.fromJson(Map<String, dynamic>.from(wire as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> remember(
    String key,
    PoolBookmarkCover cover, {
    required bool Function() current,
  }) => _enqueue(() async {
    if (!current()) return;
    final choices = _read();
    if (choices.containsKey(key) && !_writeFailed) return;
    choices.putIfAbsent(key, cover.toJson);
    if (current()) await _save(choices);
  });

  Future<void> retain(BookmarkLibraryState library) => _enqueue(() async {
    final valid = {
      for (final pool in library.pools)
        if (pool.groupIds.any(library.mirrors.isReceived))
          bookmarkPresentationCoverKey(library, pool),
      for (final bookmark
          in library.byId.values.whereType<ContentGroupBookmark>())
        if (nativeWorkPresentationCoverKey(library, bookmark) case final key?)
          key,
    };
    final choices = _read();
    final oldLength = choices.length;
    choices.removeWhere((key, _) => !valid.contains(key));
    if (_writeFailed || choices.length != oldLength) await _save(choices);
  });

  Future<void> _save(Map<String, dynamic> next) async {
    try {
      await store.put(storageKey, jsonEncode(next));
    } catch (_) {
      _writeFailed = true;
      rethrow;
    }
    _confirmed = Map.unmodifiable(next);
    _writeFailed = false;
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
