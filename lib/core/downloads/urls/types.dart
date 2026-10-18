// Flutter imports:
import 'package:flutter/widgets.dart';

// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../posts/post/types.dart';

class DownloadUrlData extends Equatable {
  const DownloadUrlData({
    required this.url,
    required this.cookie,
    this.resolvedQuality,
  });

  const DownloadUrlData.urlOnly(
    this.url, {
    this.resolvedQuality,
  }) : cookie = null;

  final String url;
  final String? cookie;

  /// The selected media variant, which may differ from the requested quality.
  /// Null means the extractor did not establish a variant identity.
  final String? resolvedQuality;

  @override
  List<Object?> get props => [url, cookie, resolvedQuality];
}

abstract interface class DownloadFileUrlExtractor {
  Future<DownloadUrlData?> getDownloadFileUrl({
    required Post post,
    required String quality,
  });
}

abstract interface class ExactOriginalUrlExtractor {
  bool canResolveExactOriginal(Post post);
}

abstract interface class ExactVideoUrlExtractor {
  bool canResolveExactVideo(Post post);
}

abstract interface class DownloadSourceProvider {
  List<DownloadSource> getDownloadSources(BuildContext context, Post post);
}

class DownloadSource extends Equatable {
  const DownloadSource({
    required String url,
    required this.name,
    this.quality,
  }) : url = url;

  const DownloadSource.quality({
    required this.quality,
    required this.name,
  }) : url = null;

  /// Null selects the quality resolver; an empty concrete URL is invalid.
  final String? url;
  final String name;
  final String? quality;

  @override
  List<Object?> get props => [url, name, quality];
}
