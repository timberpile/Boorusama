/// Video source information for players
sealed class VideoSource {
  const VideoSource({required this.originalUrl});

  /// The original streaming URL
  final String originalUrl;

  /// The URL to use for playback
  String get url;

  /// MIME type based on the original URL, since cached files have no extension
  String get mimeType => switch (originalUrl.toLowerCase()) {
    final u when u.contains('.webm') => 'video/webm',
    final u when u.contains('.mp4') => 'video/mp4',
    final u when u.contains('.mov') => 'video/quicktime',
    final u when u.contains('.avi') => 'video/x-msvideo',
    _ => 'video/mp4',
  };
}

/// Streaming video source (no caching)
class StreamingVideoSource extends VideoSource {
  const StreamingVideoSource(String url) : super(originalUrl: url);

  @override
  String get url => originalUrl;

  @override
  String toString() => 'StreamingVideoSource(url: $url)';
}

/// A native player reads only a route-owned local stream. The upstream source
/// remains metadata; credentials and redirects stay in the guarded Dart client.
final class GuardedStreamingVideoSource extends StreamingVideoSource {
  const GuardedStreamingVideoSource({
    required this.playbackUrl,
    required String originalUrl,
    this.failures = const Stream.empty(),
  }) : super(originalUrl);

  final String playbackUrl;
  final Stream<void> failures;
  @override
  String get url => playbackUrl;
}

/// Cached video file source
class CachedVideoSource extends VideoSource {
  const CachedVideoSource({
    required this.filePath,
    required super.originalUrl,
  });

  /// Absolute path of the cached video file
  final String filePath;

  @override
  String get url => 'file://$filePath';

  @override
  String toString() =>
      'CachedVideoSource(filePath: $filePath, originalUrl: $originalUrl)';
}
