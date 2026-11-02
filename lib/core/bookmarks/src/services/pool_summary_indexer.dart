import '../../../posts/post/types.dart';
import '../types/pool_bookmark.dart';

typedef PoolMemberFetcher = Future<List<Post>> Function(
  String query,
  int limit,
);

/// At most three metadata requests, at most 42 returned members, no media and
/// no pagination. Failed requests remain unknown instead of proving absence.
final class PoolSummaryIndexer {
  const PoolSummaryIndexer({required this.fetch});

  static const memberBudget = 40;
  final PoolMemberFetcher fetch;

  Future<PoolSummaryIndex> index({
    required int poolId,
    required int? total,
    required bool supportsUploadOrder,
  }) async {
    final members = await _tryFetch('pool:$poolId', memberBudget);
    var hasFailedRequests = members == null;
    final unique = {for (final post in members ?? <Post>[]) post.id: post};
    final complete =
        members != null &&
        total != null &&
        total <= memberBudget &&
        unique.length == total;
    final dates = unique.values.map((p) => p.createdAt).nonNulls.toList()
      ..sort();
    DateTime? oldest = complete && dates.length == unique.length
        ? dates.firstOrNull
        : null;
    DateTime? newest = complete && dates.length == unique.length
        ? dates.lastOrNull
        : null;
    if (!complete && supportsUploadOrder) {
      final descending = await _tryFetch('pool:$poolId order:created_at', 1);
      final ascending = await _tryFetch('pool:$poolId order:created_at_asc', 1);
      hasFailedRequests |= descending == null || ascending == null;
      newest = descending?.firstOrNull?.createdAt;
      oldest = ascending?.firstOrNull?.createdAt;
    }
    // Inconsistent source responses must not fabricate an interval.
    if (oldest != null && newest != null && oldest.isAfter(newest)) {
      oldest = null;
      newest = null;
    }
    return PoolSummaryIndex(
      hasFailedRequests: hasFailedRequests,
      members: unique.values.toList(),
      tags: {for (final post in unique.values) ...post.tags},
      coverage: complete
          ? PoolTagCoverage.complete
          : unique.isNotEmpty
          ? PoolTagCoverage.partial
          : PoolTagCoverage.unknown,
      oldestUpload: oldest,
      newestUpload: newest,
    );
  }

  Future<List<Post>?> _tryFetch(String query, int limit) async {
    try {
      // Enforce the bound even if a server ignores its requested limit.
      return (await fetch(query, limit)).take(limit).toList();
    } catch (_) {
      return null;
    }
  }
}

/// Members only live during indexing so the caller can select a safe cover.
/// Only its bounded summary, never this object, is persisted.
final class PoolSummaryIndex {
  const PoolSummaryIndex({
    required this.hasFailedRequests,
    required this.members,
    required this.tags,
    required this.coverage,
    required this.oldestUpload,
    required this.newestUpload,
  });
  final bool hasFailedRequests;
  final List<Post> members;
  final Set<String> tags;
  final PoolTagCoverage coverage;
  final DateTime? oldestUpload;
  final DateTime? newestUpload;
}
