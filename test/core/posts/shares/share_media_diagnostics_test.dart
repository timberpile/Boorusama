import 'dart:io';

import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/core/posts/shares/src/share_media_preparation.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'staging-directory failure retains its OS cause without its path',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'share-storage-diagnostics-',
      );
      addTearDown(() => root.delete(recursive: true));
      await File('${root.path}/boorusama-share').writeAsString('blocked');
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      final service = ShareMediaPreparation(
        rootPath: root.path,
        dio: dio,
        cachedBytes: (_) async => null,
      );
      try {
        await service.prepare(
          url: 'https://private-host/private-file.png',
          kind: ShareMediaKind.original,
          fallbackExtension: 'png',
          headers: const {},
        );
        fail('Expected staging failure');
      } on ShareMediaException catch (error) {
        expect(error.failure, ShareMediaFailure.storage);
        expect(error.cause, isA<FileSystemException>());
        expect(error.stackTrace, isNotNull);
        final logger = AppLogger()
          ..handledError(
            'Media Share',
            'prepare_media:storage',
            error: error.cause!,
            stackTrace: error.stackTrace,
          );
        expect(logger.dump(), contains('os_error='));
        expect(logger.dump(), isNot(contains(root.path)));
        expect(logger.dump(), isNot(contains('private-')));
      }
    },
  );

  for (final managed in [false, true]) {
    for (final status in [403, 503]) {
      test('HTTP $status retains its cause with managed cache $managed', () async {
        final root = await Directory.systemTemp.createTemp(
          'share-diagnostics-',
        );
        addTearDown(() => root.delete(recursive: true));
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          request.response.statusCode = status;
          request.response.write('private-payload');
          await request.response.close();
        });
        final cache = managed
            ? DefaultImageCacheManager(cacheRootPathProvider: () => root.path)
            : null;
        if (cache != null) addTearDown(cache.dispose);
        final dio = Dio();
        addTearDown(() => dio.close(force: true));
        final service = ShareMediaPreparation(
          rootPath: root.path,
          dio: dio,
          cachedBytes: (_) async => null,
          imageCacheManager: cache,
        );
        try {
          await service.prepare(
            url:
                'http://127.0.0.1:${server.port}/private-path.png?token=private-token',
            kind: ShareMediaKind.original,
            fallbackExtension: 'png',
            headers: const {'Authorization': 'private-secret'},
          );
          fail('Expected HTTP failure');
        } on ShareMediaException catch (error) {
          expect(
            error.failure,
            status == 403
                ? ShareMediaFailure.authentication
                : ShareMediaFailure.network,
          );
          expect(
            error.cause,
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'status',
              status,
            ),
          );
          expect(error.stackTrace, isNotNull);
          final logger = AppLogger()
            ..handledError(
              'Media Share',
              'prepare_media:${error.failure.name}',
              error: error.cause!,
              stackTrace: error.stackTrace,
            );
          expect(logger.dump(), contains('http_status=$status'));
          expect(logger.dump(), isNot(contains('private-')));
        }
      });
    }
  }
}
