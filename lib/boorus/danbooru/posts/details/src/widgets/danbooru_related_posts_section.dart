// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/posts/details/routes.dart';
import '../../../../../../core/posts/details_parts/widgets.dart';
import '../../../../../../core/posts/post/types.dart';
import '../../../../../../core/posts/related/related_family.dart';
import '../../../related/related_gallery.dart';
import '../../../post/types.dart';

class DanbooruRelatedPostsSection extends ConsumerWidget {
  const DanbooruRelatedPostsSection({
    required this.currentPost,
    required this.posts,
    super.key,
  });

  final Post currentPost;
  final List<Post> posts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverRelatedPostsSection(
      posts: posts,
      imageUrl: (item) => item.url720x720,
      onViewAll: () =>
          openRelatedFamily(ref, RelatedFamilyReference.fromPost(currentPost)),
      onTap: (index) => goToPostDetailsPageFromPosts(
        ref: ref,
        posts: posts,
        initialIndex: index,
        initialThumbnailUrl: posts[index].url720x720,
      ),
    );
  }
}
