// Project imports:
import '../post/types.dart';
import '../../../../core/posts/post/types.dart';

class PostCreatorsPreloadable {
  factory PostCreatorsPreloadable.fromPosts(List<Post> posts) {
    final ids = posts
        .expand(
          (post) => [
            if (post.uploaderId case final id?) id,
            if (post.approverId case final id?) id,
          ],
        )
        .toSet()
        .toList();

    return PostCreatorsPreloadable._(ids);
  }

  factory PostCreatorsPreloadable.fromPost(Post post) {
    final data = post.booruData;
    final approverId = switch (data) {
      DanbooruPostData(:final approverId) => approverId,
      _ => null,
    };

    return PostCreatorsPreloadable._([
      if (post.uploaderId case final id?) id,
      if (approverId case final id?) id,
    ]);
  }
  PostCreatorsPreloadable._(this.userIds);

  final List<int> userIds;
}
