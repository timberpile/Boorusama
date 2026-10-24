import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/performance.dart';

Map get _summary => performanceRecorder.snapshot()['summary'] as Map;
num _counter(String name) =>
    ((_summary['counters'] as Map)[name] as Map?)?['total'] as num? ?? 0;
num _operations(String name) {
  final rows = (_summary['operations'] as List).cast<Map>();
  return rows
      .where((row) => row['op'] == name)
      .fold<num>(0, (count, row) => count + (row['count'] as num));
}

void main() {
  late Directory root;
  late DefaultImageCacheManager manager;
  setUp(() async {
    performanceRecorder.clear();
    root = await Directory.systemTemp.createTemp('scalability-cache-read-');
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

  test('disk byte reads validate once and retain one usage record', () async {
    await manager.saveFile('A', Uint8List.fromList([1, 2, 3, 4]));
    performanceRecorder.start();
    expect(await manager.getCachedFileBytes('A'), [1, 2, 3, 4]);
    expect(_counter('cacheLookupHit'), 1);
    expect(_operations('cacheQueueWait'), 3);
    expect(_operations('cacheJournalAppend'), 1);
    expect(_operations('cacheRead'), 1);
  });

  test('a missing entry does not acquire a second queue slot', () async {
    await manager.getCacheDirectory();
    performanceRecorder.start();
    expect(await manager.getCachedFileBytes('missing'), isNull);
    expect(_counter('cacheLookupMiss'), 1);
    expect(_operations('cacheQueueWait'), 1);
    expect(_operations('cacheJournalAppend'), 0);
  });

  test(
    'RAM hits still validate disk residency and record actual use',
    () async {
      await manager.dispose();
      manager = DefaultImageCacheManager(
        cacheRootPathProvider: () => root.path,
        maxBytes: 16,
        memoryCache: LRUMemoryCache(maxEntries: 2),
      );
      await manager.saveFile('A', Uint8List.fromList([1, 2, 3, 4]));
      await manager.getCachedFileBytes('A');
      performanceRecorder.start();
      expect(await manager.getCachedFileBytes('A'), [1, 2, 3, 4]);
      expect(_counter('cacheLookupHit'), 1);
      expect(_operations('cacheQueueWait'), 1);
      expect(_operations('cacheJournalAppend'), 1);
      performanceRecorder.stop();
      await manager.clearCache('A');
      expect(await manager.getCachedFileBytes('A'), isNull);
    },
  );

  for (final corruption in ['missing', 'truncated', 'expired']) {
    test(
      '$corruption payload is not returned or retained in accounting',
      () async {
        await manager.saveFile('A', Uint8List.fromList([1, 2, 3, 4]));
        final file = File((await manager.getCachedFilePath('A'))!);
        switch (corruption) {
          case 'missing':
            await file.delete();
          case 'truncated':
            await file.writeAsBytes([1]);
          case 'expired':
            await file.setLastModified(DateTime.utc(2000));
        }
        expect(
          await manager.getCachedFileBytes(
            'A',
            maxAge: corruption == 'expired' ? const Duration(days: 1) : null,
          ),
          isNull,
        );
        expect((await manager.getStats()).retainedBytes, 0);
      },
    );
  }

  for (final clearAll in [false, true]) {
    test(
      '${clearAll ? "global" : "per-key"} clear preserves a read lease but prevents RAM repopulation',
      () async {
        await manager.dispose();
        manager = DefaultImageCacheManager(
          cacheRootPathProvider: () => root.path,
          maxBytes: 16,
          memoryCache: LRUMemoryCache(maxEntries: 2),
        );
        await manager.saveFile('A', Uint8List.fromList([1, 2, 3, 4]));
        final path = (await manager.getCachedFilePath('A'))!;
        final gate = _ReadGate(path);
        await IOOverrides.runWithIOOverrides(() async {
          final reading = manager.getCachedFileBytes('A');
          try {
            await gate.entered.future;
            if (clearAll) {
              await manager.clearAllCache();
            } else {
              await manager.clearCache('A');
            }
            expect(await File(path).exists(), isTrue);
            expect((await manager.getStats()).retainedBytes, 4);
          } finally {
            gate.release.complete();
          }
          expect(await reading, [1, 2, 3, 4]);
          expect(await File(path).exists(), isFalse);
          expect(await manager.getCachedFileBytes('A'), isNull);
          expect((await manager.getStats()).retainedBytes, 0);
        }, gate);
      },
    );
  }

  test(
    'payload read failure releases the pin so clear can reclaim the file',
    () async {
      await manager.saveFile('A', Uint8List(4));
      final path = (await manager.getCachedFilePath('A'))!;
      final gate = _ReadGate(path, fail: true)..release.complete();
      await IOOverrides.runWithIOOverrides(() async {
        expect(await manager.getCachedFileBytes('A'), isNull);
        await manager.clearCache('A');
        expect(await File(path).exists(), isFalse);
        expect((await manager.getStats()).retainedBytes, 0);
      }, gate);
    },
  );
}

final class _ReadGate extends IOOverrides {
  _ReadGate(this.path, {this.fail = false});
  final String path;
  final bool fail;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  File createFile(String requested) {
    final file = super.createFile(requested);
    return requested == path ? _GatedFile(file, this) : file;
  }
}

class _GatedFile implements File {
  _GatedFile(this.file, this.gate);
  final File file;
  final _ReadGate gate;
  @override
  String get path => file.path;
  @override
  Future<FileStat> stat() => file.stat();
  @override
  Future<bool> exists() => file.exists();
  @override
  Future<int> length() => file.length();
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      file.delete(recursive: recursive);
  @override
  Future<Uint8List> readAsBytes() async {
    if (!gate.entered.isCompleted) gate.entered.complete();
    await gate.release.future;
    if (gate.fail) throw const FileSystemException('Controlled read failure');
    return file.readAsBytes();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
