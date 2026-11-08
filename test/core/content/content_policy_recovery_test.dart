import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/src/types/blacklisted_tag.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/content/content_policy_snapshot.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

const id = '11111111-1111-4111-8111-111111111111';
final config = BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': id,
  'booruId': BooruType.danbooru.id,
  'booruIdHint': BooruType.danbooru.id,
  'url': 'https://safebooru.donmai.us',
}).copyWith(localMediaGeneration: '22222222-2222-4222-8222-222222222222');

class _Store implements MiscDataStore {
  final data = <String, String>{};
  @override
  String? get(String key) => data[key];
  @override
  Future<void> put(String key, String value) async {
    data[key] = value;
  }
}

class _Global extends GlobalBlacklistedTagsNotifier {
  @override
  IList<BlacklistedTag> build() => <BlacklistedTag>[].lock;
}

ProviderContainer container(
  _Store store,
  Future<Set<String>> future, {
  BooruConfig? profile,
}) => ProviderContainer(
  overrides: [
    booruConfigProvider.overrideWith(
      () => BooruConfigNotifier(initialConfigs: [profile ?? config]),
    ),
    globalBlacklistedTagsProvider.overrideWith(_Global.new),
    miscDataStoreProvider.overrideWithValue(store),
    blacklistTagsProvider.overrideWith((ref, filter) => future),
  ],
);
void main() {
  test(
    'no previous policy fails closed while loading and on 503; retry recovers',
    () async {
      final gate = Completer<Set<String>>();
      final store = _Store();
      final c = container(store, gate.future);
      addTearDown(c.dispose);
      final hold = c.listen(contentProfileAccessProvider(id), (_, _) {});
      addTearDown(hold.close);
      expect(c.read(contentProfileAccessProvider(id)), isNull);
      gate.completeError(
        DioException(
          requestOptions: RequestOptions(),
          response: Response(requestOptions: RequestOptions(), statusCode: 503),
          type: DioExceptionType.badResponse,
        ),
      );
      await c.pump();
      expect(c.read(contentEffectiveBlacklistProvider(id)).hasError, isTrue);
      expect(c.read(contentProfileAccessProvider(id)), isNull);
    },
  );
  test('durable disk bytes decode after full container and cache recreation; policy and actor changes isolate', () async {
    final root = await Directory.systemTemp.createTemp('durable-content-');
    addTearDown(() => root.delete(recursive: true));
    final store = _Store();
    final first = container(store, Future.value({'blocked'}));
    final hold = first.listen(contentProfileAccessProvider(id), (_, _) {});
    await first.read(blacklistTagsProvider(config.filter).future);
    await first.pump();
    final access = first.read(contentProfileAccessProvider(id))!;
    final delegate = DefaultImageCacheManager(
      cacheRootPathProvider: () => root.path,
      cacheDirName: 'media',
    );
    final provider = contentMediaCacheManagerProvider((
      manager: delegate,
      access: access.key,
    ));
    final cacheHold = first.listen(provider, (_, _) {});
    final cache = first.read(provider);
    const url = 'https://safebooru.donmai.us/data/fixture.png';
    final key = cache.generateCacheKey(url);
    final namespace1 = first.read(
      contentMediaCacheNamespaceProvider(access.key),
    );
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGP6zwAAAgcBApocMXEAAAAASUVORK5CYII=',
    );
    await cache.saveFile(key, png);
    cacheHold.close();
    hold.close();
    first.dispose();
    await delegate.dispose();
    final gate = Completer<Set<String>>();
    final second = container(store, gate.future);
    addTearDown(second.dispose);
    final hold2 = second.listen(contentProfileAccessProvider(id), (_, _) {});
    addTearDown(hold2.close);
    final access2 = second.read(contentProfileAccessProvider(id))!;
    final delegate2 = DefaultImageCacheManager(
      cacheRootPathProvider: () => root.path,
      cacheDirName: 'media',
    );
    addTearDown(delegate2.dispose);
    final provider2 = contentMediaCacheManagerProvider((
      manager: delegate2,
      access: access2.key,
    ));
    final cacheHold2 = second.listen(provider2, (_, _) {});
    addTearDown(cacheHold2.close);
    final cache2 = second.read(provider2);
    expect(cache2.generateCacheKey(url), key);
    final bytes = await cache2.getCachedFileBytes(key);
    expect(bytes, png);
    final codec = await ui.instantiateImageCodec(bytes!);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 1);
    frame.image.dispose();
    codec.dispose();
    gate.complete({'new_block'});
    await second.pump();
    expect(second.read(contentAccessContextProvider(access2.key)), isNull);
    expect(await cache2.getCachedFileBytes(key), isNull);
    final current = second.read(contentProfileAccessProvider(id))!;
    expect(
      second.read(contentMediaCacheNamespaceProvider(current.key)),
      isNot(namespace1),
    );
    final changed = container(
      store,
      Future.value({'blocked'}),
      profile: config.copyWith(
        localMediaGeneration: '33333333-3333-4333-8333-333333333333',
      ),
    );
    addTearDown(changed.dispose);
    final h = changed.listen(contentProfileAccessProvider(id), (_, _) {});
    addTearDown(h.close);
    await changed.read(blacklistTagsProvider(config.filter).future);
    await changed.pump();
    final actor = changed.read(contentProfileAccessProvider(id))!;
    final changedProvider = contentMediaCacheManagerProvider((
      manager: delegate2,
      access: actor.key,
    ));
    final ch = changed.listen(changedProvider, (_, _) {});
    addTearDown(ch.close);
    expect(changed.read(changedProvider).generateCacheKey(url), isNot(key));
  });
  test('authorization rejection never reuses last-known policy', () async {
    final store = _Store();
    await ContentPolicySnapshotStore(store)
        .write(config.localMediaGeneration!, {'blocked'});
    final gate = Completer<Set<String>>();
    final c = container(store, gate.future);
    addTearDown(c.dispose);
    final h = c.listen(contentProfileAccessProvider(id), (_, _) {});
    addTearDown(h.close);
    expect(c.read(contentProfileAccessProvider(id)), isNotNull);
    gate.completeError(
      DioException(
        requestOptions: RequestOptions(),
        response: Response(requestOptions: RequestOptions(), statusCode: 403),
        type: DioExceptionType.badResponse,
      ),
    );
    await c.pump();
    expect(c.read(contentProfileAccessProvider(id)), isNull);
  });
}
