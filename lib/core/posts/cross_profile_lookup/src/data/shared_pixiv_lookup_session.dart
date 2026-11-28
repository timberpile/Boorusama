import '../../../post/providers.dart';
import '../../../../configs/config/types.dart';
import '../types/lookup_result.dart';
import '../types/pixiv_artwork_reference.dart';
import 'exact_post_lookup.dart';
import 'source_post_lookup.dart';
import 'pixiv_lookup_capabilities.dart';
import 'pixiv_original_hashes.dart';

final class _TargetCursor {
  var sourceVariant = 0;
  var sourcePage = 1;
  var sourceMatched = false;
  var hashIndex = 0;
  var hashPage = 1;
  var nextPage = 1;
  final seen = <int>{};
}

/// Automatic artwork search checks source candidates before matching original
/// bytes. Explicit methods have independent cursors and share the hash cache.
class SharedPixivLookupSession {
  SharedPixivLookupSession({
    required this.artwork,
    required this.lookup,
    this.exactLookup,
    this.resolveHashes,
  });
  final PixivArtworkReference artwork;
  final Future<SourcePostLookup> Function(BooruConfig) lookup;
  final Future<ExactPostLookup> Function(BooruConfig)? exactLookup;
  final Future<PixivOriginalHashes> Function()? resolveHashes;
  final _cursors = <(String, PostLookupMatchKind?), _TargetCursor>{};
  Future<PixivOriginalHashes>? _hashes;

  Future<PostLookupResult> find(
    BooruConfig target, {
    int page = 1,
    required PostLookupCancellation cancellation,
    PostLookupMatchKind? method,
  }) async {
    if (page < 1) throw ArgumentError.value(page, 'page', 'Must be positive');
    if (cancellation.isCancelled) return const PostLookupCancelled();
    final origin = postOriginFromConfig(target);
    final queries = pixivSourceQueries(origin, artwork.id);
    if (!supportsSharedPixivOrigin(origin) ||
        (method == PostLookupMatchKind.pixivSource && queries.isEmpty) ||
        (method != null &&
            method != PostLookupMatchKind.pixivSource &&
            method != PostLookupMatchKind.exactFile)) {
      return const PostLookupUnavailable(
        PostLookupUnavailableReason.unsupported,
      );
    }
    final key = (target.id, method);
    if (page == 1) _cursors[key] = _TargetCursor();
    final cursor = _cursors[key];
    if (cursor == null || cursor.nextPage != page) {
      return const PostLookupInvalidResponse();
    }
    bool cancelled() => cancellation.isCancelled || _cursors[key] != cursor;
    PostLookupPage wrap(
      PostLookupPage result,
      bool hasMore, {
      PixivLookupCoverageIssue? issue,
    }) {
      cursor.nextPage++;
      return PostLookupPage(
        targetOrigin: origin,
        posts: result.posts.where((post) => cursor.seen.add(post.id)).toList(),
        page: page,
        hasMore: hasMore,
        hasFilteredMatches: result.hasFilteredMatches,
        matchKind: result.matchKind,
        coverageIssue: issue,
      );
    }

    PostLookupPage empty(PostLookupMatchKind kind) => PostLookupPage(
      targetOrigin: origin,
      posts: const [],
      page: page,
      hasMore: false,
      hasFilteredMatches: false,
      matchKind: kind,
    );
    try {
      while (method != PostLookupMatchKind.exactFile &&
          cursor.sourceVariant < queries.length) {
        final service = await lookup(target);
        if (cancelled()) return const PostLookupCancelled();
        final result = await service.findArtwork(
          artwork.id,
          variant: cursor.sourceVariant,
          page: cursor.sourcePage,
          cancellation: cancellation,
        );
        if (cancelled()) return const PostLookupCancelled();
        if (result is! PostLookupPage) return result;
        cursor.sourceMatched |=
            result.posts.isNotEmpty || result.hasFilteredMatches;
        if (result.hasMore) {
          cursor.sourcePage++;
          return wrap(result, true);
        }
        cursor.sourceVariant++;
        cursor.sourcePage = 1;
        if (result.posts.isNotEmpty) {
          return wrap(result, cursor.sourceVariant < queries.length);
        }
      }
      if (cursor.sourceMatched || method == PostLookupMatchKind.pixivSource) {
        return wrap(empty(PostLookupMatchKind.pixivSource), false);
      }
      final resolve = resolveHashes;
      final hashes = await (_hashes ??= resolve == null
          ? Future.value(
              const PixivOriginalHashes(
                [],
                issue: PixivLookupCoverageIssue.authentication,
              ),
            )
          : resolve());
      if (cancelled()) return const PostLookupCancelled();
      final exact = exactLookup;
      if (hashes.hashes.isEmpty || exact == null) {
        return wrap(
          empty(PostLookupMatchKind.exactFile),
          false,
          issue: hashes.issue ?? PixivLookupCoverageIssue.originalsUnavailable,
        );
      }
      while (cursor.hashIndex < hashes.hashes.length) {
        final service = await exact(target);
        if (cancelled()) return const PostLookupCancelled();
        final result = await service.findHash(
          hashes.hashes[cursor.hashIndex],
          page: cursor.hashPage,
          cancellation: cancellation,
        );
        if (cancelled()) return const PostLookupCancelled();
        if (result is! PostLookupPage) return result;
        if (result.hasMore) {
          cursor.hashPage++;
          return wrap(result, true, issue: hashes.issue);
        }
        cursor.hashIndex++;
        cursor.hashPage = 1;
        if (result.posts.isNotEmpty) {
          return wrap(
            result,
            cursor.hashIndex < hashes.hashes.length,
            issue: hashes.issue,
          );
        }
      }
      return wrap(
        empty(PostLookupMatchKind.exactFile),
        false,
        issue: hashes.issue,
      );
    } catch (error) {
      return cancelled()
          ? const PostLookupCancelled()
          : PostLookupFailed(error);
    }
  }
}
