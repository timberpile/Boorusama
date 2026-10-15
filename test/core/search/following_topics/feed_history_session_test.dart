import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/src/services/feed_history_session.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'topic_test_utils.dart';

void main() {
  test(
    'older browsing merges source pages in order beyond the recent cache',
    () async {
      final now = DateTime.utc(2026, 9, 20);
      final sources = [
        for (final query in ['a', 'b'])
          FollowingTopic.create(
            id: query,
            profileId: '00000000-0000-4000-8000-000000000001',
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
            _post(testSearchPost(id, now.add(Duration(seconds: id)))),
        ],
        fetchPage: (source, page) async {
          fetched.add('${source.query}:$page');
          final ids = pages[source.query]![page - 1];
          return PostResult<Post>(
            posts: [
              for (final id in ids)
                _post(testSearchPost(id, now.add(Duration(seconds: id)))),
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
      final source = FollowingTopic.create(
        id: 'artist',
        profileId: '00000000-0000-4000-8000-000000000001',
        query: 'artist',
        name: null,
        position: 0,
        createdAt: now,
      );
      var attempts = 0;
      final session = FeedHistorySession(
        sources: [source],
        recent: [_post(testSearchPost(10, now))],
        fetchPage: (_, page) async {
          attempts++;
          if (attempts == 1) throw StateError('Offline');
          expect(page, 1);
          return PostResult<Post>(
            posts: [
              _post(
                testSearchPost(
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
    final source = FollowingTopic.create(
      id: 'artist',
      profileId: '00000000-0000-4000-8000-000000000001',
      query: 'artist',
      name: null,
      position: 0,
      createdAt: now,
    );
    var pageTwoAttempts = 0;
    final session = FeedHistorySession(
      sources: [source],
      recent: [_post(testSearchPost(11, now))],
      fetchPage: (_, page) async {
        if (page == 2 && pageTwoAttempts++ == 0) {
          throw StateError('Offline');
        }
        return PostResult<Post>(
          posts: [
            for (final id in page == 1 ? [10, 9] : [8])
              _post(
                testSearchPost(
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

  test('history preserves colliding numeric IDs on different sites', () async {
    final now = DateTime.utc(2026, 9, 20);
    final sources = [
      for (final (index, host) in ['a.example', 'b.example'].indexed)
        FollowingTopic.create(
          id: host,
          profileId: index == 0
              ? '00000000-0000-4000-8000-000000000011'
              : '00000000-0000-4000-8000-000000000012',
          query: host,
          name: null,
          position: index,
          createdAt: now,
        ),
    ];
    Post fromSite(String host, int id) => Post(
      origin: PostOrigin.fromSource(
        booruType: BooruType.gelbooruV2,
        booruId: 23,
        source: 'https://$host',
      ),
      core: PostCoreData.fromPost(testSearchPost(id, now)),
      booruData: const LegacyPostData(typeKey: 'test', custom: {}),
    );
    final session = FeedHistorySession(
      sources: sources,
      recent: [fromSite('a.example', 100)],
      fetchPage: (source, page) async => PostResult<Post>(
        posts: [fromSite(source.query, 100)],
        total: null,
        hasMore: false,
      ),
    );

    final recent = await session.load(1);
    final older = await session.load(2);
    expect(recent.posts.length, 1);
    expect(older.posts.map((p) => p.origin.sourceHost), ['b.example']);
  });

  test(
    'closing history stops scheduling requests for remaining sources',
    () async {
      final now = DateTime.utc(2026, 9, 20);
      final sources = [
        for (final id in ['a', 'b', 'c', 'd'])
          FollowingTopic.create(
            id: id,
            profileId: '00000000-0000-4000-8000-000000000001',
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
        recent: [_post(testSearchPost(10, now))],
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
