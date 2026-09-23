// Project imports:
import '../../../../../core/posts/post/types.dart';

extension DanbooruRepoX on PostRepository<Post> {
  PostsOrError<Post> getPostsFromIds(List<int> ids) => getPosts(
    'id:${ids.join(',')}',
    1,
    limit: ids.length,
  );
}
