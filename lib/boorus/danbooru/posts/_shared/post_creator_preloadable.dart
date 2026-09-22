// Project imports:
import '../post/types.dart';
import '../../../../core/posts/post/types.dart';

class PostCreatorsPreloadable {
  factory PostCreatorsPreloadable.fromPosts(List<DanbooruPost> posts) {
    final ids = posts
        .map(
          (e) => [
            e.uploaderId,
            if (e.approverId != null) e.approverId!,
          ],
        )
        .expand((e) => e)
        .toSet()
        .toList();

    return PostCreatorsPreloadable._(ids);
  }

  factory PostCreatorsPreloadable.fromUnifiedPost(UnifiedPost post) {
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
