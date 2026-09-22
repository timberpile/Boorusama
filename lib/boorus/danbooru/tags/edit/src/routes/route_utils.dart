// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../../core/router.dart';
import '../../../../../../core/posts/post/types.dart';

void goToTagEditPage(
  WidgetRef ref, {
  required Post post,
}) {
  ref.router.push(
    Uri(
      pathSegments: [
        '',
        'internal',
        'danbooru',
        'posts',
        '${post.id}',
        'editor',
      ],
    ).toString(),
    extra: post,
  );
}
