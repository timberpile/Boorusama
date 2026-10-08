import 'dart:io';
import 'dart:typed_data';

import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final blocked in ['cacheimage-index', 'cacheimage-transfers']) {
    test(
      'cold $blocked failure preserves readable payload and recovers durable use order',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'image-storage-recovery-',
        );
        final marker = File('${root.path}/$blocked');
        await marker.writeAsBytes([9, 8, 7]);
        final payload = Directory('${root.path}/cacheimage');
        await payload.create();
        await File('${payload.path}/A').writeAsBytes([1, 1, 1, 1]);
        await File('${payload.path}/B').writeAsBytes([2, 2, 2, 2]);
        var manager = DefaultImageCacheManager(
          maxBytes: 8,
          cacheRootPathProvider: () => root.path,
        );
        try {
          expect(await manager.getCachedFileBytes('A'), [1, 1, 1, 1]);
          expect((await manager.getStats()).retainedBytes, 8);
          expect(await marker.readAsBytes(), [9, 8, 7]);
          await marker.delete();
          await Directory(marker.path).create();
          await manager.touch('B');
          await manager.dispose();
          manager = DefaultImageCacheManager(
            maxBytes: 8,
            cacheRootPathProvider: () => root.path,
          );
          await manager.saveFile('C', Uint8List.fromList([3, 3, 3, 3]));
          expect(await manager.hasValidCache('A'), isFalse);
          expect(await manager.getCachedFileBytes('B'), [2, 2, 2, 2]);
          expect(await manager.getCachedFileBytes('C'), [3, 3, 3, 3]);
        } finally {
          try {
            await manager.dispose();
          } on FileSystemException {
            // A failing assertion may leave the injected cold root blocked.
          }
          await root.delete(recursive: true);
        }
      },
    );
  }
}
