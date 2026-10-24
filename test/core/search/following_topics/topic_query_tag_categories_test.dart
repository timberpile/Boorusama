import 'dart:async';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/following_topics/src/providers/topic_query_tag_categories_provider.dart';
import 'package:boorusama/core/tags/categories/providers.dart';
import 'package:boorusama/core/tags/categories/types.dart';
import 'package:boorusama/core/tags/local/types.dart';
import 'package:boorusama/core/tags/tag/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final auth = BooruConfig.empty.auth;
  test(
    'cold cache never opens a remote repository solely for colors',
    () async {
      var remoteAccesses = 0;
      final container = ProviderContainer(
        overrides: [
          booruTagTypeProvider.overrideWith((ref, key) async => null),
          tagRepoProvider.overrideWith((ref, key) {
            remoteAccesses++;
            throw StateError('presentation must stay local');
          }),
        ],
      );
      addTearDown(container.dispose);
      final provider = topicQueryTagCategoriesProvider((
        auth,
        'uncached_artist',
      ));
      final listener = container.listen(provider, (_, _) {});
      addTearDown(listener.close);
      expect(await container.read(provider.future), isEmpty);
      expect(remoteAccesses, 0);
    },
  );

  test('local categories are normalized and reused without writes or remote access', () async {
    final store = _Store();
    store.categories[(auth.url, 'artist_name')] = 'artist';
    store.categories[(auth.url, 'cached')] = 'general';
    store.categories[(auth.url, 'unknown')] = 'unknown';
    final container = ProviderContainer(
      overrides: [
        booruTagTypeStoreProvider.overrideWith((ref) async => store),
        tagRepoProvider.overrideWith(
          (ref, _) => throw StateError('must not fetch'),
        ),
      ],
    );
    addTearDown(container.dispose);
    const query =
        '-Artist_name ~artist_name cached unknown rating:safe source:"a_b" name*';
    final provider = topicQueryTagCategoriesProvider((auth, query));
    final listener = container.listen(provider, (_, _) {});
    addTearDown(listener.close);
    expect(await container.read(provider.future), {
      'Artist_name': 'artist',
      'artist_name': 'artist',
      'cached': 'general',
    });
    expect(
      store.lookups,
      containsAll([
        (auth.url, 'artist_name'),
        (auth.url, 'cached'),
        (auth.url, 'unknown'),
      ]),
    );
    expect(store.lookups.where((key) => key.$2 == 'artist_name'), hasLength(1));
    expect(
      store.lookups.every(
        (key) => !key.$2.contains(':') && !key.$2.contains('*'),
      ),
      isTrue,
    );
    final count = store.lookups.length;
    await container.read(provider.future);
    expect(store.lookups, hasLength(count));
    expect(store.saved, isEmpty);
    expect(
      query,
      '-Artist_name ~artist_name cached unknown rating:safe source:"a_b" name*',
    );
  });

  test(
    'failed cache preserves known metadata and leaves missing tags neutral',
    () async {
      var remoteAccesses = 0;
      final container = ProviderContainer(
        overrides: [
          booruTagTypeProvider.overrideWith((ref, key) async {
            if (key.$2 == 'cached') return 'artist';
            throw StateError('cache unavailable');
          }),
          tagRepoProvider.overrideWith((ref, _) {
            remoteAccesses++;
            throw StateError('must not fetch');
          }),
        ],
      );
      addTearDown(container.dispose);
      final provider = topicQueryTagCategoriesProvider((
        auth,
        'cached missing',
      ));
      final listener = container.listen(provider, (_, _) {});
      addTearDown(listener.close);
      expect(await container.read(provider.future), {'cached': 'artist'});
      expect(remoteAccesses, 0);
    },
  );

  test('profile-local cache results stay separate and disposal never writes metadata', () async {
    final second = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': '00000000-0000-4000-8000-000000000051',
      'url': 'https://other.example/',
    }).auth;
    final pending = Completer<String?>();
    final store = _Store();
    final container = ProviderContainer(
      overrides: [
        booruTagTypeStoreProvider.overrideWith((ref) async => store),
        booruTagTypeProvider.overrideWith(
          (ref, key) =>
              key.$1 == auth ? pending.future : Future.value('character'),
        ),
        tagRepoProvider.overrideWith(
          (ref, _) => throw StateError('must not fetch'),
        ),
      ],
    );
    final firstKey = topicQueryTagCategoriesProvider((auth, 'artist_name'));
    container.listen(firstKey, (_, _) {});
    final otherKey = topicQueryTagCategoriesProvider((second, 'artist_name'));
    container.listen(otherKey, (_, _) {});
    expect(await container.read(otherKey.future), {'artist_name': 'character'});
    container.dispose();
    pending.complete('artist');
    await pending.future;
    expect(store.saved, isEmpty);
  });

  test(
    'engine-default empty category remains available to its generator',
    () async {
      final container = ProviderContainer(
        overrides: [
          booruTagTypeProvider.overrideWith((ref, _) async => ''),
        ],
      );
      addTearDown(container.dispose);
      final provider = topicQueryTagCategoriesProvider((auth, 'normal_tag'));
      final listener = container.listen(provider, (_, _) {});
      addTearDown(listener.close);
      expect(await container.read(provider.future), {'normal_tag': ''});
    },
  );
}

class _Store implements TagTypeStore {
  final categories = <(String, String), String>{};
  final lookups = <(String, String)>[];
  final saved = <TagInfo>[];
  @override
  Future<String?> getTagCategory(String siteHost, String tagName) async {
    lookups.add((siteHost, tagName));
    return categories[(siteHost, tagName)];
  }

  @override
  Future<void> saveTag(TagInfo info) async => saved.add(info);
  @override
  Future<void> saveOrUpdateTagsBatch(List<TagInfo> infos) async =>
      saved.addAll(infos);
  @override
  Future<void> clear() async => categories.clear();
}
