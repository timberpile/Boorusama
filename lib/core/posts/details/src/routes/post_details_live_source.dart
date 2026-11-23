import 'package:flutter/foundation.dart';

import '../../../post/types.dart';
import '../types/viewer_entry.dart';

class PostDetailsLiveSource {
  const PostDetailsLiveSource({
    required this.changes,
    required this.posts,
    required this.hasMore,
    required this.loading,
    required this.failed,
    required this.fetchMore,
  });

  final Listenable changes;
  final Iterable<Post> Function() posts;
  final bool Function() hasMore;
  final bool Function() loading;
  final bool Function() failed;
  final Future<void> Function() fetchMore;
}

/// The originating display projection owns grouping and occurrence identity.
class ViewerEntryLiveSource {
  const ViewerEntryLiveSource({
    required this.changes,
    required this.entries,
    required this.pagination,
  });
  final Listenable changes;
  final List<ViewerEntry> Function() entries;
  final PostDetailsLiveSource pagination;
}
