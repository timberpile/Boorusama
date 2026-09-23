import 'post.dart';

String postViewerIdentity(Post post) =>
    '${post.origin.booruType.id}:${post.origin.booruId}:'
    '${post.origin.sourceHost}:${post.id}';

String postHeroTag(Post post) => '${postViewerIdentity(post)}_hero';
