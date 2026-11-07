import 'dart:async';
import 'dart:typed_data';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/posts/media_preload/providers.dart';
import 'package:boorusama/core/posts/media_preload/types.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const site = 'https://safebooru.donmai.us';
const aId = '11111111-1111-4111-8111-111111111111';
const bId = '22222222-2222-4222-8222-222222222222';
const image = '$site/image.png';
final contexts = StateProvider<Map<ContentAccessKey, ContentAccessContext>>(
  (ref) => {},
);

class _Cache implements ImageCacheManager {
  final values = <String, Uint8List>{};
  var operations = 0;
  @override
  String generateCacheKey(String url, {String? customKey}) {
    operations++;
    return customKey ?? url;
  }

  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) {
    operations++;
    return values[key];
  }

  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) {
    operations++;
    return null;
  }

  @override
  FutureOr<bool> hasValidCache(String key, {Duration? maxAge}) {
    operations++;
    return values.containsKey(key);
  }

  @override
  Future<void> saveFile(String key, Uint8List bytes) async {
    operations++;
    values[key] = bytes;
  }

  @override
  Future<void> clearCache(String key) async {
    operations++;
    values.remove(key);
  }

  @override
  Future<void> clearAllCache() async {
    operations++;
    values.clear();
  }

  @override
  void invalidateCacheDirectory() {
    operations++;
  }

  @override
  Future<void> dispose() async {}
}

class _Adapter implements HttpClientAdapter {
  final started = Completer<void>();
  final cancelled = Completer<void>();
  final response = Completer<ResponseBody>();
  var requests = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests++;
    if (!started.isCompleted) started.complete();
    cancelFuture?.then((_) {
      if (!cancelled.isCompleted) cancelled.complete();
    });
    return response.future;
  }

  @override
  void close({bool force = false}) {}
}

BooruConfig profile(String id) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': id,
  'booruId': BooruType.danbooru.id,
  'booruIdHint': BooruType.danbooru.id,
  'url': site,
  'login': 'account',
  'apiKey': 'secret',
});
PreloadResult plan(String url) => PreloadResult(
  prioritizedUrls: [
    PrioritizedUrl(
      url: url,
      priority: 1,
      distance: 1,
      relevanceZone: RelevanceZone.immediate,
    ),
  ],
);
ProviderContainer _makeContainer(_Cache cache, Dio dio) => ProviderContainer(
  overrides: [
    contentAccessContextProvider.overrideWith(
      (ref, key) => ref.watch(contexts)[key],
    ),
    automaticMediaLoadingEnabledProvider.overrideWithValue(true),
    defaultImageCacheManagerProvider.overrideWithValue(cache),
    dioForWidgetProvider.overrideWith((ref, auth) => dio),
    mediaOverrideDioProvider.overrideWith((ref, auth) => dio),
    httpHeadersProvider.overrideWith((ref, auth) => const {}),
  ],
);

