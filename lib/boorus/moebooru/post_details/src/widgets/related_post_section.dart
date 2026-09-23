// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/widgets.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../core/configs/config/providers.dart';
import '../../../../../core/posts/details/routes.dart';
import '../../../../../core/posts/details/types.dart';
import '../../../../../core/posts/details_parts/widgets.dart';
import '../../../../../core/posts/post/types.dart';
import '../../../../../core/search/search/routes.dart';
import '../../providers.dart';

class MoebooruRelatedPostsSection extends ConsumerWidget {
  const MoebooruRelatedPostsSection({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);
    final params = (ref.watchConfigSearch, post);

    final postsAsync = ref.watch(moebooruPostDetailsChildrenProvider(params));

    return postsAsync.maybeWhen(
      data: (posts) => posts != null
          ? SliverRelatedPostsSection(
              posts: posts,
              imageUrl: (item) => item.sampleImageUrl,
              onViewAll: () => goToSearchPage(
                ref,
                tag: post.relationshipQuery,
              ),
              onTap: (index) => goToPostDetailsPageFromPosts(
                ref: ref,
                posts: posts,
                initialIndex: index,
                initialThumbnailUrl: posts[index].sampleImageUrl,
              ),
            )
          : const SliverSizedBox(),
      orElse: () => const SliverSizedBox(),
    );
  }
}
