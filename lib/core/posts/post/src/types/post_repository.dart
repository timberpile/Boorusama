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
  });

  final bool cascadeRequest;

  static const defaults = PostFetchOptions();
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
    this.hasMore,
  });

  PostResult.empty() : posts = <T>[], total = 0, maxPage = null, hasMore = null;

  PostResult<T> copyWith({
    List<T>? posts,
    int? Function()? total,
    int? Function()? maxPage,
    bool? Function()? hasMore,
  }) => PostResult(
    posts: posts ?? this.posts,
    total: total != null ? total() : this.total,
    maxPage: maxPage != null ? maxPage() : this.maxPage,
    hasMore: hasMore != null ? hasMore() : this.hasMore,
  );

  final List<T> posts;
  final int? total;
  final int? maxPage;
  final bool? hasMore;

  @override
  List<Object?> get props => [posts, total, maxPage, hasMore];
}

extension PostResultX<T extends Post> on List<T> {
  PostResult<T> toResult({
    int? total,
    int? maxPage,
    bool? hasMore,
  }) => PostResult(
    posts: this,
    total: total,
    maxPage: maxPage,
    hasMore: hasMore,
  );
}

typedef PostFutureFetcher<T extends Post> =
    Future<PostResult<T>> Function(
      List<String> tags,
      int page, {
      int? limit,
      PostFetchOptions? options,
    });

typedef PostSingleFutureFetcher<T extends Post> =
    Future<T?> Function(
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
