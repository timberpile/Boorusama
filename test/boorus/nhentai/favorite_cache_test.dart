import 'dart:async';
import 'dart:io';

import 'package:boorusama/boorus/nhentai/favorites/cache.dart';
import 'package:boorusama/core/cache/hive_persistent_cache_store.dart';
import 'package:boorusama/core/cache/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../support/fakes/memory_repositories.dart';
import 'fixtures.dart';

const _apiKey = 'synthetic-gallery-api-key';

void main() {
  test(
    'Favorites pages persist across reopen and are isolated by account',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nhentai-favorites-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final config = galleryAccess().config!.copyWith(apiKey: _apiKey);
      final provider = nhentaiFavoriteCacheProvider(
        nhentaiFavoriteOwner(_access(config)),
      );

      Future<void> withCache(
        Future<void> Function(ProviderContainer) use,
      ) async {
        final box = await Hive.openBox<String>(
          'favorites',
          path: directory.path,
        );
        final store = HivePersistentCacheStore(box);
        final container = _container(store);
        try {
          await use(container);
          expect(store.keys.every((key) => !key.contains(_apiKey)), isTrue);
        } finally {
          container.dispose();
          await box.close();
        }
      }

      await withCache((container) async {
        final cache = container.read(provider.notifier);
        expect(container.read(provider).ids, isEmpty);
        await cache.observeFavorites([101, 102], cache.beginRead());
        await cache.observeFavorites([102, 103], cache.beginRead());
        expect(container.read(provider).ids, {101, 102, 103});
        expect(
          await cache.setFavorite(102, false, confirm: () async => true),
          isTrue,
        );
      });

      await withCache((container) async {
        expect(container.read(provider).ids, {101, 103});
        final otherProfile = BooruConfig.fromJson({
          ...config.toJson(),
          'id': '22222222-2222-4222-8222-222222222222',
        });
        final otherCredential = config.copyWith(
          apiKey: 'synthetic-replaced-key',
        );
        for (final other in [otherProfile, otherCredential]) {
          expect(
            container
                .read(
                  nhentaiFavoriteCacheProvider(
                    nhentaiFavoriteOwner(_access(other)),
                  ),
                )
                .ids,
            isEmpty,
          );
        }
      });
    },
  );

  test('a late Favorites page cannot restore a confirmed removal', () async {
    final container = _container(MemoryPersistentCacheStore());
    addTearDown(container.dispose);
    final provider = nhentaiFavoriteCacheProvider(
      nhentaiFavoriteOwner(
        _access(galleryAccess().config!.copyWith(apiKey: _apiKey)),
      ),
    );
    final cache = container.read(provider.notifier);
    await cache.observeFavorites([101], cache.beginRead());
    final olderRead = cache.beginRead();
    final remove = Completer<bool>();
    final removal = cache.setFavorite(101, false, confirm: () => remove.future);
    expect(container.read(provider).ids, {101});
    expect(container.read(provider).pending, {101});
    final readWhilePending = cache.beginRead();
    expect(
      await cache.setFavorite(
        101,
        false,
        confirm: () async => throw StateError('duplicate write'),
      ),
      isFalse,
    );
    remove.complete(true);
    expect(await removal, isTrue);
    await cache.observeFavorites([101, 102], olderRead);
    await cache.observeFavorites([101, 103], readWhilePending);
    expect(container.read(provider).ids, {102, 103});
    expect(container.read(provider).pending, isEmpty);

    expect(
      await cache.setFavorite(102, false, confirm: () async => false),
      isFalse,
    );
    expect(container.read(provider).ids, {102, 103});
    expect(container.read(provider).pending, isEmpty);
    await cache.observeFavorites([101], cache.beginRead());
    expect(container.read(provider).ids, {101, 102, 103});
  });
}

ContentAccessContext _access(BooruConfig config) =>
    ContentAccessContext.profile(config: config, authEpoch: 1, policyEpoch: 1);

ProviderContainer _container(PersistentCacheStore store) => ProviderContainer(
  overrides: [persistentCacheStoreProvider.overrideWithValue(store)],
);
