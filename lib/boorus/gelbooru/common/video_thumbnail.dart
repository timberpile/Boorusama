String resolveGelbooruVideoPosterUrl({
  required String sampleUrl,
  required String videoUrl,
  required String thumbnailUrl,
}) {
  final sampleUri = Uri.tryParse(sampleUrl);
  if (sampleUri != null &&
      _isWebUri(sampleUri) &&
      _staticImageExtensions.contains(_extension(sampleUri.path))) {
    return sampleUrl;
  }

  final videoUri = Uri.tryParse(videoUrl);
  if (videoUri == null || !_isWebUri(videoUri)) return thumbnailUrl;

  final extension = _extension(videoUri.path);
  if (!_videoExtensions.contains(extension)) return thumbnailUrl;

  final posterPath = videoUri.path.substring(
    0,
    videoUri.path.length - extension.length,
  );

  return videoUri.replace(path: '${posterPath}jpg').toString();
}

const _staticImageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'avif'};
const _videoExtensions = {'mp4', 'webm'};

bool _isWebUri(Uri uri) =>
    (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;

String _extension(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot == path.length - 1) return '';

  return path.substring(dot + 1).toLowerCase();
}
