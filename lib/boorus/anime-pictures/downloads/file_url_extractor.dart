// Package imports:
import 'dart:collection';

import 'package:booru_clients/anime_pictures.dart';

// Project imports:
import '../../../core/downloads/urls/types.dart';
import '../../../core/posts/post/types.dart';
import '../../../foundation/caching.dart';

class AnimePicturesDownloadFileUrlExtractor
    implements DownloadFileUrlExtractor, ExactOriginalUrlExtractor {
  AnimePicturesDownloadFileUrlExtractor({
    required this.client,
  });

  final AnimePicturesClient client;

  @override
  bool canResolveExactOriginal(Post post) => true;

  final _pending = <int, Future<DownloadUrlData?>>{};
  final _mediaPostIds = LinkedHashMap<String, int>();

  /// The existing cache owns credentials only in memory, scoped to this client.
  /// Matching the complete resolved URL prevents sending its cookie elsewhere.
  String? cookieForMediaUrl(String url) {
    final id = _mediaPostIds[url];
    if (id == null) return null;
    final data = cache.get(id.toString());
    if (data == null || data.url != url) {
      _mediaPostIds.remove(url);
      return null;
    }
    return data.cookie;
  }

  @override
  Future<DownloadUrlData?> getDownloadFileUrl({
    required Post post,
    required String quality,
  }) => resolveOriginal(post.id);

  Future<DownloadUrlData?> resolveOriginal(
    int postId, {
    PostDetailsDto? details,
  }) {
    final cached = cache.get(postId.toString());
    if (cached != null) return Future.value(cached);
    return _pending.putIfAbsent(postId, () async {
      try {
        final data = await client.getDownloadUrl(postId, details: details);
        if (data == null) return null;
        final resolved = DownloadUrlData(
          url: data.url,
          cookie: data.cookie,
          resolvedQuality: 'original',
        );
        cache.set(postId.toString(), resolved);
        _mediaPostIds[Uri.parse(data.url).toString()] = postId;
        while (_mediaPostIds.length > cache.maxCapacity)
          _mediaPostIds.remove(_mediaPostIds.keys.first);
        return resolved;
      } finally {
        _pending.remove(postId);
      }
    });
  }

  final Cache<DownloadUrlData> cache = Cache(
    maxCapacity: 10,
    staleDuration: const Duration(minutes: 5),
  );
}
