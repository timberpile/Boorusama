import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/posts/shares/src/share_media_preparation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'extensionless image URL uses response type even with cached bytes',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'share-extensionless-',
      );
      addTearDown(() => root.delete(recursive: true));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      var requests = 0;
      server.listen((request) async {
        requests++;
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add([137, 80, 78, 71]);
        await request.response.close();
      });
      final service = ShareMediaPreparation(
        rootPath: root.path,
        dio: Dio(),
        cachedBytes: (_) async => Uint8List.fromList([1, 2, 3]),
      );

      final lease = await service.prepare(
        url: 'http://127.0.0.1:${server.port}/image?token=private',
        kind: ShareMediaKind.image,
        fallbackExtension: null,
        headers: const {},
      );

      expect(requests, 1);
      expect(lease.path, endsWith('.png'));
      expect(lease.mimeType, 'image/png');
      expect(await File(lease.path).readAsBytes(), [137, 80, 78, 71]);
      await lease.release();
    },
  );
}
