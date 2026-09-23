// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../../core/configs/config/providers.dart';
import '../../../../../../core/configs/config/types.dart';
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
    extra: DanbooruTagEditRouteData(post: post, config: ref.readConfig),
  );
}

class DanbooruTagEditRouteData {
  const DanbooruTagEditRouteData({required this.post, required this.config});

  final Post post;
  final BooruConfig config;
}
