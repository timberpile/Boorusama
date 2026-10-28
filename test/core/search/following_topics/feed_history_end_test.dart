import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/src/services/feed_history_end_policy.dart';
import 'package:boorusama/core/search/following_topics/src/services/feed_history_session.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'topic_test_utils.dart';

const _profile = '00000000-0000-4000-8000-000000000001';
final _date = DateTime.utc(2026, 10, 25);

Post _post(int id) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.danbooru,
    booruId: 20,
    source: 'https://safebooru.donmai.us',
  ),
  core: PostCoreData.fromPost(
    testSearchPost(id, _date.add(Duration(seconds: id))),
  ),
  booruData: const LegacyPostData(typeKey: 'test', custom: {}),
);

Future<FollowingTopic> _source(
  FollowingTopicRepository repository, [
  String query = 'a',
]) => repository.create(
  profileId: _profile,
  query: query,
  name: null,
  createdAt: _date,
);

void main() {
  test(
    'repeated pages and explicit depth limits stop without permanent ends',
    () async {
      for (final limited in [false, true]) {
        final repository = memorySubscriptionRepository();
        final source = await _source(repository);
        final pages = <int>[];
        var writes = 0;
        final session = FeedHistorySession(
          sources: [source],
          recent: [_post(10)],
          fetchPage: (_, page) async {
            pages.add(page);
            return PostResult(
              posts: [_post(10), _post(9)],
              total: null,
              hasMore: true,
              maxPage: limited ? 1 : null,
            );
          },
          confirmExhaustion: (_, _, _) => false,
          onExhausted: (_, _) async {
            writes++;
          },
        );
        expect((await session.load(2)).posts.map((p) => p.id), [9]);
        expect(pages, limited ? [1] : [1, 2]);
        expect(writes, 0);
        expect(session.exhausted, isFalse);
        expect(session.coverageIncomplete, isTrue);
      }
    },
  );

  test(
    'undated filtered pages and failed persistence do not declare completion',
    () async {
      final repository = memorySubscriptionRepository();
      final source = await _source(repository);
      for (final undated in [true, false]) {
        var writes = 0;
        final session = FeedHistorySession(
          sources: [source],
          recent: [_post(10)],
          fetchPage: (_, _) async => PostResult(
            posts: [undated ? testSearchPost(8, null) : _post(8)],
            total: 1,
            hasMore: false,
          ),
          confirmExhaustion: (_, _, _) => true,
          onExhausted: (_, _) async {
            writes++;
            throw StateError('Storage unavailable');
          },
        );
        final result = await session.load(2);
        expect(result.posts.map((p) => p.id), undated ? isEmpty : [8]);
        expect(writes, undated ? 0 : 1);
        expect(session.exhausted, isFalse);
        expect(session.coverageIncomplete, isTrue);
        expect((await repository.getById(source.id))!.historyEnd, isNull);
      }
    },
  );

  test('forward refresh invalidates only an empty-source shortcut', () async {
    final repository = memorySubscriptionRepository();
    final source = await _source(repository);
    await repository.recordHistoryEnd(
      source,
      const FeedHistoryEnd(oldestPostIdentity: null),
    );
    final updated = await repository.commitRefresh(
      SearchRefreshCommit(
        topicId: source.id,
        expectedCreatedAt: source.createdAt,
        expectedCheckpoint: null,
        startedAt: _date.add(const Duration(minutes: 1)),
        identityRetentionBoundary: _date,
        baseline: true,
        discoveredPosts: [
          SearchPostPreview(
            postId: 10,
            postCreatedAt: _date.add(const Duration(seconds: 10)),
            thumbnailUrl: 'https://example.test/10.jpg',
            sampleUrl: null,
            discoveredAt: _date.add(const Duration(minutes: 1)),
          ),
        ],
      ),
    );
    expect(updated!.historyEnd, isNull);
    const end = FeedHistoryEnd(oldestPostIdentity: '20:safebooru.donmai.us:8');
    await repository.recordHistoryEnd(updated, end);
    await repository.markRead(source.id);
    expect((await repository.getById(source.id))!.historyEnd, end);
    expect((await repository.getById(source.id))!.unreadCount, 0);
  });

  test(
    'reopen retains uncached older posts and skips the proven empty tail',
    () async {
      final repository = memorySubscriptionRepository();
      final source = await _source(repository);
      final requests = <int>[];
      Future<PostResult<Post>> fetch(FollowingTopic _, int page) async {
        requests.add(page);
        return PostResult(
          posts: page == 1 ? [_post(10), _post(9), _post(8)] : [],
          total: null,
          hasMore: page == 1,
        );
      }

      FeedHistorySession open(FollowingTopic source, List<Post> recent) =>
          FeedHistorySession(
            sources: [source],
            recent: recent,
            fetchPage: fetch,
            confirmExhaustion: (_, _, result) => result.posts.isEmpty,
            onExhausted: (source, end) async {
              await repository.recordHistoryEnd(source, end);
            },
          );
      final first = open(source, [_post(10)]);
      await first.load(1);
      expect((await first.load(2)).posts.map((p) => p.id), [9, 8]);
      expect(requests, [1, 2]);
      expect(first.exhausted, isTrue);
      first.dispose();
      final saved = (await repository.getById(source.id))!;
      expect(saved.historyEnd?.oldestPostIdentity, '20:safebooru.donmai.us:8');
      requests.clear();
      final reopened = open(saved, [_post(10)]);
      await reopened.load(1);
      final older = await reopened.load(2);
      expect(older.posts.map((p) => p.id), [9, 8]);
      expect(older.hasMore, isFalse);
      expect(requests, [1]);
      expect(reopened.exhaustedSourceIds, {source.id});
      reopened.dispose();
      requests.clear();
      final covered = open(saved, [_post(10), _post(9), _post(8)]);
      expect((await covered.load(1)).hasMore, isFalse);
      expect(requests, isEmpty);
      expect(covered.exhausted, isTrue);
    },
  );

  test(
    'sources finish independently while errors remain recoverable',
    () async {
      final repository = memorySubscriptionRepository();
      final a = await _source(repository, 'a');
      final b = await _source(repository, 'b');
      await repository.recordHistoryEnd(
        a,
        const FeedHistoryEnd(oldestPostIdentity: '20:safebooru.donmai.us:10'),
      );
      var recover = false;
      final requested = <String>[];
      final session = FeedHistorySession(
        sources: [(await repository.getById(a.id))!, b],
        recent: [_post(10)],
        fetchPage: (source, page) async {
          requested.add(source.id);
          expect(source.id, b.id);
          expect(page, 1);
          if (!recover) throw StateError('Temporary restriction');
          return PostResult(posts: [_post(8)], total: 1, hasMore: false);
        },
        confirmExhaustion: (_, _, result) => result.hasMore == false,
        onExhausted: (source, end) async {
          await repository.recordHistoryEnd(source, end);
        },
      );
      expect((await session.load(1)).hasMore, isTrue);
      await session.load(2);
      expect(session.exhaustedSourceIds, {a.id});
      expect(session.coverageIncomplete, isTrue);
      expect(session.exhausted, isFalse);
      expect((await repository.getById(b.id))!.historyEnd, isNull);
      recover = true;
      session.allowRecovery();
      expect((await session.load(2)).posts.map((p) => p.id), [8]);
      expect(session.exhausted, isTrue);
      expect(session.coverageIncomplete, isFalse);
      expect(requested, [b.id, b.id]);
    },
  );

  test(
    'unconfirmed empty/limited responses never persist and retry the same page',
    () async {
      for (final hasMore in [null, false, true]) {
        final repository = memorySubscriptionRepository();
        final source = await _source(repository);
        var confirmed = false;
        var records = 0;
        final pages = <int>[];
        final session = FeedHistorySession(
          sources: [source],
          recent: [_post(10)],
          fetchPage: (_, page) async {
            pages.add(page);
            return PostResult(posts: const [], total: null, hasMore: hasMore);
          },
          confirmExhaustion: (_, _, _) => confirmed,
          onExhausted: (source, end) async {
            records++;
            await repository.recordHistoryEnd(source, end);
          },
        );
        await session.load(2);
        expect(session.coverageIncomplete, isTrue);
        expect(session.exhaustedSourceIds, isEmpty);
        expect(records, 0);
        confirmed = true;
        session.allowRecovery();
        await session.load(2);
        expect(pages, [1, 1]);
        expect(records, 1);
        expect(session.exhausted, isTrue);
      }
    },
  );

  test(
    'semantic edits and profile invalidation reject stale end writes',
    () async {
      final repository = memorySubscriptionRepository();
      final source = await _source(repository);
      const end = FeedHistoryEnd(
        oldestPostIdentity: '20:safebooru.donmai.us:8',
      );
      await repository.recordHistoryEnd(source, end);
      await repository.rename(source.id, 'Only a display name');
      expect((await repository.getById(source.id))!.historyEnd, end);
      final edited = await repository.edit(
        source.id,
        profileId: _profile,
        query: 'b',
        name: null,
      );
      expect(edited.historyEnd, isNull);
      expect(await repository.recordHistoryEnd(source, end), isNull);
      await repository.recordHistoryEnd(edited, end);
      await repository.invalidateRuntimeForProfile(_profile);
      expect((await repository.getById(source.id))!.historyEnd, isNull);
      expect(await repository.recordHistoryEnd(edited, end), isNull);
      final changedProfile = await repository.edit(
        source.id,
        profileId: '00000000-0000-4000-8000-000000000002',
        query: 'b',
        name: null,
      );
      expect(changedProfile.historyEnd, isNull);
    },
  );

  test(
    'restore clears runtime markers without changing topic definitions',
    () async {
      final repository = memorySubscriptionRepository();
      final source = await _source(repository);
      await repository.recordHistoryEnd(
        source,
        const FeedHistoryEnd(oldestPostIdentity: null),
      );
      final saved = (await repository.getById(source.id))!;
      await repository.restoreForProfile(_profile, [saved]);
      final restored = (await repository.getById(source.id))!;
      expect(restored.query, source.query);
      expect(restored.historyEnd, isNull);
    },
  );

  test('closing during fetch never records an obsolete end', () async {
    final repository = memorySubscriptionRepository();
    final source = await _source(repository);
    final started = Completer<void>();
    final response = Completer<PostResult<Post>>();
    var writes = 0;
    final session = FeedHistorySession(
      sources: [source],
      recent: [_post(10)],
      fetchPage: (_, _) {
        started.complete();
        return response.future;
      },
      confirmExhaustion: (_, _, _) => true,
      onExhausted: (_, _) async {
        writes++;
      },
    );
    final pending = session.load(2);
    await started.future;
    session.dispose();
    response.complete(const PostResult(posts: [], total: 0));
    await expectLater(pending, throwsStateError);
    expect(writes, 0);
  });

  test('only verified raw endpoint evidence confirms exhaustion', () {
    bool confirmed(
      PostResult<Post> result, {
      int page = 1,
      BooruType type = BooruType.danbooru,
      String site = 'https://safebooru.donmai.us',
    }) => confirmsFeedHistoryEnd(
      result,
      booruType: type,
      siteUrl: site,
      page: page,
      limit: 20,
    );
    const empty = PostResult<Post>(posts: [], total: null);
    expect(confirmed(empty), isTrue);
    expect(confirmed(empty, page: 1000), isFalse);
    expect(confirmed(empty, site: 'https://unverified.example'), isFalse);
    expect(confirmed(empty.copyWith(hasMore: () => true)), isFalse);
    expect(confirmed(empty.copyWith(maxPage: () => 1)), isFalse);
    expect(
      confirmed(
        empty.copyWith(total: () => 0),
        type: BooruType.gelbooruV2,
        site: 'https://realbooru.com',
      ),
      isFalse,
    );
    expect(
      confirmed(
        PostResult(posts: [_post(1)], total: 1),
        type: BooruType.philomena,
      ),
      isTrue,
    );
    expect(
      confirmed(
        empty.copyWith(total: () => 30),
        page: 2,
        type: BooruType.gelbooru,
      ),
      isFalse,
    );
    expect(
      confirmed(
        empty.copyWith(total: () => 20),
        page: 2,
        type: BooruType.gelbooru,
      ),
      isTrue,
    );
  });
}
