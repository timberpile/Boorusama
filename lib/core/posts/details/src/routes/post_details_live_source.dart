import 'package:flutter/foundation.dart';

import '../../../post/types.dart';

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
