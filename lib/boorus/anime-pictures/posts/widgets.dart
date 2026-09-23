// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/widgets.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/posts/details/routes.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/details_parts/widgets.dart';
import '../../../core/posts/post/types.dart';
import 'parser.dart';
import 'providers.dart';

class AnimePicturesRelatedPostsSection extends ConsumerWidget {
  const AnimePicturesRelatedPostsSection({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = PostDetails.of<Post>(context).posts;
    final post = InheritedPost.of<Post>(context);
    final configAuth = ref.watchConfigAuth;
    final configViewer = ref.watchConfigViewer;
    final params = (configAuth, post.id);
    final mediaUrlResolver = ref.watch(
      animePicturesMediaUrlResolverProvider(configAuth),
    );

    return ref
        .watch(postDetailsProvider(params))
        .when(
          data: (details) => details.tied != null && details.tied!.isNotEmpty
              ? SliverRelatedPostsSection(
                  posts: details.tied!.map(dtoToAnimePicturesPost).toList(),
                  imageUrl: (post) =>
                      mediaUrlResolver.resolveMediaUrl(post, configViewer),
                  onTap: (index) => goToPostDetailsPageFromPosts(
                    ref: ref,
                    posts: posts,
                    initialIndex: index,
                    initialThumbnailUrl: mediaUrlResolver.resolveMediaUrl(
                      posts[index],
                      configViewer,
                    ),
                  ),
                )
              : const SliverSizedBox.shrink(),
          error: (e, _) => const SliverSizedBox.shrink(),
          loading: () => const SliverSizedBox.shrink(),
        );
  }
}
