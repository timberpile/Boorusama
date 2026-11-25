// Package imports:
import 'package:equatable/equatable.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import '../../../../errors/types.dart';
import '../../../../search/queries/types.dart';
import '../../../../search/selected_tags/types.dart';
import 'post.dart';

class PostFetchOptions {
  const PostFetchOptions({
    this.cascadeRequest = true,
    this.prepareGroupRows = false,
    this.useCursor = false,
    this.cursor,
  });

  final bool cascadeRequest;
  final bool prepareGroupRows;
  final bool useCursor;
  final int? cursor;

  static const defaults = PostFetchOptions();
  static const groupRows = PostFetchOptions(
    cascadeRequest: false,
    prepareGroupRows: true,
  );

  static const raw = PostFetchOptions(
    cascadeRequest: false,
  );
}

abstract class PostRepository<T extends Post> {
  PostsOrError<T> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  });

  PostsOrError<T> getPostsFromController(
    SearchTagSet controller,
    int page, {
    int? limit,
    PostFetchOptions? options,
  });

  PostOrError<T> getPost(
    PostId id, {
    PostFetchOptions? options,
  });

  TagQueryComposer get tagComposer;
}

class PostResult<T extends Post> extends Equatable {
  const PostResult({
    required this.posts,
    required this.total,
    this.maxPage,
    this.nextCursor,
    this.hasMore,
    this.rawPostCount,
    this.rawUniquePostCount,
  });

  PostResult.empty()
    : posts = <T>[],
      total = 0,
      maxPage = null,
      nextCursor = null,
      hasMore = null,
      rawPostCount = null,
      rawUniquePostCount = null;

  PostResult<T> copyWith({
    List<T>? posts,
    int? Function()? total,
    int? Function()? maxPage,
    int? Function()? nextCursor,
    bool? Function()? hasMore,
    int? Function()? rawPostCount,
    int? Function()? rawUniquePostCount,
  }) => PostResult(
    posts: posts ?? this.posts,
    total: total != null ? total() : this.total,
    maxPage: maxPage != null ? maxPage() : this.maxPage,
    nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
    hasMore: hasMore != null ? hasMore() : this.hasMore,
    rawPostCount: rawPostCount != null ? rawPostCount() : this.rawPostCount,
    rawUniquePostCount: rawUniquePostCount != null
        ? rawUniquePostCount()
        : this.rawUniquePostCount,
  );

  final List<T> posts;
  final int? total;
  final int? maxPage;
  final int? nextCursor;
  final bool? hasMore;

  /// Number returned by the source before repository visibility transforms.
  /// Consumers needing raw page progress must not infer it from filtered Posts.
  final int? rawPostCount;
  final int? rawUniquePostCount;

  @override
  List<Object?> get props => [
    posts,
    total,
    maxPage,
    nextCursor,
    hasMore,
    rawPostCount,
    rawUniquePostCount,
  ];
}

extension PostResultX<T extends Post> on List<T> {
  PostResult<T> toResult({
    int? total,
    int? maxPage,
    int? nextCursor,
    bool? hasMore,
    int? rawPostCount,
    int? rawUniquePostCount,
  }) => PostResult(
    posts: this,
    total: total,
    maxPage: maxPage,
    nextCursor: nextCursor,
    hasMore: hasMore,
    rawPostCount: rawPostCount,
    rawUniquePostCount: rawUniquePostCount,
  );
}

typedef PostFutureFetcher<T extends Post> = Future<PostResult<T>> Function(
  List<String> tags,
  int page, {
  int? limit,
  PostFetchOptions? options,
});

typedef PostSingleFutureFetcher<T extends Post> = Future<T?> Function(
  PostId id, {
  PostFetchOptions? options,
});

typedef PostFutureControllerFetcher<T extends Post> =
    Future<PostResult<T>> Function(
      SearchTagSet controller,
      int page, {
      int? limit,
      PostFetchOptions? options,
    });

typedef PostsOrErrorCore<T extends Post> =
    TaskEither<BooruError, PostResult<T>>;

typedef PostsOrError<T extends Post> = PostsOrErrorCore<T>;

typedef PostOrErrorCore<T extends Post> = TaskEither<BooruError, T?>;

typedef PostOrError<T extends Post> = PostOrErrorCore<T>;

/// Existing engine ancillary work, invoked only by a selected gallery consuming
/// prepared rows. Test/custom repositories need not advertise these effects.
abstract interface class ForegroundPostConsumer<T extends Post> {
  Future<void> consumePreparedPosts(List<T> posts);
}
