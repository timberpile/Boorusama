import '../../../../local_media/local_media_reference.dart';

import 'post.dart';

String postViewerIdentity(Post post) => switch (post.booruData) {
  LocalMediaPostData(:final reference) =>
    '${LocalMediaReference.namespace}${reference.sha256}',
  _ =>
    '${post.origin.booruType.id}:${post.origin.booruId}:'
        '${post.origin.sourceHost}:${post.id}',
};

String postHeroTag(Post post) => '${postViewerIdentity(post)}_hero';
