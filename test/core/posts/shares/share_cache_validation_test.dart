import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/posts/shares/src/share_media_preparation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  final pngBytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 1, height: 1)),
  );
  final cases = [
    (path: 'variant.png', cached: Uint8List.fromList([1, 2, 3])),
    (path: 'variant.jpg', cached: pngBytes),
  ];

  for (final testCase in cases) {
    test(
      'invalid or mismatched cached ${testCase.path} reloads exact URL',
      () async {
        final root = await Directory.systemTemp.createTemp('share-cache-');
        addTearDown(() => root.delete(recursive: true));
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);
        var requests = 0;
        String? requestedUri;
        server.listen((request) async {
          requests++;
          requestedUri = request.uri.toString();
          expect(request.headers.value('authorization'), 'secret');
          request.response.headers.contentType = ContentType('image', 'png');
          request.response.add(pngBytes);
          await request.response.close();
        });
        final service = ShareMediaPreparation(
          rootPath: root.path,
          dio: Dio(),
          cachedBytes: (_) async => testCase.cached,
        );

        final lease = await service.prepare(
          url:
              'http://127.0.0.1:${server.port}/${testCase.path}?variant=chosen',
          kind: ShareMediaKind.image,
          fallbackExtension: 'png',
          headers: const {'Authorization': 'secret'},
        );

        expect(requests, 1);
        expect(requestedUri, '/${testCase.path}?variant=chosen');
        expect(lease.path, endsWith('.png'));
        expect(lease.mimeType, 'image/png');
        expect(await File(lease.path).readAsBytes(), pngBytes);
        await lease.release();
      },
    );
  }
}
