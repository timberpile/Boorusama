import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import 'pool_bookmark.dart';

/// Engine-owned collection metadata and navigation. Core bookmarks never
/// interpret an engine payload, infer Series from tags, or borrow active auth.
abstract interface class PoolBookmarkCapability {
  Future<RemoteBookmarkPool?> getBookmarkPool(BooruConfig config, int id);

  /// Callers submit at most [membershipBudget] posts in one bounded admission.
  Future<Map<int, List<RemoteBookmarkPool>>> getBookmarkSeries(
    BooruConfig config,
    List<Post> posts,
  );

  Future<void> openBookmarkPool(WidgetRef ref, BooruConfig config, int id);

  static const membershipBudget = 40;
}

final class RemoteBookmarkPool {
  const RemoteBookmarkPool({
    required this.id,
    required this.title,
    required this.category,
    required this.total,
    this.supportsUploadOrder = false,
  });
  final int id;
  final String title;
  final BookmarkedPoolCategory category;
  final int? total;
  final bool supportsUploadOrder;
}
