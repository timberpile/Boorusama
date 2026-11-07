import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../configs/config/types.dart';
import '../../../content/types.dart';
import '../../../posts/post/types.dart';
import '../../../settings/src/types/utils.dart' show maxPostsPerPage;
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

  // Membership lookup is independent of the configured post request size.
  // Admit a whole supported search page, including the 200-post setting.
  static const membershipBudget = maxPostsPerPage;
}

final class RemoteBookmarkPool {
  const RemoteBookmarkPool({
    required this.id,
    required this.title,
    required this.category,
    required this.total,
    this.supportsUploadOrder = false,
    this.loadedDetails,
  });
  final int id;
  final String title;
  final BookmarkedPoolCategory category;
  final int? total;
  final bool supportsUploadOrder;
  final ContentGroupDetails? loadedDetails;
}
