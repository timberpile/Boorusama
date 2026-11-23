// Package imports:
import 'package:collection/collection.dart';

// Project imports:
import '../../../post/types.dart';
import 'pool_details_order.dart';

extension PoolPostIdsX<T extends Post> on PostRepository<T> {
  Future<PostResult<T>> fetchPostIds({
    required List<int> ids,
    required int page,
    required int perPage,
    required PoolDetailsOrder order,
  }) async {
    if (page < 1) throw ArgumentError.value(page, 'page');
    if (perPage < 1) throw ArgumentError.value(perPage, 'perPage');
    final sortedIds = _sortPostIds(ids, order);
    final paginatedIds = _paginate(sortedIds, page, perPage);
    final maxPage = (sortedIds.length + perPage - 1) ~/ perPage;

    if (paginatedIds.isEmpty) {
      return <T>[].toResult(
        total: sortedIds.length,
        maxPage: maxPage,
        hasMore: false,
      );
    }

    final result = await getPosts('id:${paginatedIds.join(',')}', 1).run().then(
      (value) => value.fold(
        (error) => throw error,
        (r) => r,
      ),
    );

    final ordered = <T>[];
    for (final id in paginatedIds) {
      final post = result.posts.firstWhereOrNull((post) => post.id == id);
      if (post != null) {
        ordered.add(post);
      }
    }

    // Missing/deleted/restricted IDs do not change the remaining ID slices.
    return ordered.toResult(
      total: sortedIds.length,
      maxPage: maxPage,
      hasMore: page < maxPage,
    );
  }

  List<int> _sortPostIds(List<int> ids, PoolDetailsOrder order) {
    final postIds = [...ids];

    return switch (order) {
      PoolDetailsOrder.latest => postIds.sorted((a, b) => b.compareTo(a)),
      PoolDetailsOrder.oldest => postIds.sorted((a, b) => a.compareTo(b)),
      PoolDetailsOrder.order => postIds,
    };
  }

  List<int> _paginate(List<int> ids, int page, int perPage) {
    final start = (page - 1) * perPage;
    var end = start + perPage;

    if (start >= ids.length) {
      return [];
    }

    if (end > ids.length) {
      end = ids.length;
    }

    return ids.sublist(start, end);
  }
}
