import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/pools/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  test('pool continuation uses ID slices, not returned post count', () async {
    final repo = _Repository(
      (query) async => query == 'id:1,2'
          ? const PostResult<Post>(posts: [], total: null)
          : PostResult<Post>(posts: [TestPost(id: 3)], total: null),
    );
    final first = await repo.fetchPostIds(
      ids: [1, 2, 3],
      page: 1,
      perPage: 2,
      order: PoolDetailsOrder.order,
    );
    expect(first.posts, isEmpty);
    expect(first.hasMore, isTrue);
    expect(first.maxPage, 2);
    final last = await repo.fetchPostIds(
      ids: [1, 2, 3],
      page: 2,
      perPage: 2,
      order: PoolDetailsOrder.order,
    );
    expect(last.posts.single.id, 3);
    expect(last.hasMore, isFalse);
    expect(last.total, 3);
    final pastEnd = await repo.fetchPostIds(
      ids: [1, 2, 3],
      page: 3,
      perPage: 2,
      order: PoolDetailsOrder.order,
    );
    expect(pastEnd.hasMore, isFalse);
    expect(repo.queries, ['id:1,2', 'id:3']);
  });

  test('pool failure is not converted into successful exhaustion', () async {
    final repo = _Repository((_) async => throw StateError('offline'));
    await expectLater(
      repo.fetchPostIds(
        ids: [1],
        page: 1,
        perPage: 2,
        order: PoolDetailsOrder.order,
      ),
      throwsA(isA<BooruError>()),
    );
  });

  test('complete pool preserves its order and stops immediately', () async {
    final repo = _Repository(
      (_) async => PostResult<Post>(
        posts: [TestPost(id: 1), TestPost(id: 3)],
        total: null,
      ),
    );
    final result = await repo.fetchPostIds(
      ids: [3, 2, 1],
      page: 1,
      perPage: 3,
      order: PoolDetailsOrder.order,
    );
    expect(result.posts.map((post) => post.id), [3, 1]);
    expect(result.hasMore, isFalse);
  });
}

class _Repository implements PostRepository<Post> {
  _Repository(this.fetch);
  final Future<PostResult<Post>> Function(String) fetch;
  final queries = <String>[];

  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => TaskEither.tryCatch(() {
    queries.add(tags);
    return fetch(tags);
  }, (error, _) => UnknownError(error: error, message: error.toString()));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
