import 'dart:convert';

import 'package:booru_clients/nhentai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tags/autocompletes/types.dart';
import '../search/query.dart';

import '../../../core/cache/persistent/providers.dart';
import '../../../core/cache/persistent_cache_store.dart';
import '../../../core/cache/hive_persistent_cache_store.dart';

final nhentaiTagStoreProvider = Provider<NhentaiPersistentTagStore>(
  (ref) => NhentaiPersistentTagStore(ref.watch(persistentCacheStoreProvider)),
);

/// Bounded source metadata in the existing app cache, separate from portable
/// Bookmarks. Fixed shards keep visible lookups from decoding a whole catalog.
final class NhentaiPersistentTagStore
    implements NhentaiTagStore, NhentaiTagStoreSerializationOwner {
  NhentaiPersistentTagStore(this.cache);
  final PersistentCacheStore cache;
  @override
  Object get serializationOwner => switch (cache) {
    HivePersistentCacheStore(:final box) => box,
    _ => cache,
  };
  static const _shards = 64;
  static const _shardLimit = 512;
  static const _checkpointKey = 'nhentai-tags-v1/checkpoints';
  String _key(int shard) => 'nhentai-tags-v1/tags/$shard';

  Future<List<AutocompleteData>> suggest(String prefix, String? type) {
    final snapshots = [
      for (var shard = 0; shard < _shards; shard++) ?cache.get(_key(shard)),
    ];
    return compute(_suggest, (
      shards: snapshots,
      text: prefix,
      category: type,
    ));
  }

  void _require(Uri source) {
    if (source != NhentaiTagCache.source) {
      throw const FormatException('Foreign nhentai tag store');
    }
  }

  Map<String, dynamic> _object(String key) {
    final raw = cache.get(key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid cached nhentai metadata');
    }
    return decoded;
  }

  @override
  Future<Map<int, NhentaiTag>> readTags(Uri source, Set<int> ids) async {
    _require(source);
    final buckets = <int, Map<String, dynamic>>{};
    return {
      for (final id in ids)
        if (buckets.putIfAbsent(
              id % _shards,
              () => _object(_key(id % _shards)),
            )['$id']
            case final Map<String, dynamic> data)
          id: NhentaiTag.fromJson(data),
    };
  }

  @override
  Future<void> upsertTags(Uri source, List<NhentaiTag> tags) async {
    _require(source);
    final changed = <int, Map<String, dynamic>>{};
    for (final tag in tags) {
      final shard = tag.id % _shards;
      final values = changed.putIfAbsent(shard, () => _object(_key(shard)));
      values.remove('${tag.id}');
      values['${tag.id}'] = {
        'id': tag.id,
        'type': tag.type,
        'name': tag.name,
        'count': ?tag.count,
        'slug': ?tag.slug,
      };
      while (values.length > _shardLimit) {
        values.remove(values.keys.first);
      }
    }
    for (final entry in changed.entries) {
      await cache.put(_key(entry.key), jsonEncode(entry.value));
    }
  }

  @override
  Future<NhentaiTagCheckpoint?> readCheckpoint(
    Uri source,
    String category,
    String sort,
  ) async {
    _require(source);
    final value = _object(_checkpointKey)['$category/$sort'];
    if (value == null) return null;
    if (value is! Map<String, dynamic> ||
        value['seenIds'] is! List ||
        value['category'] != category ||
        value['sort'] != sort ||
        value['observedAt'] is! String) {
      throw const FormatException('Invalid nhentai tag checkpoint');
    }
    return NhentaiTagCheckpoint(
      category: category,
      sort: sort,
      nextPage: value['nextPage'] as int?,
      observedAt: DateTime.parse(value['observedAt'] as String),
      seenIds: (value['seenIds'] as List).cast<int>().toSet(),
      observedTotal: value['observedTotal'] as int?,
      observedPageCount: value['observedPageCount'] as int?,
      catalogChanged: value['catalogChanged'] == true,
    );
  }

  @override
  Future<void> writeCheckpoint(Uri source, NhentaiTagCheckpoint state) async {
    _require(source);
    final values = _object(_checkpointKey);
    final key = '${state.category}/${state.sort}';
    values.remove(key);
    values[key] = {
      'category': state.category,
      'sort': state.sort,
      'nextPage': state.nextPage,
      'observedAt': state.observedAt.toUtc().toIso8601String(),
      // This remains partial coverage; keeping the most recent IDs bounds
      // storage while preserving repeated-page detection across nearby pages.
      'seenIds': state.seenIds
          .skip(
            (state.seenIds.length - _shards * _shardLimit).clamp(
              0,
              state.seenIds.length,
            ),
          )
          .toList(),
      'observedTotal': state.observedTotal,
      'observedPageCount': state.observedPageCount,
      'catalogChanged': state.catalogChanged,
    };
    while (values.length > 32) {
      values.remove(values.keys.first);
    }
    await cache.put(_checkpointKey, jsonEncode(values));
  }
}

List<AutocompleteData> _suggest(
  ({List<String> shards, String text, String? category}) request,
) {
  final category = request.category;
  final prefix = request.text.toLowerCase();
  if (prefix.isEmpty) return const [];
  final matches = <NhentaiTag>[];
  for (final shard in request.shards) {
    final records = jsonDecode(shard) as Map<String, dynamic>;
    for (final record in records.values) {
      final tag = NhentaiTag.fromJson(record as Map<String, dynamic>);
      if ((category == null || tag.type == category) &&
          tag.name.toLowerCase().startsWith(prefix)) {
        matches.add(tag);
      }
    }
  }
  matches.sort((a, b) {
    final aExact = a.name.toLowerCase() == prefix;
    final bExact = b.name.toLowerCase() == prefix;
    if (aExact != bExact) return aExact ? -1 : 1;
    final byCount = (b.count ?? 0).compareTo(a.count ?? 0);
    return byCount == 0 ? a.name.compareTo(b.name) : byCount;
  });
  return matches
      .take(NhentaiClient.tagSearchLimit)
      .map(nhentaiSuggestion)
      .toList();
}

AutocompleteData nhentaiSuggestion(NhentaiTag tag) => AutocompleteData(
  label: tag.name,
  value: nhentaiTagQuery(tag.name, tag.type),
  type: AutocompleteData.tag,
  category: tag.type,
  postCount: tag.count,
);
