import 'dart:async';
import 'dart:io';

import 'package:boorusama/core/posts/shares/src/gif_conversion_service.dart';
import 'package:boorusama/core/posts/shares/src/gif_export_contract.dart';
import 'package:boorusama/core/posts/shares/src/gif_timeline_thumbnails.dart';
import 'package:boorusama/core/posts/shares/src/share_media_preparation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'regional requests debounce, cache and keep one native writer alive until completion',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'gif-thumbnail-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/source.mp4');
      await file.writeAsBytes([0]);
      final source = GifPreparedSource(
        lease: ShareMediaLease(path: file.path, mimeType: 'video/mp4'),
        metadata: const GifSourceMetadata(
          duration: Duration(seconds: 100),
          complete: true,
          width: 640,
          height: 480,
          rotationDegrees: 0,
          sampleAspectRatio: 1,
          frameRate: 30,
        ),
      );
      final backend = _Backend();
      final thumbnails = GifTimelineThumbnails(source, backend);
      final published = Completer<void>();
      thumbnails.addListener(() {
        if (!published.isCompleted) published.complete();
      });
      thumbnails.request(Duration.zero, const Duration(seconds: 10));
      thumbnails.request(
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      );
      await backend.started.future;
      expect(backend.calls, 1);
      expect(backend.start, const Duration(seconds: 1));
      backend.finished.complete();
      await backend.completed.future;
      await published.future.timeout(const Duration(seconds: 3));
      expect(thumbnails.strip!.bytes, [1, 2, 3]);
      thumbnails.request(
        const Duration(seconds: 2),
        const Duration(seconds: 3),
      );
      thumbnails.request(
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(backend.calls, 1);
      thumbnails.dispose();
      await thumbnails.close();
      expect(file.existsSync(), isTrue);
      await source.release();
      expect(file.existsSync(), isFalse);
      expect(directory.listSync(), isEmpty);
    },
  );

  test(
    'closing waits for cancelled native work before deleting temporary files and releasing source',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'gif-thumbnail-close-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/source.mp4');
      await file.writeAsBytes([0]);
      final source = GifPreparedSource(
        lease: ShareMediaLease(path: file.path, mimeType: 'video/mp4'),
        metadata: const GifSourceMetadata(
          duration: Duration(seconds: 100),
          complete: true,
          width: 640,
          height: 480,
          rotationDegrees: 0,
          sampleAspectRatio: 1,
          frameRate: 30,
        ),
      );
      final backend = _Backend();
      final thumbnails = GifTimelineThumbnails(source, backend);
      thumbnails.request(Duration.zero, const Duration(seconds: 1));
      await backend.started.future;
      await source.release();
      thumbnails.dispose();
      final close = thumbnails.close();
      await backend.token.whenCancel;
      expect(backend.output.parent.existsSync(), isTrue);
      expect(file.existsSync(), isTrue);
      backend.finished.complete();
      await close;
      expect(file.existsSync(), isFalse);
      expect(directory.listSync(), isEmpty);
    },
  );
}

class _Backend implements GifTimelineRegionBackend {
  final started = Completer<void>();
  final finished = Completer<void>();
  final completed = Completer<void>();
  var calls = 0;
  late Duration start;
  late File output;
  late CancelToken token;
  @override
  Future<void> createTimelineRegion({
    required String sourcePath,
    required String outputPath,
    required Duration start,
    required Duration duration,
    required CancelToken cancelToken,
  }) async {
    calls++;
    this.start = start;
    token = cancelToken;
    output = File(outputPath);
    await output.writeAsBytes([1, 2, 3]);
    started.complete();
    await finished.future;
    completed.complete();
  }
}
