// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/search/queries/types.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';

void main() {
  final origin = PostOrigin.fromSource(
    booruType: BooruType.gelbooru,
    booruId: BooruType.gelbooru.id,
    source: 'https://gelbooru.example',
    profileIdHint: 42,
  );
  final first = _Post(2);
  final second = _Post(1);
  final delegate = _Repository(
    result: PostResult(
      posts: [first, second],
      total: 99,
      maxPage: 7,
      hasMore: true,
    ),
  );
  final repository = UnifiedPostRepository(
    delegate: delegate,
    origin: origin,
    converter: _convert,
  );

  test('preserves post order and pagination metadata', () async {
    final result = await repository.getPosts('tag', 3, limit: 12).run();
    final value = result.getOrElse((_) => throw StateError('unexpected error'));

    expect(value.posts.map((post) => post.id), [2, 1]);
    expect(value.posts.every((post) => post.origin == origin), isTrue);
    expect(value.total, 99);
    expect(value.maxPage, 7);
    expect(value.hasMore, isTrue);
    expect(delegate.lastTags, 'tag');
    expect(delegate.lastPage, 3);
    expect(delegate.lastLimit, 12);
  });

  test(
    'converts controller and single-post results with the same origin',
    () async {
    const options = PostFetchOptions.raw;
      final controllerResult = await repository
          .getPostsFromController(
            SearchTagSet.fromList(const ['one', 'two']),
            4,
            options: options,
          )
          .run();
      final singleResult = await repository
          .getPost(const NumericPostId(2), options: options)
          .run();

      expect(
        controllerResult
            .getOrElse((_) => throw StateError('unexpected error'))
            .posts
            .map((post) => post.id),
        [2, 1],
      );
      expect(
        singleResult.getOrElse((_) => null)?.origin,
        origin,
      );
      expect(delegate.lastPage, 4);
      expect(delegate.lastOptions, same(options));
      expect(repository.tagComposer, same(delegate.tagComposer));
    },
  );

  test('returns the original repository error without conversion', () async {
    final error = AppError(
      type: AppErrorType.loadDataFromServerFailed,
      message: 'failed',
    );
    final repository = UnifiedPostRepository(
      delegate: _Repository(error: error),
      origin: origin,
      converter: _convert,
    );

    final result = await repository.getPosts('', 1).run();

    expect(result.fold((value) => value, (_) => null), same(error));
  });
}

UnifiedPost _convert(Post post, PostOrigin origin) => UnifiedPost(
  origin: origin,
  core: PostCoreData.fromPost(post),
  booruData: const EmptyPostData(typeKey: 'gelbooru'),
);

final class _Repository implements PostRepository<_Post> {
  _Repository({
    this.result,
    this.error,
  });

  final PostResult<_Post>? result;
  final BooruError? error;

  String? lastTags;
  int? lastPage;
  int? lastLimit;
  PostFetchOptions? lastOptions;

  @override
  final TagQueryComposer tagComposer = EmptyTagQueryComposer();

  @override
  PostsOrError<_Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) {
    lastTags = tags;
    lastPage = page;
    lastLimit = limit;
    lastOptions = options;
    return _result();
  }

  @override
  PostsOrError<_Post> getPostsFromController(
    SearchTagSet controller,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) {
    lastPage = page;
    lastLimit = limit;
    lastOptions = options;
    return _result();
  }

  @override
  PostOrError<_Post> getPost(
    PostId id, {
    PostFetchOptions? options,
  }) {
    lastOptions = options;
    final numericId = switch (id) {
      NumericPostId(:final value) => value,
      StringPostId() => null,
    };
    return switch ((
      error,
      result?.posts.where((post) => post.id == numericId),
    )) {
      (final error?, _) => TaskEither.left(error),
      (_, final posts?) => TaskEither.right(posts.firstOrNull),
      _ => TaskEither.right(null),
    };
  }

  PostsOrError<_Post> _result() => switch ((error, result)) {
    (final error?, _) => TaskEither.left(error),
    (_, final result?) => TaskEither.right(result),
    _ => TaskEither.right(PostResult.empty()),
  };
}

final class _Post extends SimplePost {
  _Post(int id)
    : super(
        id: id,
        thumbnailImageUrl: 'thumb/$id',
        sampleImageUrl: 'sample/$id',
        originalImageUrl: 'original/$id',
        tags: const {},
        rating: Rating.general,
        hasComment: false,
        isTranslated: false,
        hasParentOrChildren: false,
        source: PostSource.none(),
        score: 0,
        duration: 0,
        fileSize: 0,
        format: 'jpg',
        hasSound: null,
        height: 1,
        md5: '',
        videoThumbnailUrl: '',
        videoUrl: '',
        width: 1,
        uploaderId: null,
        metadata: null,
      );
}
