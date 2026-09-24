// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../core/configs/config/providers.dart';
import '../../../../../core/configs/config/types.dart';
import '../../../../../core/router.dart';
import '../../../../../core/posts/post/types.dart';

class DanbooruPostVersionRouteData {
  const DanbooruPostVersionRouteData({
    required this.post,
    required this.config,
  });

  final Post post;
  final BooruConfig config;
}

void goToPostVersionPage(WidgetRef ref, Post post) {
  ref.router.push(
    Uri(
      pathSegments: [
        '',
        'danbooru',
        'post_versions',
      ],
      queryParameters: {
        'search[post_id]': post.id.toString(),
      },
    ).toString(),
    extra: DanbooruPostVersionRouteData(
      post: post,
      config: ref.readConfig,
    ),
  );
}
