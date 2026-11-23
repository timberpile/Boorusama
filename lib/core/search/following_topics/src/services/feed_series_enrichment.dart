import 'dart:async';

import '../../../../bookmarks/src/types/pool_bookmark.dart';
import '../../../../bookmarks/src/types/pool_bookmark_capability.dart';
import '../../../../boorus/booru/types.dart';
import '../../../../configs/config/types.dart';
import '../../../../posts/post/types.dart';
import '../types/feed_series_membership.dart';
import '../types/following_topic.dart';

/// Called only during an authorized refresh/history request, never by rendering.
/// Bulk results are partial: only explicitly returned Post IDs are authoritative.
Future<Map<String, FeedSeriesMembership>> enrichFeedSeries({
  required BooruConfig config,
  required FollowingTopic source,
  required Iterable<Post> posts,
  required PoolBookmarkCapability? capability,
  required bool Function() isCurrent,
  Duration timeout = const Duration(seconds: 10),
}) async {
  if (config.auth.booruType != BooruType.danbooru ||
      capability == null ||
      !isCurrent()) {
    return {};
  }
  final unique = {
    for (final post in posts)
      if (post.id > 0 && feedSeriesMatchesConfig(post.origin, config))
        post.id: post,
  }.values.toList();
  final result = <String, FeedSeriesMembership>{};
  var active = true;
  Future<void> collect() async {
    for (
      var start = 0;
      start < unique.length;
      start += PoolBookmarkCapability.membershipBudget
    ) {
      if (!active || !isCurrent()) return;
      final batch = unique
          .skip(start)
          .take(PoolBookmarkCapability.membershipBudget)
          .toList();
      try {
        final memberships = await capability.getBookmarkSeries(config, batch);
        if (!active || !isCurrent()) return;
        for (final post in batch) {
          final pools = memberships[post.id];
          if (pools == null ||
              pools.any(
                (pool) =>
                    pool.id <= 0 ||
                    pool.category == BookmarkedPoolCategory.unknown,
              )) {
            continue;
          }
          final entry = FeedSeriesMembership(
            origin: post.origin,
            postId: post.id,
            sourceId: source.id,
            sourceRevision: source.runtimeRevision,
            series: [
              for (final pool in pools)
                if (pool.id > 0 &&
                    pool.category == BookmarkedPoolCategory.series)
                  FeedSeriesSummary(
                    id: pool.id,
                    title: pool.title,
                    total: (pool.total ?? -1) >= 0 ? pool.total : null,
                  ),
            ],
          );
          result[entry.key] = entry;
        }
      } on Object {
        // Posts and successfully resolved batches remain usable after a failure.
      }
    }
  }

  try {
    // One deadline covers the entire enrichment, not ten seconds per batch.
    await collect().timeout(timeout);
  } on TimeoutException {
    // Completed batches remain authoritative; the outstanding batch is unknown.
  } finally {
    active = false;
  }
  return isCurrent() ? result : {};
}
