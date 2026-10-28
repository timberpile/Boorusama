import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/data.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/src/data/pixiv_lookup_capabilities.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/src/data/pixiv_original_hashes.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/src/data/source_post_lookup.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../core/posts/links/boorusama_post_link_test.dart' show config;
import 'providers_test.dart' show post, hash;

class _Repository extends Fake implements PostRepository<Post> {
  _Repository(this.reply);
  final PostResult<Post> Function(String, int) reply;
  final calls = <(String, int)>[];
  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => TaskEither(() async {
    calls.add((tags, page));
    expect(options?.cascadeRequest, isFalse);
    expect(limit, 100);
    return right(reply(tags, page));
  });
}

final _artwork = PixivArtworkReference.parseSharedText(
  'https://www.pixiv.net/artworks/12345',
)!;
final _targets = [
  config(
    'https://danbooru.donmai.us',
    id: '00000000-0000-4000-8000-000000000001',
  ),
  config(
    'https://gelbooru.com',
    id: '00000000-0000-4000-8000-000000000002',
    type: BooruType.gelbooru,
  ),
  config(
    'https://rule34.xxx',
    id: '00000000-0000-4000-8000-000000000003',
    type: BooruType.gelbooruV2,
  ),
  config(
    'https://safebooru.org',
    id: '00000000-0000-4000-8000-000000000004',
    type: BooruType.gelbooruV2,
  ),
];
PostResult<Post> _page(List<Post> posts, {bool more = false}) =>
    PostResult(posts: posts, total: null, hasMore: more);
SourcePostLookup _source(BooruConfig target, _Repository repository) =>
    SourcePostLookup(
      repository: repository,
      targetOrigin: postOriginFromConfig(target),
      isVisible: (_) => true,
    );
ExactPostLookup _exact(BooruConfig target, _Repository repository) =>
    ExactPostLookup(
      repository: repository,
      targetOrigin: postOriginFromConfig(target),
      apiMode: true,
      isVisible: (_) => true,
    );

