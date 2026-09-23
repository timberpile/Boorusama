// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../search/queries/types.dart';
import '../../../../search/selected_tags/types.dart';
import '../types/post.dart';
import '../types/post_origin.dart';
import '../types/post_repository.dart';

class OriginAwarePostRepository implements PostRepository<Post> {
  const OriginAwarePostRepository({
    required this.delegate,
    required this.origin,
  });

  factory OriginAwarePostRepository.fromConfig({
    required PostRepository<Post> delegate,
    required BooruConfig config,
  }) => OriginAwarePostRepository(
    delegate: delegate,
    origin: PostOrigin.fromSource(
      booruType: config.auth.booruType,
      booruId: config.booruId,
      source: config.url,
      profileIdHint: config.id,
    ),
  );

  final PostRepository<Post> delegate;
  final PostOrigin origin;

  @override
  TagQueryComposer get tagComposer => delegate.tagComposer;

  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => delegate
      .getPosts(tags, page, limit: limit, options: options)
      .map(_convertResult);

  @override
  PostsOrError<Post> getPostsFromController(
    SearchTagSet controller,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => delegate
      .getPostsFromController(
        controller,
        page,
        limit: limit,
        options: options,
      )
      .map(_convertResult);

  @override
  PostOrError<Post> getPost(
    PostId id, {
    PostFetchOptions? options,
  }) => delegate
      .getPost(id, options: options)
      .map((post) => post?.copyWith(origin: origin));

  PostResult<Post> _convertResult(PostResult<Post> result) =>
      bindPostResultOrigin(result, origin: origin);
}

PostResult<Post> bindPostResultOrigin(
  PostResult<Post> result, {
  required PostOrigin origin,
}) => PostResult(
  posts: result.posts
      .map((post) => post.copyWith(origin: origin))
      .toList(growable: false),
  total: result.total,
  maxPage: result.maxPage,
  hasMore: result.hasMore,
);
