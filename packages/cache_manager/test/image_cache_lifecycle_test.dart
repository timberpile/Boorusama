import 'dart:io';
import 'dart:typed_data';

import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late DefaultImageCacheManager manager;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('image-lifetime-');
    manager = DefaultImageCacheManager(cacheRootPathProvider: () => root.path);
  });
  tearDown(() async {
    await manager.dispose();
    await root.delete(recursive: true);
  });
  Future<void> limit(int value) => manager.setMaxBytes(value);
  Future<ImageCacheFileLease> read(String key) async =>
      (await manager.acquireFile(key))!;
  Future<ImageCacheWriteSession> write(String key) =>
      manager.beginFileWrite(key);

  test(
    'clear leaves an active source intact until its idempotent release',
    () async {
      await manager.saveFile('A', Uint8List.fromList([1, 2, 3, 4]));
      final lease = await read('A');
      await manager.clearAllCache();
      expect(await manager.hasValidCache('A'), isFalse);
      expect(await File(lease.path).readAsBytes(), [1, 2, 3, 4]);
      await lease.release();
      await lease.release();
      expect(await File(lease.path).exists(), isFalse);
    },
  );

  test(
    'same-key replacement keeps the leased original generation immutable',
    () async {
      await limit(8);
      await manager.saveFile('A', Uint8List.fromList([1, 2, 3, 4]));
      final old = await read('A');
      await manager.saveFile('A', Uint8List.fromList([5, 6, 7, 8]));
      expect(await File(old.path).readAsBytes(), [1, 2, 3, 4]);
      expect(await manager.getCachedFileBytes('A'), [5, 6, 7, 8]);
      expect(await manager.getCachedFilePath('A'), isNot(old.path));
      await old.release();
      expect(await File(old.path).exists(), isFalse);
    },
  );

  test(
    'a pre-clear writer completes transiently without refilling the cleared cache',
    () async {
      final session = await write('A');
      await File(session.stagedPath).writeAsBytes([1, 2, 3]);
      await manager.clearAllCache();
      final lease = await session.commit();
      expect(lease.isRetained, isFalse);
      expect(await File(lease.path).readAsBytes(), [1, 2, 3]);
      expect(await manager.hasValidCache('A'), isFalse);
      await lease.release();
      expect(await File(lease.path).exists(), isFalse);
    },
  );

  test(
    'commit evaluates a reduced limit using the completed file length',
    () async {
      await limit(8);
      await manager.saveFile('B', Uint8List.fromList([9, 9]));
      final session = await write('A');
      await File(session.stagedPath).writeAsBytes([1, 2, 3, 4]);
      await limit(3);
      final lease = await session.commit();
      expect(lease.isRetained, isFalse);
      expect(await manager.getCachedFileBytes('B'), [9, 9]);
      expect(await manager.hasValidCache('A'), isFalse);
      await lease.release();
    },
  );

  test(
    'pinned occupancy prevents admission without pointless partial eviction',
    () async {
      await limit(8);
      await manager.saveFile('A', Uint8List.fromList([1, 1, 1, 1]));
      await manager.saveFile('B', Uint8List.fromList([2, 2, 2, 2]));
      final pinned = await read('A');
      final session = await write('C');
      await File(session.stagedPath).writeAsBytes([3, 3, 3, 3, 3, 3]);
      final candidate = await session.commit();
      expect(candidate.isRetained, isFalse);
      expect(await manager.hasValidCache('B'), isTrue);
      expect(await File(pinned.path).readAsBytes(), [1, 1, 1, 1]);
      await candidate.release();
      await limit(0);
      expect(await File(pinned.path).exists(), isTrue);
      await pinned.release();
      expect(await File(pinned.path).exists(), isFalse);
    },
  );

  test(
    'aborted partial writes preserve previous bytes and cannot later commit',
    () async {
      await manager.saveFile('A', Uint8List.fromList([1, 2]));
      final session = await write('A');
      await File(session.stagedPath).writeAsBytes([3]);
      await session.abort();
      await session.abort();
      expect(await File(session.stagedPath).exists(), isFalse);
      expect(await manager.getCachedFileBytes('A'), [1, 2]);
      await expectLater(session.commit(), throwsStateError);
    },
  );

  test(
    'disabled admission returns a readable owned transient until release',
    () async {
      await limit(0);
      final session = await write('A');
      await File(session.stagedPath).writeAsBytes([1, 2, 3]);
      final lease = await session.commit();
      expect(lease.isRetained, isFalse);
      expect(await File(lease.path).readAsBytes(), [1, 2, 3]);
      expect(await manager.hasValidCache('A'), isFalse);
      await lease.release();
      expect(await File(lease.path).exists(), isFalse);
    },
  );
}
