import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:booru_clients/anime_pictures.dart' as api;
import 'package:boorusama/boorus/anime-pictures/client_provider.dart';
import 'package:boorusama/boorus/anime-pictures/downloads/url_provider.dart';
import 'package:boorusama/boorus/anime-pictures/posts/media_dio_provider.dart';
import 'package:boorusama/boorus/anime-pictures/posts/post_codec.dart';
import 'package:boorusama/boorus/anime-pictures/posts/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final config = BooruConfig.defaultConfig(
    booruType: BooruType.animePictures,
    url: 'https://anime-pictures.test/',
    customDownloadFileNameFormat: null,
  );

  test('on-open resolution shares one detail response and redirect with downloads; cookies stay out of snapshots', () async {
    final adapter = _SourceAdapter(holdRedirect: true);
    final client = api.AnimePicturesClient(
      baseUrl: config.url,
      dio: Dio()..httpClientAdapter = adapter,
    );
    final container = ProviderContainer(
      overrides: [
        animePicturesClientProvider.overrideWith((ref, auth) => client),
      ],
    );
    addTearDown(container.dispose);
    final first = container.read(
      animePicturesResolvedPostProvider((config.auth, 12)).future,
    );
    final second = container.read(
      animePicturesResolvedPostProvider((config.auth, 12)).future,
    );
    await adapter.redirectStarted.future;
    final resolver = container.read(
      animePicturesDownloadFileUrlExtractorProvider(config.auth),
    );
    final download = resolver.resolveOriginal(12);
    expect(adapter.detailCalls, 1);
    expect(adapter.redirectCalls, 1);
    adapter.redirectGate.complete();
    final post = (await first)!;
    expect(await second, same(post));
    expect((await download)!.url, post.originalImageUrl);
    expect(adapter.detailCalls, 1);
    expect(adapter.redirectCalls, 1);
    expect(post.originalImageUrl, 'https://cdn.test/original.png');
    expect(post.sampleImageUrl, 'https://cdn.test/sample.avif');
    expect(post.uploaderName, 'Source uploader');
    expect(post.detailFacts.originalByteSize, 900);
    expect(post.detailFacts.originalWidth, 1200);
    expect(post.detailFacts.originalFormat, 'png');
    final snapshot = const StoredPostCodec().encode(
      post,
      dataCodec: const AnimePicturesPostCodec(),
    );
    expect(jsonEncode(snapshot.toJson()), isNot(contains('unit-only-ticket')));

    final media = _MediaAdapter();
    final dio = Dio(BaseOptions(headers: {'cookie': 'profile=first'}))
      ..httpClientAdapter = media
      ..interceptors.add(
        AnimePicturesMediaCookieInterceptor(resolver.cookieForMediaUrl),
      );
    await dio.get<void>(post.originalImageUrl);
    expect(media.cookies.last, contains('media_ticket=unit-only-ticket'));
    expect(media.cookies.last, contains('profile=first'));
    await dio.get<void>('https://other.test/original.png');
    expect(media.cookies.last, isNot(contains('unit-only-ticket')));
    resolver.cache.clear();
    await dio.get<void>(post.originalImageUrl);
    expect(media.cookies.last, isNot(contains('unit-only-ticket')));
    expect(
      adapter.redirectCalls,
      1,
    ); // A cache check never fetches media/metadata.
  });

  test('a denied Original preserves uploader and score without presenting preview properties as Original', () async {
    final adapter = _SourceAdapter(denyOriginal: true);
    final client = api.AnimePicturesClient(
      baseUrl: config.url,
      dio: Dio()..httpClientAdapter = adapter,
    );
    final container = ProviderContainer(
      overrides: [
        animePicturesClientProvider.overrideWith((ref, auth) => client),
      ],
    );
    addTearDown(container.dispose);
    final post = (await container.read(
      animePicturesResolvedPostProvider((config.auth, 12)).future,
    ))!;
    expect(post.originalImageUrl, post.sampleImageUrl);
    expect(post.uploaderName, 'Source uploader');
    expect(post.detailFacts.score, 0);
    expect(post.detailFacts.originalByteSize, isNull);
    expect(post.detailFacts.originalWidth, isNull);
    expect(post.detailFacts.originalFormat, isNull);
    expect(adapter.detailCalls, 1);
    expect(adapter.redirectCalls, 1);
  });

  test('identical post IDs under another auth configuration have independent resolutions and cookies', () async {
    final adapters = <BooruConfigAuth, _SourceAdapter>{};
    final container = ProviderContainer(
      overrides: [
        animePicturesClientProvider.overrideWith((ref, auth) {
          final adapter = _SourceAdapter();
          adapters[auth] = adapter;
          return api.AnimePicturesClient(
            baseUrl: auth.url,
            dio: Dio()..httpClientAdapter = adapter,
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    final other = BooruConfig.fromJson({
      ...config.toJson(),
      'id': '550e8400-e29b-41d4-a716-446655440010',
      'passHash': 'other-account',
    });
    await container.read(
      animePicturesResolvedPostProvider((config.auth, 12)).future,
    );
    final second = container.read(
      animePicturesDownloadFileUrlExtractorProvider(other.auth),
    );
    expect(second.cookieForMediaUrl('https://cdn.test/original.png'), isNull);
    await container.read(
      animePicturesResolvedPostProvider((other.auth, 12)).future,
    );
    expect(adapters, hasLength(2));
    expect(adapters.values.map((a) => a.detailCalls), everyElement(1));
  });
}

class _SourceAdapter implements HttpClientAdapter {
  _SourceAdapter({this.holdRedirect = false, this.denyOriginal = false});
  final bool holdRedirect;
  final bool denyOriginal;
  final redirectStarted = Completer<void>();
  final redirectGate = Completer<void>();
  var detailCalls = 0;
  var redirectCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.startsWith('/api/v3/posts/')) {
      detailCalls++;
      return ResponseBody.fromString(
        jsonEncode({
          'post': {
            'id': 12,
            'width': 1200,
            'height': 800,
            'size': 900,
            'ext': '.png',
            'score_number': 0,
            'big_preview': 'https://cdn.test/sample.avif',
          },
          'user': {'id': 3, 'name': 'Source uploader'},
          'file_url': '12-original.png',
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.uri.path.contains('/pictures/download_image/')) {
      redirectCalls++;
      if (!redirectStarted.isCompleted) redirectStarted.complete();
      if (holdRedirect) await redirectGate.future;
      return denyOriginal
          ? ResponseBody.fromString('denied', 403)
          : ResponseBody.fromString(
              '',
              307,
              headers: {
                'location': ['https://cdn.test/original.png'],
                'set-cookie': ['media_ticket=unit-only-ticket; Path=/'],
              },
            );
    }
    return ResponseBody.fromString('unexpected', 404);
  }

  @override
  void close({bool force = false}) {}
}

class _MediaAdapter implements HttpClientAdapter {
  final cookies = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    cookies.add(options.headers['cookie']?.toString() ?? '');
    return ResponseBody.fromString('', 200);
  }

  @override
  void close({bool force = false}) {}
}
