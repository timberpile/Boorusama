import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'following_topic_test_utils.dart';
import 'topic_test_utils.dart';

void main() {
  final older = DateTime.utc(2026);
  final newer = DateTime.utc(2026, 2);
  final members = [
    topicFixture(
      id: 'a',
      previewCount: 1,
      postCreatedAt: older,
      unreadCount: 0,
    ),
    topicFixture(
      id: 'b',
      previewCount: 1,
      postCreatedAt: newer,
      unreadCount: 0,
    ),
    topicFixture(
      id: 'c',
      previewCount: 1,
      postCreatedAt: older,
      unreadCount: 1,
    ),
    topicFixture(id: 'd', checked: false, unreadCount: 1),
  ];
  for (final c in [
    (sort: TopicFeedMemberSort.addedDate, ids: ['a', 'b', 'c', 'd']),
    (sort: TopicFeedMemberSort.newestFirst, ids: ['b', 'a', 'c', 'd']),
    (sort: TopicFeedMemberSort.oldestFirst, ids: ['a', 'c', 'b', 'd']),
  ]) {
    test(
      '${c.sort.name} uses membership order for equal and missing dates without NEW priority',
      () {
        final before = members.map((m) => m).toList();
        expect(
          sortTopicFeedMembers(members, c.sort).map((m) => m.id),
          c.ids,
        );
        expect(members.map((m) => m.id), ['a', 'b', 'c', 'd']);
        expect(members.map((m) => m).toList(), before);
        expect(
          () => sortTopicFeedMembers(members, c.sort).clear(),
          throwsUnsupportedError,
        );
      },
    );
  }
  test(
    'last refresh puts never checked first, then oldest successful checks, ignoring newer failed attempts',
    () {
      FollowingTopic source(
        String id,
        DateTime? checked, {
        DateTime? attempted,
        SearchRefreshErrorKind? error,
      }) => FollowingTopic(
        id: id,
        profileId: testProfile.id,
        query: id,
        position: 0,
        createdAt: older,
        previews: const [],
        recentPostIdentities: const [],
        unreadCount: 0,
        lastSuccessfulCheckAt: checked,
        lastAttemptAt: attempted,
        lastErrorKind: error,
      );
      final sources = [
        source('newest', newer),
        source(
          'old-failed',
          older,
          attempted: newer,
          error: SearchRefreshErrorKind.network,
        ),
        source(
          'never-failed',
          null,
          attempted: newer,
          error: SearchRefreshErrorKind.network,
        ),
        source('old-equal', older),
        source('never', null),
      ];
      final before = List<FollowingTopic>.of(sources);
      expect(
        sortTopicFeedMembers(
          sources,
          TopicFeedMemberSort.lastRefresh,
        ).map((s) => s.id),
        ['never-failed', 'never', 'old-failed', 'old-equal', 'newest'],
      );
      expect(sources, before);
    },
  );

  test(
    'addition order is each feed membership sequence, including shared sources and remove readd',
    () async {
      final repository = memorySubscriptionRepository();
      final olderFeed = await repository.saveFeed(
        profileId: testProfile.id,
        name: 'Older',
        queries: ['b'],
      );
      final feed = await repository.saveFeed(
        profileId: testProfile.id,
        name: 'Main',
        queries: ['a', 'b', 'c'],
      );
      final byId = {for (final s in await repository.getAll()) s.id: s};
      expect(feed.sourceIds[1], olderFeed.sourceIds.single);
      expect(
        sortTopicFeedMembers([
          for (final id in feed.sourceIds) byId[id]!,
        ], TopicFeedMemberSort.addedDate).map((s) => s.query),
        ['a', 'b', 'c'],
      );
      final reduced = await repository.saveFeed(
        profileId: testProfile.id,
        name: feed.name,
        queries: ['a', 'c'],
        id: feed.id,
      );
      final readded = await repository.saveFeed(
        profileId: testProfile.id,
        name: feed.name,
        queries: ['a', 'c', 'b'],
        id: feed.id,
      );
      expect(readded.sourceIds.take(2), reduced.sourceIds);
      expect(readded.sourceIds.last, olderFeed.sourceIds.single);
    },
  );
}
