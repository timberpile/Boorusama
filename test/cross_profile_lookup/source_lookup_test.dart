import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/data.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/src/data/source_post_lookup.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../core/posts/links/boorusama_post_link_test.dart' show config;
import 'providers_test.dart' show post, targetProfile, sourceProfile, hash;

const artwork = 'https://www.pixiv.net/en/artworks/12345';

class QueryRepository extends Fake implements PostRepository<Post> {
  QueryRepository(this.respond);
  final PostResult<Post> Function(String, int) respond;
  final queries = <String>[];
  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) {
    queries.add(tags);
    expect(options?.cascadeRequest, isFalse);
    return TaskEither(() async => right(respond(tags, page)));
  }
}

void main() {
  for (final md5 in [hash, '']) {
    test('ordered source fallback with hash "$md5"', () async {
      final repo = QueryRepository(
        (query, _) => PostResult(
          total: null,
          hasMore: false,
          posts: query.startsWith('source:')
              ? [post(targetProfile, sourceUrl: artwork)]
              : [],
        ),
      );
      final session = CrossProfileLookupSession(
        source: post(sourceProfile, md5: md5, sourceUrl: artwork),
        refreshSource: () async => null,
        lookup: (_) async => ExactPostLookup(
          repository: repo,
          targetOrigin: postOriginFromConfig(targetProfile),
          apiMode: true,
          isVisible: (_) => true,
        ),
        sourceLookup: (_) async => SourcePostLookup(
          repository: repo,
          targetOrigin: postOriginFromConfig(targetProfile),
          isVisible: (_) => true,
        ),
      );
      final result = await session.find(
        targetProfile,
        cancellation: PostLookupCancellation(),
      ) as PostLookupPage;
      expect(repo.queries, [
        if (md5.isNotEmpty) 'md5:$hash',
        'pixiv_id:12345',
        'source:$artwork',
      ]);
      expect(result.matchKind, PostLookupMatchKind.sourceUrl);
      expect(result.posts, hasLength(1));
    });
  }

  test('Pixiv matching accepts image URL variants but rejects other artworks and accounts', () async {
    final repo = QueryRepository(
      (_, _) => PostResult(
        total: null,
        hasMore: false,
        posts: [
          post(
            targetProfile,
            sourceUrl: 'https://i.pximg.net/img-original/img/12345_p2.jpg',
          ),
          post(
            targetProfile,
            id: 43,
            sourceUrl: 'https://www.pixiv.net/artworks/123456',
          ),
        ],
      ),
    );
    final service = SourcePostLookup(
      repository: repo,
      targetOrigin: postOriginFromConfig(targetProfile),
      isVisible: (_) => true,
    );
    final result = await service.find(
      post(sourceProfile, sourceUrl: artwork),
      kind: PostLookupMatchKind.pixivSource,
      cancellation: PostLookupCancellation(),
    ) as PostLookupPage;
    expect(result.posts.map((p) => p.id), [42]);
    expect(result.matchKind, PostLookupMatchKind.pixivSource);

    final wrong = SourcePostLookup(
      repository: repo,
      targetOrigin: postOriginFromConfig(sourceProfile),
      isVisible: (_) => true,
    );
    expect(
      await wrong.find(
        post(sourceProfile, sourceUrl: artwork),
        kind: PostLookupMatchKind.pixivSource,
        cancellation: PostLookupCancellation(),
      ),
      isA<PostLookupInvalidResponse>(),
    );
  });

  test('URL match excludes prefix matches, blacklisted posts and duplicates; pagination uses raw metadata', () async {
    final repo = QueryRepository(
      (_, _) => PostResult(
        total: null,
        hasMore: true,
        posts: [
          post(targetProfile, sourceUrl: artwork),
          post(targetProfile, sourceUrl: artwork),
          post(targetProfile, id: 43, sourceUrl: artwork, tags: {'blocked'}),
          post(targetProfile, id: 44, sourceUrl: '${artwork}9'),
        ],
      ),
    );
    final result =
        await SourcePostLookup(
              repository: repo,
              targetOrigin: postOriginFromConfig(targetProfile),
              isVisible: (p) => !p.tags.contains('blocked'),
            ).find(
              post(sourceProfile, sourceUrl: artwork),
              kind: PostLookupMatchKind.sourceUrl,
              cancellation: PostLookupCancellation(),
            )
            as PostLookupPage;
    expect(result.posts.map((p) => p.id), [42]);
    expect(result.hasMore, isTrue);
    expect(result.hasFilteredMatches, isTrue);
  });

  test('errors and incomplete MD5 pages never silently fall back', () async {
    for (final fail in [true, false]) {
      final repo = QueryRepository((_, _) {
        if (fail) throw StateError('transport failed');
        return const PostResult(total: null, posts: [], hasMore: true);
      });
      final session = CrossProfileLookupSession(
        source: post(sourceProfile, sourceUrl: artwork),
        refreshSource: () async => null,
        lookup: (_) async => ExactPostLookup(
          repository: repo,
          targetOrigin: postOriginFromConfig(targetProfile),
          apiMode: true,
          isVisible: (_) => true,
        ),
        sourceLookup: (_) => throw StateError('Must not fall back'),
      );
      final result = await session.find(
        targetProfile,
        cancellation: PostLookupCancellation(),
      );
      expect(result, fail ? isA<PostLookupFailed>() : isA<PostLookupPage>());
      expect(repo.queries, ['md5:$hash']);
    }
  });

  test(
    'a successful method stops fallback and retains provenance across pages',
    () async {
      for (final kind in [
        PostLookupMatchKind.exactFile,
        PostLookupMatchKind.pixivSource,
      ]) {
        final queryPrefix = kind == PostLookupMatchKind.exactFile
            ? 'md5:'
            : 'pixiv_id:';
        final repo = QueryRepository(
          (query, page) => PostResult(
            total: null,
            hasMore: query.startsWith(queryPrefix) && page == 1,
            posts: query.startsWith(queryPrefix) && page == 1
                ? [post(targetProfile, sourceUrl: artwork)]
                : [],
          ),
        );
        final session = CrossProfileLookupSession(
          source: post(sourceProfile, sourceUrl: artwork),
          refreshSource: () async => null,
          lookup: (_) async => ExactPostLookup(
            repository: repo,
            targetOrigin: postOriginFromConfig(targetProfile),
            apiMode: true,
            isVisible: (_) => true,
          ),
          sourceLookup: (_) async => SourcePostLookup(
            repository: repo,
            targetOrigin: postOriginFromConfig(targetProfile),
            isVisible: (_) => true,
          ),
        );
        final first = await session.find(
          targetProfile,
          cancellation: PostLookupCancellation(),
        ) as PostLookupPage;
        expect(first.matchKind, kind);
        expect(first.posts, hasLength(1));
        final second = await session.find(
          targetProfile,
          page: 2,
          cancellation: PostLookupCancellation(),
        ) as PostLookupPage;
        expect(second.matchKind, kind);
        expect(second.hasMore, isFalse);
        expect(repo.queries.where((q) => q.startsWith('source:')), isEmpty);
        expect(repo.queries.last, startsWith(queryPrefix));
      }
    },
  );

  test(
    'metadata refresh does not erase an available source reference',
    () async {
      for (final failedRefresh in [true, false]) {
        final repo = QueryRepository(
          (_, _) => PostResult(
            total: null,
            hasMore: false,
            posts: [post(targetProfile, sourceUrl: artwork)],
          ),
        );
        final session = CrossProfileLookupSession(
          source: post(sourceProfile, md5: '', sourceUrl: artwork),
          refreshSource: () async {
            if (failedRefresh) throw StateError('refresh failed');
            return post(sourceProfile, md5: '');
          },
          lookup: (_) => throw StateError('No hash available'),
          sourceLookup: (_) async => SourcePostLookup(
            repository: repo,
            targetOrigin: postOriginFromConfig(targetProfile),
            isVisible: (_) => true,
          ),
        );
        final result = await session.find(
          targetProfile,
          cancellation: PostLookupCancellation(),
        ) as PostLookupPage;
        expect(result.matchKind, PostLookupMatchKind.pixivSource);
        expect(result.posts, hasLength(1));
      }
    },
  );

  test('only Rule34 is enabled among Gelbooru V2 sites', () {
    expect(
      supportsExactPostLookup(
        config('https://rule34.xxx/', type: BooruType.gelbooruV2),
      ),
      isTrue,
    );
    expect(
      supportsExactPostLookup(
        config('https://realbooru.com/', type: BooruType.gelbooruV2),
      ),
      isFalse,
    );
    expect(supportsSourceUrlLookup(BooruType.gelbooruV2), isFalse);
  });

  test('source parsing rejects query injection and unrelated hosts', () {
    for (final url in [
      'https://x.test/a rating:e',
      'https://x.test/*',
      'https://user@x.test/a',
    ]) {
      expect(lookupSourceUrl(url), isNull);
    }
    expect(
      pixivArtworkId('https://pixiv.net.evil.test/artworks/12345'),
      isNull,
    );
    expect(
      pixivArtworkId('https://www.pixiv.net/member_illust.php?illust_id=12345'),
      '12345',
    );
  });

  test(
    'automatic fan-out is bounded and releases a slot after failure',
    () async {
      final queue = CrossProfileLookupQueue(concurrency: 2);
      final first = Completer<PostLookupResult>();
      final second = Completer<PostLookupResult>();
      final thirdStarted = Completer<void>();
      var started = 0;
      final a = queue.run(() {
        started++;
        return first.future;
      });
      final b = queue.run(() {
        started++;
        return second.future;
      });
      final c = queue.run(() async {
        started++;
        thirdStarted.complete();
        return const PostLookupCancelled();
      });
      expect(started, 2);
      first.complete(const PostLookupFailed('failed'));
      await a;
      await thirdStarted.future;
      expect(started, 3);
      second.complete(const PostLookupCancelled());
      await Future.wait([b, c]);
    },
  );
}
