import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cache_manager/cache_manager.dart';
import 'package:cache_manager/src/image_cache_checkpoint.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/performance.dart';

void main() {
  late Directory root;
  late DefaultImageCacheManager manager;
  setUp(() async {
    performanceRecorder.clear();
    root = await Directory.systemTemp.createTemp('cache-metrics-');
    manager = DefaultImageCacheManager(
      cacheRootPathProvider: () => root.path,
      maxBytes: 16,
    );
  });
  tearDown(() async {
    performanceRecorder.stop();
    await manager.dispose();
    performanceRecorder.clear();
    await root.delete(recursive: true);
  });
  Map counter(String name) =>
      ((performanceRecorder.snapshot()['summary'] as Map)['counters']
              as Map)[name]
          as Map;

  test(
    'samples retained bytes and actual victim work without recording keys',
    () async {
      for (final key in ['PRIVATE_A', 'PRIVATE_B', 'PRIVATE_C', 'PRIVATE_D']) {
        await manager.saveFile(key, Uint8List(4));
      }
      final lease = (await manager.acquireFile('PRIVATE_A'))!;
      for (final key in ['PRIVATE_B', 'PRIVATE_C', 'PRIVATE_D']) {
        await manager.touch(key);
      }
      performanceRecorder.start();
      await manager.setMaxBytes(8);
      expect(await manager.getCachedFilePath('PRIVATE_A'), isNotNull);
      expect(await manager.getCachedFilePath('PRIVATE_MISSING'), isNull);
      expect(counter('cacheRetainedBytes')['first'], 16);
      expect(counter('cacheRetainedBytes')['last'], 8);
      expect(counter('cacheEntries')['last'], 2);
      expect(counter('cacheEvictionExamined')['total'], 3);
      expect(counter('cacheEvictionVictims')['total'], 2);
      expect(counter('cacheLookupHit')['total'], 1);
      expect(counter('cacheLookupMiss')['total'], 1);
      expect(counter('cacheLimitBytes')['last'], 8);
      expect(
        jsonEncode(performanceRecorder.snapshot()),
        isNot(contains('PRIVATE_')),
      );
      performanceRecorder.stop();
      await lease.release();
    },
  );

  test(
    'below-limit reads measure acquire and journal work without eviction scans',
    () async {
      await manager.saveFile('PRIVATE_KEY', Uint8List(4));
      performanceRecorder.start();
      final lease = (await manager.acquireFile('PRIVATE_KEY'))!;
      await lease.release();
      final operations =
          ((performanceRecorder.snapshot()['summary'] as Map)['operations']
                  as List)
              .cast<Map>();
      expect(operations.any((op) => op['op'] == 'cacheAcquireFile'), isTrue);
      expect(operations.any((op) => op['op'] == 'cacheJournalAppend'), isTrue);
      expect(operations.any((op) => op['op'] == 'cacheEvictionScan'), isFalse);
      expect(counter('cacheEntries')['last'], 1);
    },
  );

  test(
    'queue depth counts pending operations while a checkpoint worker waits',
    () async {
      await manager.dispose();
      final entered = Completer<void>();
      final release = Completer<void>();
      manager = DefaultImageCacheManager(
        cacheRootPathProvider: () => root.path,
        checkpointWriter: (snapshot) async {
          if (!entered.isCompleted) entered.complete();
          await release.future;
          await writeImageCacheCheckpointInBackground(snapshot);
        },
      );
      performanceRecorder.start();
      final pending = [for (var i = 0; i < 3; i++) manager.getCacheDirectory()];
      await entered.future;
      expect(counter('cacheQueueDepth')['max'], 3);
      release.complete();
      await Future.wait(pending);
      expect(counter('cacheQueueDepth')['last'], 0);
      final operations =
          ((performanceRecorder.snapshot()['summary'] as Map)['operations']
                  as List)
              .cast<Map>();
      expect(
        operations.singleWhere(
          (op) => op['op'] == 'cacheCheckpointWorker',
        )['kind'],
        'asyncWall',
      );
      expect(
        operations.singleWhere((op) => op['op'] == 'cacheQueueWait')['count'],
        3,
      );
    },
  );
}