void main() {
  for (final target in _targets) {
    test(
      '${target.auth.url} accepts a real digest without a synthetic Post',
      () async {
        final repo = _Repository((_, _) => _page([post(target)]));
        final result =
            await _exact(target, repo).findHash(hash) as PostLookupPage;
        expect(result.posts.single.origin, postOriginFromConfig(target));
        expect(result.matchKind, PostLookupMatchKind.exactFile);
        expect(repo.calls, [('md5:$hash', 1)]);
        expect(supportsSharedPixivLookup(target), isTrue);
      },
    );
    test(
      '${target.auth.url} rejects a digest response with missing identity',
      () async {
        final repo = _Repository((_, _) => _page([post(target, md5: '')]));
        expect(
          await _exact(target, repo).findHash(hash),
          isA<PostLookupInvalidResponse>(),
        );
      },
    );
  }

  for (final target in _targets.take(3)) {
    for (final source in [
      'https://www.pixiv.net/en/artworks/12345',
      'http://www.pixiv.net/member_illust.php?mode=medium&amp;illust_id=12345',
      'https://i.pximg.net/img-original/img/2026/01/01/00/00/00/12345_p1.png',
      'https://other.test/reference https://www.pixiv.net/artworks/12345 https://i.pximg.net/img-original/12345_p0.jpg',
    ]) {
      test(
        '${target.auth.url} independently validates source form $source',
        () async {
          final repo = _Repository(
            (_, _) => _page([
              post(target, sourceUrl: source),
              post(
                target,
                id: 43,
                sourceUrl: 'https://www.pixiv.net/artworks/123456',
              ),
            ]),
          );
          final result = await _source(target, repo).findArtwork(
            '12345',
            variant: 0,
            cancellation: PostLookupCancellation(),
          ) as PostLookupPage;
          expect(result.posts.map((p) => p.id), [42]);
          expect(result.matchKind, PostLookupMatchKind.pixivSource);
        },
      );
    }
    test(
      '${target.auth.url} missing or ambiguous source data is a failure',
      () async {
        for (final source in [
          '',
          'https://evil.test/artworks/12345',
          'https://www.pixiv.net/artworks/12345 https://www.pixiv.net/artworks/12346',
        ]) {
          final repo = _Repository(
            (_, _) => _page([post(target, sourceUrl: source)]),
          );
          expect(
            await _source(target, repo).findArtwork(
              '12345',
              variant: 0,
              cancellation: PostLookupCancellation(),
            ),
            isA<PostLookupInvalidResponse>(),
          );
        }
      },
    );
    test(
      '${target.auth.url} wrong profile origin cannot become a source match',
      () async {
        final wrong = config('https://wrong.test');
        final repo = _Repository(
          (_, _) => _page([
            post(wrong, sourceUrl: 'https://www.pixiv.net/artworks/12345'),
          ]),
        );
        expect(
          await _source(target, repo).findArtwork(
            '12345',
            variant: 0,
            cancellation: PostLookupCancellation(),
          ),
          isA<PostLookupInvalidResponse>(),
        );
      },
    );
  }

  test(
    'unknown hosts and unverified Safebooru source search stay disabled',
    () {
      expect(
        pixivSourceQueries(postOriginFromConfig(_targets.last), '12345'),
        isEmpty,
      );
      for (final type in [
        BooruType.gelbooru,
        BooruType.gelbooruV2,
        BooruType.sankaku,
      ]) {
        expect(
          supportsSharedPixivLookup(
            config('https://unverified.test', type: type),
          ),
          isFalse,
        );
      }
    },
  );

  test(
    'variant cursors keep separate pages and deduplicate source results',
    () async {
      final target = _targets[1];
      var resolutions = 0;
      final repo = _Repository((query, page) {
        if (query.contains('artworks')) {
          return _page([
            post(target, sourceUrl: _artwork.url),
          ], more: page == 1);
        }
        if (query.contains('illust_id')) {
          return _page([post(target, sourceUrl: _artwork.url)]);
        }
        return _page([post(target, id: 43, sourceUrl: _artwork.url)]);
      });
      final session = SharedPixivLookupSession(
        artwork: _artwork,
        lookup: (_) async => _source(target, repo),
        resolveHashes: () async {
          resolutions++;
          return const PixivOriginalHashes([]);
        },
      );
      final results = <PostLookupPage>[];
      for (var page = 1; page <= 4; page++) {
        results.add(
          await session.find(
            target,
            page: page,
            cancellation: PostLookupCancellation(),
          ) as PostLookupPage,
        );
      }
      expect(results.map((r) => r.posts.map((p) => p.id).toList()), [
        [42],
        [],
        [],
        [43],
      ]);
      expect(repo.calls.map((r) => r.$2), [1, 2, 1, 1]);
      expect(results.last.hasMore, isFalse);
      expect(resolutions, 0);
    },
  );

  test(
    'one original resolution serves every target and keeps file provenance',
    () async {
      var resolutions = 0;
      final session = SharedPixivLookupSession(
        artwork: _artwork,
        lookup: (target) async =>
            _source(target, _Repository((_, _) => _page([]))),
        exactLookup: (target) async =>
            _exact(target, _Repository((_, _) => _page([post(target)]))),
        resolveHashes: () async {
          resolutions++;
          return const PixivOriginalHashes([hash]);
        },
      );
      final results = await Future.wait(
        _targets.map(
          (target) =>
              session.find(target, cancellation: PostLookupCancellation()),
        ),
      );
      expect(resolutions, 1);
      expect(
        results.every(
          (r) =>
              r is PostLookupPage &&
              r.matchKind == PostLookupMatchKind.exactFile,
        ),
        isTrue,
      );
    },
  );

  test(
    'multi-page original digests retain independent remote pagination',
    () async {
      final target = _targets.last;
      const otherHash = 'fedcba9876543210fedcba9876543210';
      final repo = _Repository(
        (query, page) => query == 'md5:$hash'
            ? _page([post(target)], more: page == 1)
            : _page([post(target, id: 43, md5: otherHash)]),
      );
      final session = SharedPixivLookupSession(
        artwork: _artwork,
        lookup: (_) =>
            throw StateError('Safebooru source queries must not run'),
        exactLookup: (_) async => _exact(target, repo),
        resolveHashes: () async => const PixivOriginalHashes([hash, otherHash]),
      );
      final pages = <PostLookupPage>[];
      for (var page = 1; page <= 3; page++) {
        pages.add(
          await session.find(
            target,
            page: page,
            cancellation: PostLookupCancellation(),
          ) as PostLookupPage,
        );
      }
      expect(repo.calls, [
        ('md5:$hash', 1),
        ('md5:$hash', 2),
        ('md5:$otherHash', 1),
      ]);
      expect(pages.map((p) => p.posts.map((p) => p.id).toList()), [
        [42],
        [],
        [43],
      ]);
      expect(pages.last.hasMore, isFalse);
    },
  );

  test(
    'source failures do not silently advance to downloading originals',
    () async {
      final target = _targets[2];
      var resolutions = 0;
      final session = SharedPixivLookupSession(
        artwork: _artwork,
        lookup: (_) async => _source(
          target,
          _Repository((_, _) => throw StateError('server failed')),
        ),
        resolveHashes: () async {
          resolutions++;
          return const PixivOriginalHashes([hash]);
        },
      );
      expect(
        await session.find(target, cancellation: PostLookupCancellation()),
        isA<PostLookupFailed>(),
      );
      expect(resolutions, 0);
    },
  );

  test(
    'cancellation while original hashes resolve prevents any target request',
    () async {
      final gate = Completer<PixivOriginalHashes>();
      final cancellation = PostLookupCancellation();
      var requests = 0;
      final session = SharedPixivLookupSession(
        artwork: _artwork,
        lookup: (_) => throw StateError('No source method'),
        exactLookup: (_) {
          requests++;
          throw StateError('Must not request');
        },
        resolveHashes: () => gate.future,
      );
      final pending = session.find(_targets.last, cancellation: cancellation);
      await Future<void>.value();
      cancellation.cancel();
      gate.complete(const PixivOriginalHashes([hash]));
      expect(await pending, isA<PostLookupCancelled>());
      expect(requests, 0);
    },
  );

  test(
    'partial original coverage never becomes a definite completed no-match',
    () async {
      final target = _targets.last;
      final session = SharedPixivLookupSession(
        artwork: _artwork,
        lookup: (_) => throw StateError('No source method'),
        exactLookup: (_) async =>
            _exact(target, _Repository((_, _) => _page([]))),
        resolveHashes: () async => const PixivOriginalHashes([
          hash,
        ], issue: PixivLookupCoverageIssue.originalsUnavailable),
      );
      final result = await session.find(
        target,
        cancellation: PostLookupCancellation(),
      ) as PostLookupPage;
      expect(result.posts, isEmpty);
      expect(result.hasMore, isFalse);
      expect(
        result.coverageIssue,
        PixivLookupCoverageIssue.originalsUnavailable,
      );
    },
  );
}
