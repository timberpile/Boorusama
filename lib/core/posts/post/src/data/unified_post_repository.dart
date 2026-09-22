// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../search/queries/types.dart';
import '../../../../search/selected_tags/types.dart';
import '../types/booru_post_capability.dart';
import '../types/post.dart';
import '../types/post_origin.dart';
import '../types/post_repository.dart';
import '../types/unified_post.dart';

class UnifiedPostRepository<T extends Post>
    implements PostRepository<UnifiedPost> {
  const UnifiedPostRepository({
    required this.delegate,
    required this.origin,
    required this.converter,
  });

  factory UnifiedPostRepository.fromConfig({
    required PostRepository<T> delegate,
    required BooruConfig config,
    required PostToUnifiedConverter converter,
  }) => UnifiedPostRepository(
    delegate: delegate,
    origin: PostOrigin.fromSource(
      booruType: config.auth.booruType,
      booruId: config.booruId,
      source: config.url,
      profileIdHint: config.id,
    ),
    converter: converter,
  );

  final PostRepository<T> delegate;
  final PostOrigin origin;
  final PostToUnifiedConverter converter;

  @override
  TagQueryComposer get tagComposer => delegate.tagComposer;

  @override
  PostsOrError<UnifiedPost> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => delegate
      .getPosts(tags, page, limit: limit, options: options)
      .map(_convertResult);

  @override
  PostsOrError<UnifiedPost> getPostsFromController(
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
  PostOrError<UnifiedPost> getPost(
    PostId id, {
    PostFetchOptions? options,
  }) => delegate
      .getPost(id, options: options)
      .map((post) => post == null ? null : converter(post, origin));

  PostResult<UnifiedPost> _convertResult(PostResult<T> result) =>
      convertPostResult(
        result,
        origin: origin,
        converter: converter,
      );
}

PostResult<UnifiedPost> convertPostResult<T extends Post>(
  PostResult<T> result, {
  required PostOrigin origin,
  required PostToUnifiedConverter converter,
}) => PostResult(
  posts: result.posts
      .map((post) => converter(post, origin))
      .toList(growable: false),
  total: result.total,
  maxPage: result.maxPage,
  hasMore: result.hasMore,
);
