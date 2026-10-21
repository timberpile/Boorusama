import '../../../../boorus/booru/types.dart';
import '../../../../errors/error.dart';
import '../../../post/types.dart';
import '../../../sources/types.dart';
import '../types/lookup_result.dart';
import 'exact_post_lookup.dart';

/// Source matching never establishes identical file content. Validate the
/// returned metadata rather than trusting a site's metatag implementation.
final class SourcePostLookup {
  const SourcePostLookup({
    required this.repository,
    required this.targetOrigin,
    required this.isVisible,
  });
  final PostRepository<Post> repository;
  final PostOrigin targetOrigin;
  final bool Function(Post) isVisible;

  Future<PostLookupResult> find(
    Post source, {
    required PostLookupMatchKind kind,
    int page = 1,
    required PostLookupCancellation cancellation,
  }) async {
    if (page < 1) {
      throw ArgumentError.value(page, 'page', 'Must be positive');
    }
    if (cancellation.isCancelled) return const PostLookupCancelled();
    if (targetOrigin.sourceHost.isEmpty ||
        (targetOrigin.profileIdHint?.trim().isEmpty ?? true)) {
      return const PostLookupUnavailable(
        PostLookupUnavailableReason.invalidTarget,
      );
    }
    final id = pixivArtworkId(source.source.url);
    final url = lookupSourceUrl(source.source.url);
    final query = switch (kind) {
      PostLookupMatchKind.pixivSource
          when targetOrigin.booruType == BooruType.danbooru && id != null =>
        'pixiv_id:$id',
      PostLookupMatchKind.sourceUrl
          when supportsSourceUrlLookup(targetOrigin.booruType) && url != null =>
        'source:$url',
      _ => null,
    };
    if (query == null) {
      return const PostLookupUnavailable(
        PostLookupUnavailableReason.unsupported,
      );
    }
    try {
      final response = await repository
          .getPosts(
            query,
            page,
            limit: ExactPostLookup.pageSize,
            options: PostFetchOptions.raw,
          )
          .run();
      if (cancellation.isCancelled) return const PostLookupCancelled();
      return response.fold(
        (error) => error is RequestCancelledError
            ? const PostLookupCancelled()
            : PostLookupFailed(error),
        (result) {
          if (result.posts.any((post) => post.origin != targetOrigin)) {
            return const PostLookupInvalidResponse();
          }
          final matches = result.posts
              .where(
                (post) => switch (kind) {
                  PostLookupMatchKind.pixivSource =>
                    pixivArtworkId(post.source.url) == id,
                  _ => lookupSourceUrl(post.source.url) == url,
                },
              )
              .toList();
          // A source search may return prefix matches. Do not display those as
          // exact source matches; keep pagination based on the unfiltered page.
          final visible = <int, Post>{};
          var filtered = false;
          for (final post in matches) {
            if (isVisible(post)) {
              visible[post.id] = post;
            } else {
              filtered = true;
            }
          }
          return PostLookupPage(
            targetOrigin: targetOrigin,
            posts: visible.values.toList(),
            page: page,
            matchKind: kind,
            hasFilteredMatches: filtered,
            hasMore:
                result.hasMore ??
                switch (result.total) {
                  final total? when total >= 0 =>
                    page * ExactPostLookup.pageSize < total,
                  _ => result.posts.length >= ExactPostLookup.pageSize,
                },
          );
        },
      );
    } catch (error) {
      return cancellation.isCancelled || error is RequestCancelledError
          ? const PostLookupCancelled()
          : PostLookupFailed(error);
    }
  }
}

bool supportsSourceUrlLookup(BooruType type) =>
    type == BooruType.danbooru || type == BooruType.gelbooru;

/// Only single URL tokens are safe to interpolate into a site's search grammar.
/// Preserve query parameters and path case; they may identify a different work.
String? lookupSourceUrl(String? raw) {
  if (raw == null || raw.isEmpty || RegExp(r'''[\s*"'\\]''').hasMatch(raw)) {
    return null;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri.removeFragment().toString();
}

String? pixivArtworkId(String? raw) {
  final url = lookupSourceUrl(raw);
  if (url == null) return null;
  final uri = Uri.parse(url);
  final host = uri.host.toLowerCase();
  String? id;
  if (host == 'pixiv.net' || host.endsWith('.pixiv.net')) {
    id = RegExp(r'^/(?:[a-z]{2}/)?artworks/([0-9]+)/?$')
        .firstMatch(uri.path)
        ?.group(1);
    if (uri.path == '/member_illust.php') {
      id ??= uri.queryParameters['illust_id'];
    }
  }
  if (host == 'pximg.net' ||
      host.endsWith('.pximg.net') ||
      host.endsWith('.pixiv.net')) {
    id ??= RegExp(r'/([0-9]+)_p[0-9]+(?:_[a-zA-Z0-9]+)?\.[a-zA-Z0-9]+$')
        .firstMatch(uri.path)
        ?.group(1);
  }
  return id != null && RegExp(r'^[1-9][0-9]*$').hasMatch(id) ? id : null;
}
