import 'dart:async';
import 'dart:typed_data';

import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/core/http/client/src/data/source_media_http_adapter.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/images/media_diagnostics.dart';
import 'package:boorusama/core/posts/details/src/widgets/progressive_post_image.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../posts/details/progressive_image_test_utils.dart' as helpers;

void main() {
  test('final adapter failures report safe hosts/header presence and coalesce a broken timeline', () async {
    final logger = AppLogger(initialLevel: LogLevel.debug);
    final diagnostics = MediaDiagnostics(
      logger: logger,
      engine: 'pixiv',
      source: Uri.parse('https://pixiv.net/private?token=SOURCE_SECRET'),
    );
    final delegate = _Adapter(status: 403);
    final dio = Dio()
      ..httpClientAdapter = SourceMediaHttpClientAdapter(
        delegate: delegate,
        source: Uri.parse('https://pixiv.net'),
        current: () => true,
        diagnostics: diagnostics,
      );
    addTearDown(() {
      dio.close(force: true);
      logger.dispose();
    });
    for (var i = 0; i < 20; i++) {
      await expectLater(
        dio.get<List<int>>(
          'https://i.pximg.net/private-$i.png?token=SIGNED_SECRET',
          options: Options(
            headers: {
              'Referer': 'https://www.pixiv.net/',
              'Cookie': 'COOKIE_SECRET',
              'Authorization': 'Bearer AUTH_SECRET',
            },
            responseType: ResponseType.bytes,
            extra: const {'boorusama.request.media': true},
          ),
        ),
        throwsA(isA<DioException>()),
      );
    }
    expect(logger.logs, hasLength(1));
    final message = logger.dump();
    expect(message, contains('stage=request'));
    expect(message, contains('engine=pixiv'));
    expect(message, contains('destination_host=i.pximg.net'));
    expect(message, contains('http_status=403'));
    expect(message, contains('referer_present=true'));
    expect(message, contains('credential_headers_present=false'));
    expect(message, contains('request=media-'));
    expect(message, isNot(contains('SECRET')));
    expect(message, isNot(contains('/private')));
    expect(message, isNot(contains('https://')));
  });

  test(
    'revoked requests are cancellations rather than failed image diagnostics',
    () async {
      final logger = AppLogger(initialLevel: LogLevel.debug);
      final diagnostics = MediaDiagnostics(logger: logger, engine: 'pixiv');
      final dio = Dio()
        ..httpClientAdapter = SourceMediaHttpClientAdapter(
          delegate: _Adapter(status: 200),
          source: Uri.parse('https://pixiv.net'),
          current: () => false,
          diagnostics: diagnostics,
        );
      addTearDown(() {
        dio.close(force: true);
        logger.dispose();
      });
      await expectLater(
        dio.get(
          'https://i.pximg.net/image.png?token=SECRET',
          options: Options(extra: const {'boorusama.request.media': true}),
        ),
        throwsA(isA<DioException>()),
      );
      expect(logger.logs, hasLength(1));
      expect(logger.logs.single.level, LogLevel.debug);
      expect(logger.dump(), contains('outcome=cancelled'));
      expect(logger.dump(), isNot(contains('outcome=failed')));
      expect(logger.dump(), isNot(contains('SECRET')));
    },
  );

  for (final progressive in [false, true]) {
    testWidgets(
      '${progressive ? 'progressive' : 'ordinary'} cached corrupt bytes report actual decode failure without cache removal',
      (tester) async {
        final logger = AppLogger();
        final diagnostics = MediaDiagnostics(
          logger: logger,
          engine: 'pixiv',
          source: Uri.parse('https://pixiv.net'),
        );
        final logged = Completer<void>();
        logger.addListener(() {
          if (!logged.isCompleted &&
              logger.logs.any((log) => log.message.contains('stage=decode'))) {
            logged.complete();
          }
        });
        const url = 'https://i.pximg.net/private.png?token=SECRET';
        final cache = _Cache({
          url: Uint8List.fromList([0, 1, 2, 3]),
        });
        final delegate = _Adapter(status: 500);
        final dio = Dio()..httpClientAdapter = delegate;
        addTearDown(() {
          dio.close(force: true);
          logger.dispose();
        });
        await tester.pumpWidget(
          helpers.testApp(
            progressive
                ? RawProgressivePostImage(
                    dio: dio,
                    imageUrl: url,
                    lowerMedia: const GridThumbnailMedia(
                      url: '',
                      aspectRatio: 1,
                    ),
                    aspectRatio: 1,
                    geometryAspectRatio: 1,
                    cacheManager: cache,
                    diagnostics: diagnostics,
                  )
                : BooruRawImage(
                    dio: dio,
                    imageUrl: url,
                    cachedImageBytes: cache.bytes[url],
                    imageCacheManager: cache,
                    diagnostics: diagnostics,
                  ),
          ),
        );
        await tester.pump();
        await tester.runAsync(
          () => helpers.pumpUntil(
            tester,
            () => logged.isCompleted,
            reason: 'decoder diagnostic (${logger.dump()})',
          ),
        );
        await tester.pump();
        final message = logger.dump();
        expect(message, contains('stage=decode'));
        expect(
          message,
          contains(
            progressive ? 'cache_entry=present' : 'cache_entry=supplied_bytes',
          ),
        );
        expect(message, isNot(contains('SECRET')));
        expect(message, isNot(contains('/private')));
        expect(delegate.requests, 0);
        expect(cache.clears, 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter({required this.status});
  final int status;
  var requests = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    return ResponseBody.fromBytes([1], status);
  }

  @override
  void close({bool force = false}) {}
}

class _Cache implements ImageCacheManager {
  _Cache(this.bytes);
  final Map<String, Uint8List> bytes;
  var clears = 0;
  @override
  String generateCacheKey(String url, {String? customKey}) => customKey ?? url;
  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) =>
      bytes[key];
  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) => null;
  @override
  FutureOr<bool> hasValidCache(String key, {Duration? maxAge}) =>
      bytes.containsKey(key);
  @override
  Future<void> saveFile(String key, Uint8List data) async => bytes[key] = data;
  @override
  Future<void> clearCache(String key) async {
    clears++;
    bytes.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
