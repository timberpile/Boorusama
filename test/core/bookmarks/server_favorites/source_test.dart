import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:boorusama/core/posts/post/types.dart';

import '../../search/following_topics/topic_test_utils.dart';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/bookmarks/src/server_favorites/source.dart';
import 'package:boorusama/core/bookmarks/src/server_favorites/target_settings.dart';

BooruConfigAuth _auth(
  BooruType type, {
  String? login = 'example user',
  String? apiKey = 'test-key',
}) => BooruConfigAuth(
  booruId: type.id,
  booruIdHint: type.id,
  url: 'https://example.invalid',
  login: login,
  apiKey: apiKey,
  passHash: null,
  proxySettings: null,
  networkSettings: null,
);

void main() {
  test('Danbooru uses the existing ordered-favorites query', () {
    expect(
      serverFavoriteQuery(_auth(BooruType.danbooru)),
      'ordfav:example_user',
    );
  });

  test('e621 uses the dedicated account-favorites endpoint', () {
    expect(serverFavoriteQuery(_auth(BooruType.e621)), '');
  });

  test('additional engines use their existing account queries', () {
    expect(
      serverFavoriteQuery(_auth(BooruType.moebooru)),
      'vote:3:example_user order:vote',
    );
    expect(
      serverFavoriteQuery(_auth(BooruType.gelbooru, login: '123')),
      'fav:123',
    );
    expect(serverFavoriteQuery(_auth(BooruType.szurubooru)), 'special:fav');
  });

  test('repository downloads use raw options and report search-depth caps as partial', () async {
    final repository = _RecordingRepository();
    final source = RepositoryServerFavoriteSource(repository, 'fav:fixture');
    expect((await source.fetchPage(2)).posts.length, 1);
    expect(repository.options, PostFetchOptions.raw);
    expect(repository.limit, 100);
    expect(repository.query, 'fav:fixture');
    repository.capped = true;
    await expectLater(
      source.fetchPage(3),
      throwsA(
        isA<ServerFavoriteException>().having(
          (e) => e.problem,
          'problem',
          ServerFavoriteProblem.paginationStalled,
        ),
      ),
    );
  });

  test('unverified engines are explicitly unsupported', () {
    expect(
      () => serverFavoriteQuery(_auth(BooruType.sankaku)),
      throwsA(
        isA<ServerFavoriteException>().having(
          (error) => error.problem,
          'problem',
          ServerFavoriteProblem.unsupported,
        ),
      ),
    );
  });

  test('missing credentials fail without constructing a client', () {
    for (final auth in [
      _auth(BooruType.danbooru, login: null),
      _auth(BooruType.e621, apiKey: null),
      _auth(BooruType.e621, login: ' '),
      _auth(BooruType.e621, apiKey: ' '),
    ]) {
      expect(
        () => serverFavoriteQuery(auth),
        throwsA(
          isA<ServerFavoriteException>().having(
            (error) => error.problem,
            'problem',
            ServerFavoriteProblem.signedOut,
          ),
        ),
      );
    }
  });
}

class _RecordingRepository extends PostRepository<Post> {
  PostFetchOptions? options;
  int? limit;
  String? query;
  bool capped = false;
  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) {
    this.options = options;
    this.limit = limit;
    query = tags;
    return TaskEither.right(
      PostResult(
        total: null,
        posts: capped ? [] : [testSearchPost(1, DateTime.utc(2026))],
        maxPage: 2,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
