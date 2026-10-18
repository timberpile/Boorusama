import 'dart:io';
import 'dart:typed_data';

import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late DefaultImageCacheManager manager;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('cache-lru-');
    manager = DefaultImageCacheManager(cacheRootPathProvider: () => root.path);
  });
  tearDown(() async {
    await manager.dispose();
    await root.delete(recursive: true);
  });
  Future<void> save(String key, [int size = 2]) =>
      manager.saveFile(key, Uint8List(size));

  for (final count in [64, 4000]) {
    test(
      'full cache churn preserves capacity and evicts oldest entries at $count files',
      () async {
        final directory = Directory('${root.path}/cacheimage');
        await directory.create();
        for (var i = 0; i < count; i++) {
          final file = File('${directory.path}/old-$i');
          await file.writeAsBytes([1]);
          await file.setLastModified(
            DateTime.utc(2020).add(Duration(seconds: i)),
          );
        }
        await manager.setMaxBytes(count);
        for (var i = 0; i < 25; i++) {
          await save('new-$i', 1);
        }
        final stats = await manager.getStats();
        expect(stats.retainedBytes, count);
        expect(stats.retainedFileCount, count);
        for (var i = 0; i < 25; i++) {
          expect(await manager.hasValidCache('old-$i'), isFalse);
          expect(await manager.hasValidCache('new-$i'), isTrue);
        }
        expect(await manager.hasValidCache('old-25'), isTrue);
      },
    );
  }

  test(
    'pinned oldest is skipped and release does not refresh its age',
    () async {
      await manager.setMaxBytes(6);
      for (final key in ['A', 'B', 'C']) {
        await save(key);
      }
      final lease = (await manager.acquireFile('A'))!;
      await manager.touch('B');
      await manager.touch('C');
      await save('D');
      expect(await manager.hasValidCache('A'), isTrue);
      expect(await manager.hasValidCache('B'), isFalse);
      await lease.release();
      await save('E');
      expect(await manager.hasValidCache('A'), isFalse);
      for (final key in ['C', 'D', 'E']) {
        expect(await manager.hasValidCache(key), isTrue);
      }
    },
  );

  test('same-key duplicate preserves unrelated older entries', () async {
    await manager.setMaxBytes(6);
    for (final key in ['A', 'B', 'C']) {
      await save(key);
    }
    await manager.touch('A');
    await save('A');
    for (final key in ['A', 'B', 'C']) {
      expect(await manager.hasValidCache(key), isTrue);
    }
    await save('D');
    expect(await manager.hasValidCache('B'), isFalse);
  });

  test(
    'limit reduction and restart preserve recency',
    () async {
      await manager.setMaxBytes(10);
      for (final key in ['A', 'B', 'C', 'D', 'E']) {
        await save(key);
      }
      await manager.touch('B');
      await manager.touch('A');
      await manager.dispose();
      manager = DefaultImageCacheManager(
        maxBytes: 10,
        cacheRootPathProvider: () => root.path,
      );
      await manager.getCacheDirectory();
      await manager.setMaxBytes(6);
      expect(await manager.hasValidCache('C'), isFalse);
      expect(await manager.hasValidCache('D'), isFalse);
      for (final key in ['E', 'B', 'A']) {
        expect(await manager.hasValidCache(key), isTrue);
      }
      await save('F');
      expect(await manager.hasValidCache('E'), isFalse);
    },
  );
}
