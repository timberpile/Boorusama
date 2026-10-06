import 'dart:async';
import 'dart:io';

import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final kind in ['normal', 'avif']) {
    for (final blocked in [
      'cacheimage-index',
      'cacheimage-transfers',
      'cacheimage',
    ]) {
      for (final cached in [false, true]) {
        if (cached && blocked == 'cacheimage') continue;
        test(
          '$kind decodes ${cached ? "existing" : "network"} bytes with cold $blocked blockage',
          () async {
            final root = await Directory.systemTemp.createTemp(
              'cold-image-cache-',
            );
            final marker = File('${root.path}/$blocked');
            await marker.writeAsBytes([7, 8, 9]);
            final cache = DefaultImageCacheManager(
              cacheRootPathProvider: () => root.path,
            );
            final bytes = await File(
              kind == 'avif'
                  ? 'test/fixtures/red.avif'
                  : '../../test/fixtures/post_quality/lower.png',
            ).readAsBytes();
            final url =
                'https://cold.test/image.${kind == "avif" ? "avif" : "png"}';
            final key = cache.generateCacheKey(url);
            if (cached) {
              final file = File('${root.path}/cacheimage/$key');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes);
            }
            final transport = _Transport(bytes);
            final dio = Dio()..httpClientAdapter = transport;
            final image = ExtendedImage.network(
              url,
              dio: dio,
              cacheManager: cache,
              platform: TargetPlatform.linux,
            ).image;
            try {
              await _decode(
                image,
                kind == 'avif' ? [255, 0, 1, 255] : [255, 0, 0, 255],
              );
              expect(transport.requests, cached ? 0 : 1);
              expect(await marker.readAsBytes(), [7, 8, 9]);
              if (cached) expect(await cache.getCachedFileBytes(key), bytes);
            } finally {
              await image.evict();
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();
              dio.close(force: true);
              try {
                await cache.dispose();
              } on FileSystemException {
                // The injected payload-root blockage also prevents disposal.
              }
              await root.delete(recursive: true);
            }
          },
        );
      }
    }
  }
}

Future<void> _decode(ImageProvider provider, List<int> expectedPixel) async {
  final stream = provider.resolve(ImageConfiguration.empty);
  final done = Completer<void>();
  late ImageStreamListener listener;
  listener = ImageStreamListener((info, _) async {
    try {
      expect(
        (await info.image.toByteData())!.buffer.asUint8List().take(4),
        expectedPixel,
      );
      done.complete();
    } catch (error, stack) {
      done.completeError(error, stack);
    } finally {
      info.dispose();
    }
  }, onError: done.completeError);
  stream.addListener(listener);
  try {
    await done.future;
  } finally {
    stream.removeListener(listener);
  }
}

class _Transport implements HttpClientAdapter {
  _Transport(this.bytes);
  final Uint8List bytes;
  var requests = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    expect(options.extra['boorusama.request.media'], true);
    return ResponseBody.fromBytes(bytes, 200);
  }

  @override
  void close({bool force = false}) {}
}
