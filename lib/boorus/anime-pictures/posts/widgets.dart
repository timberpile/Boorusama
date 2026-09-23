// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/widgets.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/posts/details/routes.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/details_parts/widgets.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import 'parser.dart';
import 'providers.dart';

class AnimePicturesRelatedPostsSection extends ConsumerWidget {
  const AnimePicturesRelatedPostsSection({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);
    final config = ref.watchConfig;
    final configAuth = config.auth;
    final configViewer = ref.watchConfigViewer;
    final params = (configAuth, post.id);
    final mediaUrlResolver = ref.watch(
      animePicturesMediaUrlResolverProvider(configAuth),
    );

    return ref
        .watch(postDetailsProvider(params))
        .when(
          data: (details) {
            final tied = details.tied;
            if (tied == null || tied.isEmpty) {
              return const SliverSizedBox.shrink();
            }

            final relatedPosts = bindPostsOrigin(
              tied.map(dtoToAnimePicturesPost),
              origin: postOriginFromConfig(config),
            );
            return SliverRelatedPostsSection(
              posts: relatedPosts,
              imageUrl: (post) =>
                  mediaUrlResolver.resolveMediaUrl(post, configViewer),
              onTap: (index) => goToPostDetailsPageFromPosts(
                ref: ref,
                posts: relatedPosts,
                initialIndex: index,
                initialThumbnailUrl: mediaUrlResolver.resolveMediaUrl(
                  relatedPosts[index],
                  configViewer,
                ),
              ),
            );
          },
          error: (e, _) => const SliverSizedBox.shrink(),
          loading: () => const SliverSizedBox.shrink(),
        );
  }
}
