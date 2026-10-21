// Project imports:
import '../../../../boorus/booru/types.dart';
import '../../../../errors/error.dart';
import '../../../post/types.dart';
import '../types/lookup_result.dart';

/// Exact-file lookup through one explicitly selected profile repository.
///
/// The caller must provide the target's origin-aware repository and visibility
/// policy. This service never selects an active profile, changes navigation,
/// downloads media, or falls back to tag/source/similarity searches.
final class ExactPostLookup {
  const ExactPostLookup({
    required PostRepository<Post> repository,
    required this.targetOrigin,
    required this.apiMode,
    required bool Function(Post) isVisible,
  }) : _repository = repository,
       _isVisible = isVisible;

  final PostRepository<Post> _repository;
  final PostOrigin targetOrigin;

  /// Opt out for HTML/scraping modes until their hash semantics are verified.
  final bool apiMode;
  final bool Function(Post) _isVisible;

  static const pageSize = 100;
  static final _md5Pattern = RegExp(r'^[0-9a-f]{32}$');

  bool get isSupported =>
      apiMode &&
      switch (targetOrigin.booruType) {
        BooruType.danbooru || BooruType.gelbooru => true,
        BooruType.gelbooruV2 => targetOrigin.sourceHost == 'rule34.xxx',
        _ => false,
      };

  Future<PostLookupResult> find(
    Post source, {
    int page = 1,
    PostLookupCancellation? cancellation,
  }) async {
    if (page < 1) {
      throw ArgumentError.value(page, 'page', 'Must be positive');
    }
    if (cancellation?.isCancelled ?? false) {
      return const PostLookupCancelled();
    }
    if (!isSupported) {
      return const PostLookupUnavailable(
        PostLookupUnavailableReason.unsupported,
      );
    }
    if (targetOrigin.sourceHost.isEmpty ||
        (targetOrigin.profileIdHint?.trim().isEmpty ?? true)) {
      return const PostLookupUnavailable(
        PostLookupUnavailableReason.invalidTarget,
      );
    }

    final hash = normalizeMd5(source.md5);
    if (hash == null) {
      return const PostLookupUnavailable(
        PostLookupUnavailableReason.missingHash,
      );
    }

    try {
      final response = await _repository
          .getPosts(
            'md5:$hash',
            page,
            limit: pageSize,
            // Do not cascade into unrelated requests or reuse a search controller.
            options: PostFetchOptions.raw,
          )
          .run();
      if (cancellation?.isCancelled ?? false) {
        return const PostLookupCancelled();
      }
      return response.fold<PostLookupResult>(
        (error) => error is RequestCancelledError
            ? const PostLookupCancelled()
            : PostLookupFailed(error),
        (result) => _validatePage(result, hash: hash, page: page),
      );
    } catch (error) {
      if (cancellation?.isCancelled ?? false) {
        return const PostLookupCancelled();
      }
      return error is RequestCancelledError
          ? const PostLookupCancelled()
          : PostLookupFailed(error);
    }
  }

  PostLookupResult _validatePage(
    PostResult<Post> result, {
    required String hash,
    required int page,
  }) {
    // A server may ignore an unknown metatag. Never label its normal feed as
    // matches, and never relabel source-account objects as target-account posts.
    for (final post in result.posts) {
      if (post.origin != targetOrigin || normalizeMd5(post.md5) != hash) {
        return const PostLookupInvalidResponse();
      }
    }

    final visible = <Post>[];
    final seen = <int>{};
    var hasFilteredMatches = false;
    for (final post in result.posts) {
      if (!_isVisible(post)) {
        hasFilteredMatches = true;
      } else if (seen.add(post.id)) {
        visible.add(post);
      }
    }

    // Use the unfiltered response for continuation. Hidden/duplicate posts do
    // not prove that the server has no more results.
    final hasMore =
        result.hasMore ??
        switch (result.total) {
          final total? when total >= 0 => page * pageSize < total,
          _ => result.posts.length >= pageSize,
        };
    return PostLookupPage(
      targetOrigin: targetOrigin,
      posts: visible,
      page: page,
      hasMore: hasMore,
      hasFilteredMatches: hasFilteredMatches,
    );
  }

  static String? normalizeMd5(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.length == 32 && _md5Pattern.hasMatch(normalized)
        ? normalized
        : null;
  }
}