void main() {
  test(
    'actor namespaces differ and same key differs across app sessions',
    () async {
      final cache = _Cache();
      final dio = Dio()..httpClientAdapter = _Adapter();
      final one = _makeContainer(cache, dio);
      final two = _makeContainer(cache, dio);
      addTearDown(one.dispose);
      addTearDown(two.dispose);
      addTearDown(() => dio.close(force: true));
      final a = ContentAccessContext.profile(
        config: profile(aId),
        authEpoch: 1,
        policyEpoch: 1,
      );
      final b = ContentAccessContext.profile(
        config: profile(bId),
        authEpoch: 1,
        policyEpoch: 1,
      );
      final source = const AnonymousSourcePolicy().resolve(
        BooruType.danbooru,
        Uri.parse(site),
      )!;
      final publicKey = ContentAccessKey(
        engine: BooruType.danbooru,
        siteNamespace: source.site.host,
        authEpoch: 1,
        policyEpoch: 1,
      );
      final scope = AnonymousReadScope(
        source: source,
        key: publicKey,
        createDio: () => throw StateError('Unexpected client'),
        current: () => true,
      );
      addTearDown(scope.dispose);
      final public = profile(aId)
          .copyWith(anonymousReadScope: scope, login: '', apiKey: '');
      final publicContext = ContentAccessContext.anonymous(
        config: public,
        scope: scope,
      );
      one.read(contexts.notifier).state = {
        a.key: a,
        b.key: b,
        publicKey: publicContext,
      };
      two.read(contexts.notifier).state = {a.key: a};
      final ns = [
        one.read(contentMediaCacheNamespaceProvider(a.key)),
        one.read(contentMediaCacheNamespaceProvider(b.key)),
        one.read(contentMediaCacheNamespaceProvider(publicKey)),
        two.read(contentMediaCacheNamespaceProvider(a.key)),
      ];
      expect(ns.toSet(), hasLength(4));
      final firstProvider = contentMediaCacheManagerProvider((
        manager: cache,
        access: a.key,
      ));
      final firstHold = one.listen(firstProvider, (_, _) {});
      final secondHold = two.listen(firstProvider, (_, _) {});
      addTearDown(firstHold.close);
      addTearDown(secondHold.close);
      final first = one.read(firstProvider);
      final second = two.read(firstProvider);
      final firstKey = first.generateCacheKey(image);
      final secondKey = second.generateCacheKey(image);
      expect(firstKey, isNot(secondKey));
      await first.saveFile(firstKey, Uint8List.fromList([1]));
      expect(await second.getCachedFileBytes(secondKey), isNull);
    },
  );

  testWidgets('public unsafe URL has no transport or cache work', (
    tester,
  ) async {
    final cache = _Cache();
    final adapter = _Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final c = _makeContainer(cache, dio);
    addTearDown(c.dispose);
    addTearDown(() => dio.close(force: true));
    final source = const AnonymousSourcePolicy().resolve(
      BooruType.danbooru,
      Uri.parse(site),
    )!;
    final k = ContentAccessKey(
      engine: BooruType.danbooru,
      siteNamespace: source.site.host,
      authEpoch: 1,
      policyEpoch: 1,
    );
    final scope = AnonymousReadScope(
      source: source,
      key: k,
      createDio: () => dio,
      current: () => true,
    );
    addTearDown(scope.dispose);
    final public = profile(aId)
        .copyWith(anonymousReadScope: scope, login: '', apiKey: '');
    final context = ContentAccessContext.anonymous(
      config: public,
      scope: scope,
    );
    c.read(contexts.notifier).state = {k: context};
    final provider = contentPreloadManagerProvider((
      auth: public.auth,
      access: k,
    ));
    final hold = c.listen(provider, (_, _) {});
    addTearDown(hold.close);
    final manager = c.read(provider);
    manager.preloadMedias(plan('https://evil.example.test/image.png'));
    await tester.pump();
    expect(adapter.requests, 0);
    expect(cache.operations, 0);
    expect(cache.values, isEmpty);
  });

  for (final dispose in [false, true]) {
    test(
      'in-flight preload cannot write after ${dispose ? 'disposal' : 'revocation'}',
      () async {
        final cache = _Cache();
        final adapter = _Adapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final c = _makeContainer(cache, dio);
        addTearDown(c.dispose);
        addTearDown(() => dio.close(force: true));
        final config = profile(aId);
        final context = ContentAccessContext.profile(
          config: config,
          authEpoch: 1,
          policyEpoch: 1,
        );
        c.read(contexts.notifier).state = {context.key: context};
        final provider = contentPreloadManagerProvider((
          auth: config.auth,
          access: context.key,
        ));
        final hold = c.listen(provider, (_, _) {});
        final manager = c.read(provider);
        manager.preloadMedias(plan(image));
        await adapter.started.future.timeout(const Duration(seconds: 10));
        if (dispose) {
          hold.close();
          c.dispose();
        } else {
          c.read(contexts.notifier).state = {};
          c.read(contentAccessContextProvider(context.key));
        }
        adapter.response.complete(
          ResponseBody.fromBytes(Uint8List.fromList([1, 2, 3]), 200),
        );
        if (dispose) {
          await adapter.cancelled.future.timeout(const Duration(seconds: 10));
        }
        await Future.doWhile(() async {
          if (manager.state.activeDownloads.isEmpty) return false;
          await Future<void>.delayed(Duration.zero);
          return true;
        }).timeout(const Duration(seconds: 10));
        expect(cache.values, isEmpty);
        expect(manager.state.completedUrls, isNot(contains(image)));
        if (!dispose) hold.close();
        if (dispose) expect(adapter.cancelled.isCompleted, isTrue);
      },
    );
  }
}
