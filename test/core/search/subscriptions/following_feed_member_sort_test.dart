import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'pinned_search_test_utils.dart';
import 'subscription_test_utils.dart';

void main() {
  final older = DateTime.utc(2026);
  final newer = DateTime.utc(2026, 2);
  final members = [
    pinnedFixture(
      id: 'a',
      previewCount: 1,
      postCreatedAt: older,
      unreadCount: 0,
    ),
    pinnedFixture(
      id: 'b',
      previewCount: 1,
      postCreatedAt: newer,
      unreadCount: 0,
    ),
    pinnedFixture(
      id: 'c',
      previewCount: 1,
      postCreatedAt: older,
      unreadCount: 1,
    ),
    pinnedFixture(id: 'd', checked: false, unreadCount: 1),
  ];
  for (final c in [
    (sort: FollowingFeedMemberSort.addedDate, ids: ['a', 'b', 'c', 'd']),
    (sort: FollowingFeedMemberSort.newestFirst, ids: ['b', 'a', 'c', 'd']),
    (sort: FollowingFeedMemberSort.oldestFirst, ids: ['a', 'c', 'b', 'd']),
  ]) {
    test(
      '${c.sort.name} uses membership order for equal and missing dates without NEW priority',
      () {
        final before = members.map((m) => m).toList();
        expect(
          sortFollowingFeedMembers(members, c.sort).map((m) => m.id),
          c.ids,
        );
        expect(members.map((m) => m.id), ['a', 'b', 'c', 'd']);
        expect(members.map((m) => m).toList(), before);
        expect(
          () => sortFollowingFeedMembers(members, c.sort).clear(),
          throwsUnsupportedError,
        );
      },
    );
  }
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
        sortFollowingFeedMembers([
          for (final id in feed.sourceIds) byId[id]!,
        ], FollowingFeedMemberSort.addedDate).map((s) => s.query),
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
