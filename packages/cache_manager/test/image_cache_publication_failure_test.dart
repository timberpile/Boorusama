import 'dart:io';
import 'dart:typed_data';

import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'failed canonical publication preserves existing entries and capacity victims',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'image-publication-failure-',
      );
      var manager = DefaultImageCacheManager(
        maxBytes: 8,
        cacheRootPathProvider: () => root.path,
      );
      try {
        await manager.saveFile('A', Uint8List.fromList([1, 2, 3, 4]));
        await manager.saveFile('B', Uint8List.fromList([5, 6, 7, 8]));
        final writer = await manager.beginFileWrite(
          List.filled(300, 'C').join(),
        );
        await File(
          writer.stagedPath,
        ).writeAsBytes([9, 9, 9, 9, 9, 9, 9, 9]);

        await expectLater(
          writer.commit(),
          throwsA(isA<FileSystemException>()),
        );
        await writer.abort();

        expect(await manager.getCachedFileBytes('A'), [1, 2, 3, 4]);
        expect(await manager.getCachedFileBytes('B'), [5, 6, 7, 8]);
        expect((await manager.getStats()).retainedBytes, 8);
        expect(
          await Directory(
            '${root.path}/cacheimage-transfers',
          ).list().toList(),
          isEmpty,
        );

        await manager.dispose();
        manager = DefaultImageCacheManager(
          maxBytes: 8,
          cacheRootPathProvider: () => root.path,
        );
        expect(await manager.getCachedFileBytes('A'), [1, 2, 3, 4]);
        expect(await manager.getCachedFileBytes('B'), [5, 6, 7, 8]);
      } finally {
        await manager.dispose();
        await root.delete(recursive: true);
      }
    },
  );
}
