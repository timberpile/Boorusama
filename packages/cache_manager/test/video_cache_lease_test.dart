import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late VideoCacheManager manager;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('video-cache-lease-');
    manager = VideoCacheManager(
      fileDownloader: FileDownloader(),
      dio: Dio(),
      cacheRootPathProvider: () => root.path,
    );
  });

  tearDown(() async {
    await manager.dispose();
    await root.delete(recursive: true);
  });

  Future<File> seed(String url, List<int> bytes) async {
    final directory = await manager.getCacheDirectory();
    return File(
      '${directory.path}/${manager.generateCacheKey(url)}',
    ).writeAsBytes(bytes);
  }

  test(
    'a deferred deletion blocks replacement until the last reader releases',
    () async {
      const url = 'https://example.test/video.mp4';
      final downloader = _RecordingDownloader();
      await manager.dispose();
      manager = VideoCacheManager(
        fileDownloader: downloader,
        dio: Dio(),
        cacheRootPathProvider: () => root.path,
      );
      final original = await seed(url, [1, 2, 3]);
      final first = (await manager.acquireVideo(url))!;
      final second = (await manager.acquireVideo(url))!;
      await manager.clearVideo(url);
      expect(await manager.cacheVideo(url, fileSize: 3), isNull);
      expect(downloader.queued, isEmpty);
      await first.release();
      expect(await original.readAsBytes(), [1, 2, 3]);
      expect(await manager.cacheVideo(url, fileSize: 3), isNull);
      await second.release();
      expect(await original.exists(), isFalse);
      expect(await manager.cacheVideo(url, fileSize: 3), isNotNull);
      expect(downloader.queued, hasLength(1));
      await File(
        await downloader.queued.single.filePath(),
      ).writeAsBytes([4, 5, 6]);
      await first.release();
      expect(await original.readAsBytes(), [4, 5, 6]);
    },
  );

  test('clear defers deletion until the active lease is released', () async {
    const url = 'https://example.test/video.mp4';
    final file = await seed(url, [1, 2, 3]);
    final lease = await manager.acquireVideo(url);

    expect(lease?.path, file.path);
    await manager.clearVideo(url);
    expect(await file.exists(), isTrue);
    expect(await manager.isVideoCached(url), isFalse);

    await lease!.release();
    await lease.release();
    expect(await file.exists(), isFalse);
  });

  test(
    'clear all removes inactive files but preserves active playback',
    () async {
      const activeUrl = 'https://example.test/active.webm';
      const inactiveUrl = 'https://example.test/inactive.webm';
      final active = await seed(activeUrl, [1]);
      final inactive = await seed(inactiveUrl, [2]);
      final lease = await manager.acquireVideo(activeUrl);

      await manager.clearAllVideos();

      expect(await active.exists(), isTrue);
      expect(await inactive.exists(), isFalse);
      expect(await manager.isVideoCached(activeUrl), isFalse);
      await lease!.release();
      expect(await active.exists(), isFalse);
    },
  );

  test('expiry hides an active file and deletes it after release', () async {
    const url = 'https://example.test/expired.mp4';
    final file = await seed(url, [1]);
    final lease = await manager.acquireVideo(url);
    await file.setLastModified(
      DateTime.now().subtract(const Duration(days: 2)),
    );

    expect(
      await manager.isVideoCached(url, maxAge: const Duration(days: 1)),
      isFalse,
    );
    expect(await file.exists(), isTrue);
    await lease!.release();
    expect(await file.exists(), isFalse);
  });
}

class _RecordingDownloader implements FileDownloader {
  final queued = <DownloadTask>[];
  @override
  Future<Task?> taskForId(String taskId) async => null;
  @override
  Future<bool> enqueue(Task task) async {
    queued.add(task as DownloadTask);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
