import '../../../../boorus/booru/types.dart';
import '../../../../errors/error.dart';
import '../../../post/types.dart';
import '../../../sources/types.dart';
import '../types/lookup_result.dart';
import 'exact_post_lookup.dart';
import 'pixiv_lookup_capabilities.dart';
import '../types/source_reference.dart';
import '../types/pixiv_artwork_reference.dart';

export '../types/source_reference.dart';

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
  }) => findReference(
    source.source.url,
    kind: kind,
    page: page,
    cancellation: cancellation,
  );

  Future<PostLookupResult> findArtwork(
    String id, {
    required int variant,
    int page = 1,
    required PostLookupCancellation cancellation,
  }) {
    final queries = pixivSourceQueries(targetOrigin, id);
    if (variant < 0 || variant >= queries.length) {
      return Future.value(
        const PostLookupUnavailable(
          PostLookupUnavailableReason.unsupported,
        ),
      );
    }
    return _search(
      queries[variant],
      id: id,
      kind: PostLookupMatchKind.pixivSource,
      page: page,
      cancellation: cancellation,
      requireSourceIdentity: true,
    );
  }

  Future<PostLookupResult> findReference(
    String? sourceUrl, {
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
    final id = pixivArtworkId(sourceUrl);
    final url = lookupSourceUrl(sourceUrl);
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
    return _search(
      query,
      id: id,
      url: url,
      kind: kind,
      page: page,
      cancellation: cancellation,
    );
  }

  Future<PostLookupResult> _search(
    String query, {
    String? id,
    String? url,
    required PostLookupMatchKind kind,
    required int page,
    required PostLookupCancellation cancellation,
    bool requireSourceIdentity = false,
  }) async {
    if (page < 1) throw ArgumentError.value(page, 'page', 'Must be positive');
    if (cancellation.isCancelled) return const PostLookupCancelled();
    if (targetOrigin.sourceHost.isEmpty ||
        (targetOrigin.profileIdHint?.trim().isEmpty ?? true)) {
      return const PostLookupUnavailable(
        PostLookupUnavailableReason.invalidTarget,
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
          if (result.posts.any(
            (post) => post.id <= 0 || post.origin != targetOrigin,
          )) {
            return const PostLookupInvalidResponse();
          }
          if (requireSourceIdentity &&
              result.posts.any(
                (post) =>
                    PixivArtworkReference.parseSharedText(
                      post.source.url?.replaceAll('&amp;', '&'),
                    ) ==
                    null,
              )) {
            return const PostLookupInvalidResponse();
          }
          final matches = result.posts
              .where(
                (post) => switch (kind) {
                  PostLookupMatchKind.pixivSource =>
                    (requireSourceIdentity
                            ? PixivArtworkReference.parseSharedText(
                                post.source.url?.replaceAll('&amp;', '&'),
                              )?.id
                            : pixivArtworkId(post.source.url)) ==
                        id,
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
