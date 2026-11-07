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
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/images/booru_image_candidates.dart';
import 'package:boorusama/core/images/image_candidate_picker.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/posts/details/src/widgets/progressive_post_image.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/info/device_info.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../posts/details/progressive_image_test_utils.dart' as helpers;

class _Adapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(helpers.targetPng, 200);
}

class _Cache implements ImageCacheManager {
  var operations = 0;
  @override
  String generateCacheKey(String url, {String? customKey}) {
    operations++;
    return customKey ?? url;
  }

  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) {
    operations++;
    return null;
  }

  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) {
    operations++;
    return null;
  }

  @override
  FutureOr<bool> hasValidCache(String key, {Duration? maxAge}) {
    operations++;
    return false;
  }

  @override
  Future<void> saveFile(String key, Uint8List bytes) async {
    operations++;
  }

  @override
  Future<void> clearCache(String key) async {
    operations++;
  }

  @override
  Future<void> clearAllCache() async {
    operations++;
  }

  @override
  void invalidateCacheDirectory() {
    operations++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  const safe = 'https://safebooru.donmai.us/image.jpg';
  const unsafe = 'https://other.example.test/image.jpg';
  final source = const AnonymousSourcePolicy().resolve(
    BooruType.danbooru,
    Uri.parse('https://safebooru.donmai.us'),
  )!;
  ContentAccessKey key(int epoch) => ContentAccessKey(
    engine: BooruType.danbooru,
    siteNamespace: source.site.host,
    authEpoch: epoch,
    policyEpoch: 1,
  );
  AnonymousReadScope scope(ContentAccessKey key) => AnonymousReadScope(
    source: source,
    key: key,
    createDio: () => throw StateError('Unexpected transport'),
    current: () => true,
  );
  BooruConfig config(AnonymousReadScope scope) => BooruConfig.fromJson({
    ...BooruConfig.empty.toJson(),
    'id': '11111111-1111-4111-8111-111111111111',
    'booruId': BooruType.danbooru.id,
    'booruIdHint': BooruType.danbooru.id,
    'url': source.site.toString(),
  }).copyWith(anonymousReadScope: scope);
  List<Widget> widgets(BooruConfigAuth auth, String url, _Cache cache) => [
    BooruImage(
      config: auth,
      imageUrl: url,
      imageCacheManager: cache,
      cachedImageBytes: Uint8List.fromList([1, 2, 3]),
    ),
    BooruImageCandidates(
      config: auth,
      urls: [url],
      imageCacheManager: cache,
      placeholder: const SizedBox(key: ValueKey('candidate-placeholder')),
      builder: (_) => const SizedBox(),
    ),
    ProgressivePostImage(
      mediaIdentity: 'test',
      config: auth,
      imageUrl: url,
      lowerMedia: GridThumbnailMedia(url: url, aspectRatio: 1),
      aspectRatio: 1,
      geometryAspectRatio: 1,
      imageCacheManager: cache,
    ),
  ];

  testWidgets(
    'required missing access stops all image paths before cache or transport',
    (tester) async {
      final cache = _Cache();
      final auth = BooruConfig.empty.auth;
      final container = ProviderContainer(
        overrides: [
          automaticMediaLoadingEnabledProvider.overrideWithValue(true),
          contentAccessRequiredProvider.overrideWithValue(true),
          dioForWidgetProvider.overrideWith(
            (ref, auth) => throw StateError('Unexpected transport provider'),
          ),
          defaultImageCacheManagerProvider.overrideWith(
            (ref) => throw StateError('Unexpected cache provider'),
          ),
        ],
      );
      addTearDown(container.dispose);
      for (final child in widgets(auth, safe, cache)) {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: helpers.testApp(child),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(BooruRawImage), findsNothing);
        expect(find.byType(RawProgressivePostImage), findsNothing);
        expect(find.byType(ImageCandidatePicker), findsNothing);
        expect(cache.operations, 0);
      }
    },
  );

  testWidgets('public unsafe URL stops all paths before cache or transport', (
    tester,
  ) async {
    final cache = _Cache();
    final publicScope = scope(key(1));
    addTearDown(publicScope.dispose);
    final public = config(publicScope);
    final access = ContentAccessContext.anonymous(
      config: public,
      scope: publicScope,
    );
    final container = ProviderContainer(
      overrides: [
        automaticMediaLoadingEnabledProvider.overrideWithValue(true),
        contentAccessContextProvider.overrideWith((ref, key) => access),
        dioForWidgetProvider.overrideWith(
          (ref, auth) => throw StateError('Unexpected transport provider'),
        ),
        defaultImageCacheManagerProvider.overrideWith(
          (ref) => throw StateError('Unexpected cache provider'),
        ),
      ],
    );
    addTearDown(container.dispose);
    for (final child in widgets(public.auth, unsafe, cache)) {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: helpers.testApp(child),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(BooruRawImage), findsNothing);
      expect(find.byType(RawProgressivePostImage), findsNothing);
      expect(find.byType(ImageCandidatePicker), findsNothing);
      expect(cache.operations, 0);
    }
  });

  testWidgets('cached image bytes require their matching access key', (
    tester,
  ) async {
    final cache = _Cache();
    final publicScope = scope(key(1));
    addTearDown(publicScope.dispose);
    final public = config(publicScope);
    final access = ContentAccessContext.anonymous(
      config: public,
      scope: publicScope,
    );
    final wrongKey = key(2);
    final dio = Dio()..httpClientAdapter = _Adapter();
    addTearDown(() => dio.close(force: true));
    final container = ProviderContainer(
      overrides: [
        automaticMediaLoadingEnabledProvider.overrideWithValue(true),
        contentAccessContextProvider.overrideWith((ref, request) => access),
        dioForWidgetProvider.overrideWith((ref, auth) => dio),
        httpHeadersProvider.overrideWith((ref, auth) => const {}),
        defaultImageCacheManagerProvider.overrideWithValue(cache),
        imageListingSettingsProvider.overrideWithValue(
          Settings.defaultSettings.listing,
        ),
        deviceInfoProvider.overrideWithValue(const DeviceInfo()),
      ],
    );
    addTearDown(container.dispose);

    Future<Uint8List?> mount(
      BooruConfigAuth auth, {
      required ContentAccessKey? cachedKey,
      required Uint8List bytes,
    }) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: helpers.testApp(
            BooruImage(
              config: auth,
              imageUrl: safe,
              cachedImageBytes: bytes,
              cachedImageAccessKey: cachedKey,
              imageCacheManager: cache,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester
          .widget<BooruRawImage>(find.byType(BooruRawImage))
          .cachedImageBytes;
    }

    final bytes = Uint8List.fromList(helpers.targetPng);
    expect(
      await mount(public.auth, cachedKey: access.key, bytes: bytes),
      bytes,
    );
    expect(
      await mount(public.auth, cachedKey: wrongKey, bytes: bytes),
      isNull,
    );
    expect(
      await mount(BooruConfig.empty.auth, cachedKey: null, bytes: bytes),
      bytes,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'caller cache manager is scoped by access key and unsafe fallbacks are removed',
    (tester) async {
      final delegate = _Cache();
      final first = scope(key(1));
      final second = scope(key(2));
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final one = config(first);
      final two = config(second);
      final contexts = {
        first.key: ContentAccessContext.anonymous(config: one, scope: first),
        second.key: ContentAccessContext.anonymous(config: two, scope: second),
      };
      final dio = Dio()..httpClientAdapter = _Adapter();
      addTearDown(() => dio.close(force: true));
      final container = ProviderContainer(
        overrides: [
          automaticMediaLoadingEnabledProvider.overrideWithValue(true),
          contentAccessContextProvider.overrideWith(
            (ref, key) => contexts[key],
          ),
          dioForWidgetProvider.overrideWith((ref, auth) => dio),
          httpHeadersProvider.overrideWith((ref, auth) => const {}),
          defaultImageCacheManagerProvider.overrideWithValue(delegate),
          imageListingSettingsProvider.overrideWithValue(
            Settings.defaultSettings.listing,
          ),
          deviceInfoProvider.overrideWithValue(const DeviceInfo()),
        ],
      );
      addTearDown(container.dispose);
      Future<ImageCacheManager> mount(BooruConfig config) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: helpers.testApp(
              BooruImage(
                config: config.auth,
                imageUrl: safe,
                placeholderUrl: unsafe,
                fallbackUrl: unsafe,
                fallbackUrls: const [unsafe],
                imageCacheManager: delegate,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final raw = tester.widget<BooruRawImage>(find.byType(BooruRawImage));
        expect(raw.placeholderUrl, isNull);
        expect(raw.fallbackUrl, isNull);
        expect(raw.fallbackWidget, isNull);
        expect(raw.cachedImageBytes, isNull);
        return raw.imageCacheManager!;
      }

      final manager1 = await mount(one);
      final k1 = manager1.generateCacheKey(safe);
      final manager2 = await mount(two);
      final k2 = manager2.generateCacheKey(safe);
      expect(k1, isNot(k2));
      expect(k1, isNot(delegate.generateCacheKey(safe)));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: helpers.testApp(
            ProgressivePostImage(
              mediaIdentity: 'progressive',
              config: two.auth,
              imageUrl: safe,
              lowerMedia: const GridThumbnailMedia(
                url: unsafe,
                aspectRatio: 1,
                placeholderUrl: unsafe,
                fallbackUrl: unsafe,
                fallbackUrls: [unsafe],
              ),
              intermediateImageUrls: const [unsafe],
              aspectRatio: 1,
              geometryAspectRatio: 1,
              imageCacheManager: delegate,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final progressive = tester.widget<RawProgressivePostImage>(
        find.byType(RawProgressivePostImage),
      );
      expect(progressive.lowerMedia.url, isEmpty);
      expect(progressive.lowerMedia.placeholderUrl, isNull);
      expect(progressive.lowerMedia.fallbackUrl, isNull);
      expect(progressive.lowerMedia.fallbackUrls, isEmpty);
      expect(progressive.intermediateImageUrls, isEmpty);
      expect(progressive.cacheManager.generateCacheKey(safe), k2);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: helpers.testApp(
            BooruImageCandidates(
              config: two.auth,
              urls: const [unsafe, safe],
              placeholder: const SizedBox(),
              builder: (_) => const SizedBox(),
              imageCacheManager: delegate,
            ),
          ),
        ),
      );
      final picker = tester.widget<ImageCandidatePicker>(
        find.byType(ImageCandidatePicker),
      );
      expect(picker.candidates, hasLength(1));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'foreign image and progressive requests use stripped separate transport',
    (tester) async {
      final cache = _Cache();
      final auth = BooruConfig.empty
          .copyWith(url: 'https://source.example.test:8443/install/')
          .auth;
      final sourceDio = Dio()..httpClientAdapter = _Adapter();
      final foreignDio = Dio()..httpClientAdapter = _Adapter();
      addTearDown(() {
        sourceDio.close(force: true);
        foreignDio.close(force: true);
      });
      final container = ProviderContainer(
        overrides: [
          automaticMediaLoadingEnabledProvider.overrideWithValue(true),
          dioForWidgetProvider(auth).overrideWithValue(sourceDio),
          mediaOverrideDioProvider(auth).overrideWithValue(foreignDio),
          httpHeadersProvider(auth).overrideWithValue({
            'Authorization': 'Basic secret',
            'Cookie': 'secret',
            'Referer': 'https://source.example.test/private',
            'User-Agent': 'fixture',
          }),
          defaultImageCacheManagerProvider.overrideWithValue(cache),
          imageListingSettingsProvider.overrideWithValue(
            Settings.defaultSettings.listing,
          ),
          deviceInfoProvider.overrideWithValue(const DeviceInfo()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: helpers.testApp(
            BooruImage(
              config: auth,
              imageUrl: unsafe,
              imageCacheManager: cache,
            ),
          ),
        ),
      );
      final image = tester.widget<BooruRawImage>(find.byType(BooruRawImage));
      expect(identical(image.dio, foreignDio), isTrue);
      expect(image.headers, {'User-Agent': 'fixture'});
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: helpers.testApp(
            ProgressivePostImage(
              mediaIdentity: 'foreign',
              config: auth,
              imageUrl: unsafe,
              lowerMedia: const GridThumbnailMedia(url: '', aspectRatio: 1),
              aspectRatio: 1,
              geometryAspectRatio: 1,
              imageCacheManager: cache,
            ),
          ),
        ),
      );
      final progressive = tester.widget<RawProgressivePostImage>(
        find.byType(RawProgressivePostImage),
      );
      final request = progressive.resolveRequest!(unsafe);
      expect(identical(request.dio, foreignDio), isTrue);
      expect(request.headers, {'User-Agent': 'fixture'});
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
