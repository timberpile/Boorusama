import 'dart:io';
import 'dart:typed_data';

import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late DefaultImageCacheManager manager;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('image-accounting-');
    manager = DefaultImageCacheManager(cacheRootPathProvider: () => root.path);
  });
  tearDown(() async {
    await manager.dispose();
    await root.delete(recursive: true);
  });
  Future<void> save(String key, int length) =>
      manager.saveFile(key, Uint8List(length));
  Future<void> expectStats(int bytes, int files) async {
    final stats = await manager.getStats();
    expect(stats.retainedBytes, bytes);
    expect(stats.retainedFileCount, files);
  }

  test(
    'duplicate same-key writes share one pinned canonical file',
    () async {
      await save('A', 2);
      final first = (await manager.acquireFile('A'))!;
      await save('A', 3);
      final second = (await manager.acquireFile('A'))!;
      await save('A', 4);
      await expectStats(2, 1);
      await manager.setMaxBytes(1);
      expect(await manager.hasValidCache('A'), isTrue);
      await expectStats(2, 1);
      await first.release();
      await first.release();
      await expectStats(2, 1);
      await manager.setMaxBytes(0);
      await expectStats(2, 1);
      await second.release();
      expect(await manager.hasValidCache('A'), isFalse);
      await expectStats(0, 0);
    },
  );

  test(
    'replacements, missing files and clear during writes conserve bytes',
    () async {
      await save('A', 4);
      await save('A', 6);
      await expectStats(4, 1);
      await File((await manager.getCachedFilePath('A'))!).delete();
      await expectStats(0, 0);
      await save('B', 3);
      final writer = await manager.beginFileWrite('B');
      await File(writer.stagedPath).writeAsBytes([1, 2]);
      await manager.clearCache('B');
      final result = await writer.commit();
      expect(result.isRetained, isFalse);
      await expectStats(0, 0);
      await result.release();
      await save('C', 5);
      await manager.clearAllCache();
      await expectStats(0, 0);
    },
  );

  test(
    'restart reconciles missing, resized and orphaned files exactly once',
    () async {
      await save('A', 2);
      await save('B', 3);
      await save('C', 4);
      final a = (await manager.getCachedFilePath('A'))!;
      final b = (await manager.getCachedFilePath('B'))!;
      await manager.dispose();
      await File(a).delete();
      await File(b).writeAsBytes([1]);
      await File('${root.path}/cacheimage/orphan').writeAsBytes([1, 2]);
      manager = DefaultImageCacheManager(
        cacheRootPathProvider: () => root.path,
      );
      await expectStats(4, 1);
      await save('D', 5);
      await expectStats(9, 2);
      await manager.dispose();
      manager = DefaultImageCacheManager(
        cacheRootPathProvider: () => root.path,
      );
      await expectStats(9, 2);
    },
  );

  test(
    'legacy reconciliation migrates the newest same-key generation',
    () async {
      final directory = Directory('${root.path}/cacheimage');
      await directory.create();
      final old = File('${directory.path}/A');
      await old.writeAsBytes([1, 2]);
      await old.setLastModified(DateTime(2020));
      await File('${directory.path}/A.generation_new').writeAsBytes([3, 4, 5]);
      await expectStats(3, 1);
      expect(await manager.getCachedFileBytes('A'), [3, 4, 5]);
      expect(await File('${directory.path}/A').exists(), isTrue);
      expect(
        await File('${directory.path}/A.generation_new').exists(),
        isFalse,
      );
    },
  );

  test(
    'failed retirement retains bytes and retries cleanup below capacity',
    () async {
      await save('A', 4);
      final directory = Directory('${root.path}/cacheimage');
      expect(
        (await Process.run('chmod', ['0555', directory.path])).exitCode,
        0,
      );
      try {
        await expectLater(
          manager.clearCache('A'),
          throwsA(isA<FileSystemException>()),
        );
        await expectStats(4, 1);
      } finally {
        await Process.run('chmod', ['0755', directory.path]);
      }
      await manager.setMaxBytes(100);
      await expectStats(0, 0);
    },
    skip: !Platform.isLinux,
  );

  test(
    'failed initialization can retry without counting loaded files twice',
    () async {
      await save('A', 4);
      await manager.dispose();
      final directory = Directory('${root.path}/cacheimage');
      await File('${directory.path}/orphan').writeAsBytes([1]);
      manager = DefaultImageCacheManager(
        cacheRootPathProvider: () => root.path,
      );
      expect(
        (await Process.run('chmod', ['0555', directory.path])).exitCode,
        0,
      );
      try {
        await expectLater(
          manager.getStats(),
          throwsA(isA<FileSystemException>()),
        );
      } finally {
        await Process.run('chmod', ['0755', directory.path]);
      }
      await expectStats(4, 1);
      await save('B', 2);
      await expectStats(6, 2);
    },
    skip: !Platform.isLinux,
  );

  for (final count in [1800, 3400]) {
    test(
      'large-cache reads and admission retain all entries at $count files',
      () async {
        final directory = Directory('${root.path}/cacheimage');
        await directory.create();
        // Disposable legacy payloads avoid journaling during fixture preparation.
        for (var start = 0; start < count; start += 50) {
          await Future.wait([
            for (var i = start; i < start + 50 && i < count; i++)
              File('${directory.path}/key$i').writeAsBytes([1]),
          ]);
        }
        await expectStats(
          count,
          count,
        ); // Initialization is outside interaction.
        for (var i = 0; i < 3; i++) {
          expect(await manager.getCachedFileBytes('key$i'), [1]);
        }
        await save('new', 2);
        expect(await manager.getCachedFileBytes('new'), [0, 0]);
        await expectStats(count + 2, count + 1);
      },
    );
  }
}
