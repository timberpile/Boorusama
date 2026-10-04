import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/posts/shares/src/share_media_preparation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancelled download removes its partial temporary file', () async {
    final root = await Directory.systemTemp.createTemp('share-cancel-test-');
    addTearDown(() => root.delete(recursive: true));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.contentLength = 8192;
      request.response.add(List.filled(4096, 1));
      await request.response.flush();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      try {
        request.response.add(List.filled(4096, 2));
        await request.response.close();
      } on SocketException {
        // The client cancelled the response.
      }
    });
    final token = CancelToken();
    final service = ShareMediaPreparation(
      rootPath: root.path,
      dio: Dio(),
      cachedBytes: (_) async => null,
    );

    await expectLater(
      service.prepare(
        url: 'http://127.0.0.1:${server.port}/slow.jpg',
        kind: ShareMediaKind.image,
        fallbackExtension: 'jpg',
        headers: const {},
        cancelToken: token,
        onProgress: (_) => token.cancel(),
      ),
      throwsA(
        isA<ShareMediaException>().having(
          (error) => error.failure,
          'failure',
          ShareMediaFailure.cancelled,
        ),
      ),
    );
    final directory = Directory('${root.path}/boorusama-share');
    expect(await directory.list().toList(), isEmpty);
  });
  test('cancel interrupts a pending cache lookup before download', () async {
    final root = await Directory.systemTemp.createTemp('share-cache-cancel-');
    addTearDown(() => root.delete(recursive: true));
    final enteredCache = Completer<void>();
    final pendingCache = Completer<Uint8List?>();
    final token = CancelToken();
    final service = ShareMediaPreparation(
      rootPath: root.path,
      dio: Dio(),
      cachedBytes: (_) {
        enteredCache.complete();
        return pendingCache.future;
      },
    );
    final preparation = service.prepare(
      url: 'https://site.test/variant.png',
      kind: ShareMediaKind.image,
      fallbackExtension: 'png',
      headers: const {},
      cancelToken: token,
    );

    await enteredCache.future;
    token.cancel();
    try {
      await expectLater(
        preparation.timeout(const Duration(milliseconds: 300)),
        throwsA(
          isA<ShareMediaException>().having(
            (error) => error.failure,
            'failure',
            ShareMediaFailure.cancelled,
          ),
        ),
      );
    } finally {
      pendingCache.complete(null);
    }
  });
}
