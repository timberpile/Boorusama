import 'dart:async';
import 'dart:typed_data';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:extended_image/src/dio_extended_image_provider.dart';
import 'package:extended_image/src/shared_image_read.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'preload and real foreground provider share pending transport/write',
    () async {
      final cache = _Cache();
      final dio = Dio();
      final requested = Completer<void>();
      final response = Completer<void>();
      var calls = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            calls++;
            if (!requested.isCompleted) requested.complete();
            await response.future;
            handler.resolve(
              Response<List<int>>(requestOptions: options, data: [1, 2, 3]),
            );
          },
        ),
      );
      final preload = ImagePreloader(
        cacheManager: cache,
        dio: dio,
      ).preloadImage('https://images.test/a.png', propagateErrors: true);
      await requested.future;
      final foreground = DioExtendedNetworkImageProvider(
        'https://images.test/a.png',
        dio: dio,
        cache: true,
        cacheManager: cache,
      ).getNetworkImageData();
      await cache.foregroundRead.future;
      response.complete();
      expect(await foreground, [1, 2, 3]);
      await preload;
      expect(calls, 1);
      expect(cache.writes, 1);
      dio.close(force: true);
    },
  );
  test('one cancelled image observer leaves the other flight alive', () async {
    final cache = _Cache();
    final dio = Dio();
    final firstToken = CancelToken();
    final response = Completer<Uint8List?>();
    CancelToken? transport;
    var calls = 0;
    Future<Uint8List?> read(CancelToken? token) => SharedImageRead.run(
      dio: dio,
      manager: cache,
      key: 'key',
      headers: null,
      owner: token,
      load: (cancel) {
        calls++;
        transport = cancel;
        return response.future;
      },
    );
    final first = read(firstToken);
    final cancelled = expectLater(first, throwsA(isA<DioException>()));
    final second = read(null);
    firstToken.cancel();
    await cancelled;
    expect(transport!.isCancelled, isFalse);
    response.complete(Uint8List.fromList([1]));
    expect(await second, [1]);
    expect(calls, 1);
  });
}

class _Cache implements ImageCacheManager {
  final foregroundRead = Completer<void>();
  Uint8List? bytes;
  var writes = 0;
  @override
  String generateCacheKey(String url, {String? customKey}) => customKey ?? url;
  @override
  bool hasValidCache(String key, {Duration? maxAge}) => bytes != null;
  @override
  Uint8List? getCachedFileBytes(String key, {Duration? maxAge}) {
    if (!foregroundRead.isCompleted) foregroundRead.complete();
    return bytes;
  }

  @override
  Future<void> saveFile(String key, Uint8List value) async {
    writes++;
    bytes = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
