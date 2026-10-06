import 'dart:io';
import 'dart:typed_data';

import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/src/cached_network_avif_image.dart';
import 'package:extended_image/src/image_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory cacheRoot;
  late DefaultImageCacheManager cacheManager;

  setUp(() async {
    cacheRoot = await Directory.systemTemp.createTemp('extended_image_avif_');
    cacheManager = DefaultImageCacheManager(
      cacheRootPathProvider: () => cacheRoot.path,
    );
  });

  tearDown(() async {
    await cacheManager.dispose();
    if (cacheRoot.existsSync()) {
      await cacheRoot.delete(recursive: true);
    }
  });

  test(
    'signed extensionless image and AVIF callers retain media purpose through retry transport',
    () async {
      final adapter = _MediaTransport();
      final dio = Dio()..httpClientAdapter = adapter;
      expect(
        await ImageFetcher.fetchImageBytes(
          url: 'https://example.com/signed?token=media',
          dio: dio,
        ),
        [1, 2, 3],
      );
      final provider = CustomCachedNetworkAvifImageProvider(
        'https://example.com/avif-signed?token=media',
        dio: dio,
        cacheManager: cacheManager,
      );
      expect(await provider.loadAvifSource(provider).bytes, [1, 2, 3]);
      expect(adapter.starts, 2);
    },
  );

  test('loads cached bytes and safely cancels the source', () async {
    const url = 'https://example.com/image.avif';
    final bytes = Uint8List.fromList(<int>[0, 1, 2, 3]);
    final cacheKey = cacheManager.generateCacheKey(url);
    await cacheManager.saveFile(cacheKey, bytes);
    final cancelToken = CancelToken();
    final provider = CustomCachedNetworkAvifImageProvider(
      url,
      dio: Dio(),
      cancelToken: cancelToken,
      cacheManager: cacheManager,
      cacheWidth: 320,
      cacheHeight: 240,
    );

    final source = provider.loadAvifSource(provider);

    expect(await source.bytes, orderedEquals(bytes));
    expect(await source.chunkEvents!.toList(), isEmpty);
    source.cancel?.call();
    expect(cancelToken.isCancelled, isTrue);
  });
}

final class _MediaTransport implements HttpClientAdapter {
  int starts = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    starts++;
    expect(options.extra['boorusama.request.media'], true);
    return ResponseBody.fromBytes([1, 2, 3], 200);
  }

  @override
  void close({bool force = false}) {}
}
