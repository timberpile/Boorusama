import 'post.dart';
import 'unified_post.dart';

String postViewerIdentity(Post post) => switch (post) {
  UnifiedPost(:final origin) =>
    '${origin.booruType.id}:${origin.booruId}:${origin.sourceHost}:${post.id}',
  _ => '${post.id}',
};

String postHeroTag(Post post) => '${postViewerIdentity(post)}_hero';
