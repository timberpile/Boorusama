import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';

import '../engines/types.dart';
import 'guarded_video_stream.dart';

typedef PreparedBoundVideo = ({
  VideoSource source,
  Future<void> Function()? release,
});

/// Optional cache admission must not decide whether an authorized video plays.
/// Cache-eligible known small files keep offline reuse; other media streams
/// through the same guarded source transport without unbounded file retention.
Future<PreparedBoundVideo> prepareBoundVideo({
  required String url,
  required String namespace,
  required Dio transport,
  required Map<String, String> headers,
  required bool Function() isCurrent,
  required CancelToken cancellation,
  required int? fileSize,
  VideoCacheManager? cache,
}) async {
  bool current() => !cancellation.isCancelled && isCurrent();
  if (!current()) throw StateError('Video access revoked');
  if (cache != null &&
      fileSize != null &&
      fileSize > 0 &&
      fileSize <= cache.maxItemSize &&
      fileSize <= 100 * 1024 * 1024 &&
      fileSize <= cache.maxTotalCacheSize) {
    try {
      final lease = await cache.acquireGuardedVideo(
        url,
        namespace: namespace,
        transport: transport,
        headers: headers,
        isCurrent: current,
        cancelToken: cancellation,
      );
      if (!current()) {
        await lease.release();
        throw StateError('Video access revoked');
      }
      return (
        source: CachedVideoSource(filePath: lease.path, originalUrl: url),
        release: lease.release,
      );
    } catch (_) {
      if (!current()) rethrow;
      // Size metadata can be stale, or the optional cache can be full. Playback
      // still uses the guarded adapter; there is no native upstream fallback.
    }
  }
  final stream = await GuardedVideoStream.open(
    transport: transport,
    upstream: url,
    headers: headers,
    isCurrent: current,
    cancellation: cancellation,
  );
  if (!current()) {
    await stream.close();
    throw StateError('Video access revoked');
  }
  return (
    source: GuardedStreamingVideoSource(
      playbackUrl: stream.uri.toString(),
      originalUrl: url,
      failures: stream.failures,
    ),
    release: stream.close,
  );
}
