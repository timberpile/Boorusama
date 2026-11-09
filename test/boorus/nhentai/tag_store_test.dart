import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/boorus/nhentai/tags/store.dart';
import 'package:boorusama/core/cache/persistent_cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

class Cache implements PersistentCacheStore {
  final values = <String, String>{};
  bool fail = false;
  @override
  Iterable<String> get keys => values.keys;
  @override
  int get length => values.length;
  @override
  String? get(String key) => values[key];
  @override
  Future<void> put(String key, String value) async {
    if (fail) throw StateError('fixture write failed');
    values[key] = value;
  }

  @override
  Future<void> clear() async => values.clear();
}

void main() {
  test('existing persistent cache stores bounded tag shards and resumes checkpoints', () async {
    final cache = Cache();
    final store = NhentaiPersistentTagStore(cache);
    await store.upsertTags(NhentaiTagCache.source, [
      for (var i = 1; i <= 600; i++)
        NhentaiTag(id: i * 64, type: 'tag', name: 'fixture_$i'),
    ]);
    expect(cache.length, 1);
    final reopened = NhentaiPersistentTagStore(cache);
    final records = await reopened.readTags(NhentaiTagCache.source, {
      64,
      600 * 64,
    });
    expect(records.keys, {
      600 * 64,
    }, reason: 'Only oldest source cache entries are evicted');
    final state = NhentaiTagCheckpoint(
      category: 'tag',
      sort: 'popular',
      nextPage: 2,
      observedAt: DateTime.utc(2026, 11, 8),
      seenIds: {1, 2, 3},
      observedTotal: 120,
    );
    await store.writeCheckpoint(NhentaiTagCache.source, state);
    final saved = (await reopened.readCheckpoint(
      NhentaiTagCache.source,
      'tag',
      'popular',
    ))!;
    expect(saved.nextPage, 2);
    expect(saved.seenIds, {1, 2, 3});
    expect(saved.observedTotal, 120);
    cache.fail = true;
    await expectLater(
      store.writeCheckpoint(
        NhentaiTagCache.source,
        NhentaiTagCheckpoint(
          category: 'tag',
          sort: 'popular',
          nextPage: 3,
          observedAt: state.observedAt,
          seenIds: {1, 2, 3, 4},
        ),
      ),
      throwsStateError,
    );
    expect(
      (await reopened.readCheckpoint(
        NhentaiTagCache.source,
        'tag',
        'popular',
      ))!.nextPage,
      2,
    );
    expect(cache.length, 2);
  });
}
