import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/subscriptions/src/services/feed_history_session.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'subscription_test_utils.dart';

void main() {
  test(
    'older browsing merges source pages in order beyond the recent cache',
    () async {
      final now = DateTime.utc(2026, 9, 20);
      final sources = [
        for (final query in ['a', 'b'])
          SearchSubscription.create(
            id: query,
            profileId: 1,
            query: query,
            name: null,
            position: 0,
            createdAt: now,
          ),
      ];
      final fetched = <String>[];
      final pages = {
        'a': [
          [10, 8],
          [5],
        ],
        'b': [
          [9, 7],
          [6],
        ],
      };
      final session = FeedHistorySession(
        sources: sources,
        recent: [
          for (final id in [10, 9])
            _post(TestSearchPost(id, now.add(Duration(seconds: id)))),
        ],
        fetchPage: (source, page) async {
          fetched.add('${source.query}:$page');
          final ids = pages[source.query]![page - 1];
          return PostResult<Post>(
            posts: [
              for (final id in ids)
                _post(TestSearchPost(id, now.add(Duration(seconds: id)))),
            ],
            total: null,
            hasMore: page == 1,
          );
        },
      );

      expect((await session.load(1)).posts.map((post) => post.id), [10, 9]);
      expect(fetched, isEmpty);
      expect((await session.load(2)).posts.map((post) => post.id), [
        8,
        7,
        6,
        5,
      ]);
      expect((await session.load(2)).posts.map((post) => post.id), [
        8,
        7,
        6,
        5,
      ]);
      expect(fetched, containsAll(['a:1', 'a:2', 'b:1', 'b:2']));
      expect(fetched, hasLength(4));
    },
  );

  test(
    'a failed source page can be retried without losing its cursor',
    () async {
      final now = DateTime.utc(2026, 9, 20);
      final source = SearchSubscription.create(
        id: 'artist',
        profileId: 1,
        query: 'artist',
        name: null,
        position: 0,
        createdAt: now,
      );
      var attempts = 0;
      final session = FeedHistorySession(
        sources: [source],
        recent: [_post(TestSearchPost(10, now))],
        fetchPage: (_, page) async {
          attempts++;
          if (attempts == 1) throw StateError('Offline');
          expect(page, 1);
          return PostResult<Post>(
            posts: [
              _post(
                TestSearchPost(
                  9,
                  now.subtract(const Duration(seconds: 1)),
                ),
              ),
            ],
            total: null,
            hasMore: false,
          );
        },
      );

      expect((await session.load(1)).posts.map((post) => post.id), [10]);
      await expectLater(session.load(2), throwsStateError);
      expect((await session.load(2)).posts.map((post) => post.id), [9]);
      expect(attempts, 2);
    },
  );

  test('retry keeps posts gathered before a later source page fails', () async {
    final now = DateTime.utc(2026, 9, 20);
    final source = SearchSubscription.create(
      id: 'artist',
      profileId: 1,
      query: 'artist',
      name: null,
      position: 0,
      createdAt: now,
    );
    var pageTwoAttempts = 0;
    final session = FeedHistorySession(
      sources: [source],
      recent: [_post(TestSearchPost(11, now))],
      fetchPage: (_, page) async {
        if (page == 2 && pageTwoAttempts++ == 0) {
          throw StateError('Offline');
        }
        return PostResult<Post>(
          posts: [
            for (final id in page == 1 ? [10, 9] : [8])
              _post(
                TestSearchPost(
                  id,
                  now.subtract(Duration(seconds: 11 - id)),
                ),
              ),
          ],
          total: null,
          hasMore: page == 1,
        );
      },
    );

    expect((await session.load(1)).posts.map((post) => post.id), [11]);
    await expectLater(session.load(2), throwsStateError);
    expect((await session.load(2)).posts.map((post) => post.id), [10, 9, 8]);
    expect(pageTwoAttempts, 2);
  });

  test(
    'closing history stops scheduling requests for remaining sources',
    () async {
      final now = DateTime.utc(2026, 9, 20);
      final sources = [
        for (final id in ['a', 'b', 'c', 'd'])
          SearchSubscription.create(
            id: id,
            profileId: 1,
            query: id,
            name: null,
            position: 0,
            createdAt: now,
          ),
      ];
      final requests = <String>[];
      final started = Completer<void>();
      final replies = [
        for (var i = 0; i < 3; i++) Completer<PostResult<Post>>(),
      ];
      final session = FeedHistorySession(
        sources: sources,
        recent: [_post(TestSearchPost(10, now))],
        fetchPage: (source, _) {
          requests.add(source.id);
          if (requests.length == 3) started.complete();
          return replies[requests.length - 1].future;
        },
      );

      final loading = session.load(2);
      await started.future;
      session.dispose();
      for (final reply in replies) {
        reply.complete(
          const PostResult<Post>(posts: [], total: null),
        );
      }
      await expectLater(loading, throwsStateError);
      expect(requests, ['a', 'b', 'c']);
    },
  );
}

Post _post(Post post) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.unknown,
    booruId: 0,
    source: '',
  ),
  core: PostCoreData.fromPost(post),
  booruData: const LegacyPostData(typeKey: 'test', custom: {}),
);
