// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../../core/router.dart';
import '../../../../../../core/posts/post/types.dart';

void goToPostFavoritesDetails(WidgetRef ref, Post post) {
  ref.router.push(
    Uri(
      pathSegments: [
        '',
        'internal',
        'danbooru',
        'posts',
        '${post.id}',
        'favoriter',
      ],
    ).toString(),
  );
}

void goToPostVotesDetails(WidgetRef ref, Post post) {
  ref.router.push(
    Uri(
      pathSegments: [
        '',
        'internal',
        'danbooru',
        'posts',
        '${post.id}',
        'voter',
      ],
    ).toString(),
  );
}
