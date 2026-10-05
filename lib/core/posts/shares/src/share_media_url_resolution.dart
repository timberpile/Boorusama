import 'package:dio/dio.dart';
import '../../../downloads/urls/types.dart';
import '../../../downloads/urls/providers.dart';
import '../../post/types.dart';
import 'share_media_preparation.dart';
import 'share_payloads.dart';
import 'share_resolution_control.dart';

bool hasExactOriginalSource(
  Post post,
  DownloadFileUrlExtractor extractor,
) {
  final uri = Uri.tryParse(post.originalImageUrl);
  if (uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty) {
    return true;
  }
  return switch (extractor) {
    final ExactOriginalUrlExtractor resolver =>
      resolver.canResolveExactOriginal(post),
    _ => false,
  };
}

const _videoExtensions = {'mp4', 'webm', 'mov', 'm4v'};

String? _webUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return null;
  }
  return uri.toString();
}

String? _urlExtension(String url) {
  final segments = Uri.parse(url).pathSegments;
  if (segments.isEmpty) return null;
  final name = segments.last;
  final separator = name.lastIndexOf('.');
  if (separator < 0 || separator == name.length - 1) return null;
  return name.substring(separator + 1).toLowerCase();
}

bool _isKnownVideoUrl(Post post, String url) {
  final extension = _urlExtension(url);
  return _videoExtensions.contains(extension) ||
      (extension == null &&
          _videoExtensions.contains(
            post.format.toLowerCase().replaceFirst('.', ''),
          ));
}

bool _isUnprovenPreviewUrl(Post post, String url) {
  final matchesPreview = [
    post.thumbnailImageUrl,
    post.sampleImageUrl,
    post.videoThumbnailUrl,
  ].any((preview) => _webUrl(preview) == url);
  if (!matchesPreview) return false;
  if (_webUrl(post.originalImageUrl) == url &&
      _videoExtensions.contains(_urlExtension(url))) {
    return false;
  }
  return _webUrl(post.videoUrl) != url || !_isKnownVideoUrl(post, url);
}

String? _directVideoUrl(Post post) {
  final original = _webUrl(post.originalImageUrl);
  if (original != null &&
      _videoExtensions.contains(_urlExtension(original)) &&
      !_isUnprovenPreviewUrl(post, original)) {
    return original;
  }
  final video = _webUrl(post.videoUrl);
  if (video != null &&
      _isKnownVideoUrl(post, video) &&
      !_isUnprovenPreviewUrl(post, video)) {
    return video;
  }
  return null;
}

bool hasExactVideoSource(Post post, DownloadFileUrlExtractor extractor) {
  if (!post.isVideo) return false;
  if (_directVideoUrl(post) != null) return true;
  return switch (extractor) {
    final ExactVideoUrlExtractor resolver => resolver.canResolveExactVideo(
      post,
    ),
    _ => false,
  };
}

bool _isExactVideoResult(
  Post post,
  DownloadFileUrlExtractor extractor,
  String? value,
) {
  final url = _webUrl(value ?? '');
  if (url == null) return false;
  final extension = _urlExtension(url);
  if (_isUnprovenPreviewUrl(post, url) ||
      (extension != null && !_videoExtensions.contains(extension))) {
    return false;
  }
  return _videoExtensions.contains(extension) ||
      url == _directVideoUrl(post) ||
      switch (extractor) {
        final ExactVideoUrlExtractor resolver => resolver.canResolveExactVideo(
          post,
        ),
        _ => false,
      };
}

Future<DownloadUrlData?> _resolveVideoUrl(
  Post post,
  DownloadFileUrlExtractor extractor,
  CancelToken? cancelToken,
) async {
  final direct = _directVideoUrl(post);
  if (extractor is UrlInsidePostExtractor) {
    return direct == null ? null : DownloadUrlData.urlOnly(direct);
  }
  final resolved = await awaitShareOrCancellation(
    extractor.getDownloadFileUrl(post: post, quality: 'original'),
    cancelToken,
  );
  if (_isExactVideoResult(post, extractor, resolved?.url)) return resolved;
  return direct == null ? resolved : DownloadUrlData.urlOnly(direct);
}

Future<DownloadUrlData> resolveShareMediaUrl({
  required SharePayload payload,
  required Post post,
  required DownloadFileUrlExtractor extractor,
  CancelToken? cancelToken,
}) async {
  if (payload.id == SharePayloadId.original &&
      !hasExactOriginalSource(post, extractor)) {
    throw const ShareMediaException(ShareMediaFailure.unavailable);
  }
  DownloadUrlData? result;
  if (payload.id == SharePayloadId.video &&
      !hasExactVideoSource(post, extractor)) {
    throw const ShareMediaException(ShareMediaFailure.unavailable);
  }
  try {
    result = switch (payload.id) {
      SharePayloadId.image => switch (payload.value) {
        final String url => DownloadUrlData.urlOnly(url),
        _ => null,
      },
      SharePayloadId.original => await awaitShareOrCancellation(
        extractor.getDownloadFileUrl(post: post, quality: 'original'),
        cancelToken,
      ),
      SharePayloadId.video => await _resolveVideoUrl(
        post,
        extractor,
        cancelToken,
      ),
      _ => null,
    };
  } on ShareMediaException {
    rethrow;
  } on DioException catch (error) {
    if (CancelToken.isCancel(error)) {
      throw const ShareMediaException(ShareMediaFailure.cancelled);
    }
    if (error.response?.statusCode == 401 ||
        error.response?.statusCode == 403) {
      throw const ShareMediaException(ShareMediaFailure.authentication);
    }
    throw const ShareMediaException(ShareMediaFailure.network);
  } on Exception {
    throw const ShareMediaException(ShareMediaFailure.network);
  }
  final uri = Uri.tryParse(result?.url ?? '');
  checkShareCancellation(cancelToken);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      (payload.id == SharePayloadId.video &&
          !_isExactVideoResult(post, extractor, result?.url))) {
    throw const ShareMediaException(ShareMediaFailure.unavailable);
  }
  return result!;
}
