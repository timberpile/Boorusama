import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../configs/config/types.dart';
import '../../../content/types.dart';
import '../../../posts/post/types.dart';
import 'pool_bookmark.dart';

/// Engine-owned collection metadata and navigation. Core bookmarks never
/// interpret an engine payload, infer Series from tags, or borrow active auth.
abstract interface class PoolBookmarkCapability {
  Future<RemoteBookmarkPool?> getBookmarkPool(BooruConfig config, int id);

  /// Callers submit at most [membershipBudget] posts in one bounded admission.
  /// Return an empty list for a confirmed absence; omitted IDs remain unknown.
  Future<Map<int, List<RemoteBookmarkPool>>> getBookmarkSeries(
    BooruConfig config,
    List<Post> posts,
  );

  Future<void> openBookmarkPool(WidgetRef ref, BooruConfig config, int id);

  // Membership lookup is independent of the configured post request size.
  // Admit a whole supported search page, including the 200-post setting.
  static const membershipBudget = 200;
}

final class RemoteBookmarkPool {
  const RemoteBookmarkPool({
    required this.id,
    required this.title,
    required this.category,
    required this.total,
    this.supportsUploadOrder = false,
    this.loadedDetails,
    this.cachedMembers = const [],
    this.memberOrderDigest,
  });
  final int id;
  final String title;
  final BookmarkedPoolCategory category;
  final int? total;
  final bool supportsUploadOrder;
  final ContentGroupDetails? loadedDetails;
  final List<Post> cachedMembers;

  /// Source-authoritative order, never a sampled/search member window.
  final String? memberOrderDigest;
}
