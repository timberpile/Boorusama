import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/posts/shares/src/share_media_preparation.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/utils/file_utils.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory root;
  final png = Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2)));
  setUp(() async {
    root = await Directory.systemTemp.createTemp('share-common-');
  });
  tearDown(() => root.delete(recursive: true));
  for (final limit in [1024, 0, 1]) {
    test(
      'image share limit $limit survives clear while owned and releases safely',
      () async {
        final manager = DefaultImageCacheManager(
          maxBytes: limit,
          cacheRootPathProvider: () => root.path,
        );
        addTearDown(manager.dispose);
        var requests = 0;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);
        server.listen((request) async {
          requests++;
          request.response.headers.contentType = ContentType('image', 'png');
          request.response.add(png);
          await request.response.close();
        });
        final url = 'http://127.0.0.1:${server.port}/image.png';
        final key = manager.generateCacheKey(url);
        if (limit == 1024) await manager.saveFile(key, png);
        final preparation = ShareMediaPreparation(
          rootPath: root.path,
          dio: Dio(),
          cachedBytes: (_) async => null,
          imageCacheManager: manager,
        );
        final lease = await preparation.prepare(
          url: url,
          kind: ShareMediaKind.original,
          fallbackExtension: 'png',
          headers: const {},
        );
        expect(lease.mimeType, 'image/png');
        expect(requests, limit == 1024 ? 0 : 1);
        await manager.clearAllCache();
        await clearCache(_TestFileSystem(root.path));
        expect(await File(lease.path).readAsBytes(), png);
        expect(await manager.getCachedFilePath(key), isNull);
        expect(
          (await manager.getStats()).retainedBytes,
          limit == 1024 ? png.length : 0,
        );
        lease.retain();
        await lease.release();
        expect(File(lease.path).existsSync(), isTrue);
        await lease.release();
        await lease.release();
        expect(File(lease.path).existsSync(), isFalse);
        expect((await manager.getStats()).retainedBytes, 0);
      },
    );
  }
  for (final failedListing in [false, true]) {
    test(
      'generic clear preserves owned handoff roots when listing fails=$failedListing',
      () async {
        const protected = [
          'cacheimage',
          'cacheimage-index',
          'cacheimage-transfers',
          'boorusama-clipboard',
          'boorusama-share',
          'share_plus',
        ];
        for (final name in [...protected, 'ordinary']) {
          final file = File('${root.path}/$name/payload');
          await file.parent.create(recursive: true);
          await file.writeAsBytes([1, 2, 3]);
        }
        await clearCache(
          _TestFileSystem(root.path, failListing: failedListing),
        );
        for (final name in protected) {
          expect(await File('${root.path}/$name/payload').readAsBytes(), [
            1,
            2,
            3,
          ]);
        }
        if (!failedListing) {
          expect(Directory('${root.path}/ordinary').existsSync(), isFalse);
        }
      },
    );
  }
}

class _TestFileSystem extends IoFileSystem {
  const _TestFileSystem(this.root, {this.failListing = false});
  final String root;
  final bool failListing;
  @override
  Future<String?> getTemporaryPath() async => root;
  @override
  Stream<FileSystemEntry> listDirectoryStream(
    String path, {
    bool recursive = false,
    bool followLinks = true,
  }) {
    if (failListing) {
      return Stream.error(
        const FileSystemException('owned root listing unavailable'),
      );
    }
    return super.listDirectoryStream(
      path,
      recursive: recursive,
      followLinks: followLinks,
    );
  }
}
