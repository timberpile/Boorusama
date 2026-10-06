import 'dart:io';

import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final held in [false, true]) {
    test(
      'failed generation rename preserves ${held ? "leased" : "unleased"} previous bytes and capacity victims',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'image-publication-failure-',
        );
        final directory = Directory('${root.path}/cacheimage');
        await directory.create();
        final key = List.filled(240, 'A').join();
        await File('${directory.path}/$key').writeAsBytes([1, 2, 3, 4]);
        await File('${directory.path}/B').writeAsBytes([5, 6, 7, 8]);
        var manager = DefaultImageCacheManager(
          maxBytes: held ? 12 : 8,
          cacheRootPathProvider: () => root.path,
        );
        ImageCacheFileLease? reader;
        try {
          expect(await manager.getCachedFileBytes(key), [1, 2, 3, 4]);
          if (held) reader = await manager.acquireFile(key);
          final writer = await manager.beginFileWrite(key);
          await File(writer.stagedPath).writeAsBytes([9, 9, 9, 9, 9, 9, 9, 9]);
          await expectLater(
            writer.commit(),
            throwsA(isA<FileSystemException>()),
          );
          await writer.abort();
          expect(await manager.getCachedFileBytes(key), [1, 2, 3, 4]);
          expect(await manager.getCachedFileBytes('B'), [5, 6, 7, 8]);
          expect((await manager.getStats()).retainedBytes, 8);
          if (reader case final lease?) {
            expect(await File(lease.path).readAsBytes(), [1, 2, 3, 4]);
          }
          await reader?.release();
          reader = null;
          expect(
            await Directory(
              '${root.path}/cacheimage-transfers',
            ).list().toList(),
            isEmpty,
          );
          await manager.dispose();
          manager = DefaultImageCacheManager(
            maxBytes: held ? 12 : 8,
            cacheRootPathProvider: () => root.path,
          );
          expect(await manager.getCachedFileBytes(key), [1, 2, 3, 4]);
          expect(await manager.getCachedFileBytes('B'), [5, 6, 7, 8]);
        } finally {
          await reader?.release();
          await manager.dispose();
          await root.delete(recursive: true);
        }
      },
    );
  }
}
