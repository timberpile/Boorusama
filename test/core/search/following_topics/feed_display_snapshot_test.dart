import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/search/following_topics/src/services/feed_display_snapshot.dart';
import 'package:boorusama/core/search/following_topics/src/types/topic_feed.dart';

import 'topic_test_utils.dart';
import 'following_topic_test_utils.dart';

void main() {
  TopicFeed feed(
    List<int> ids, {
    bool initialized = true,
    int generation = 0,
  }) => TopicFeed(
    id: 'feed',
    profileId: testProfile.id,
    name: 'Feed',
    sourceIds: const ['topic'],
    initializedSourceIds: initialized ? const ['topic'] : const [],
    cacheGeneration: generation,
    posts: [
      for (final id in ids)
        feedPostSnapshotFromPost(
          testSearchPost(id, DateTime.utc(2026, 11, 18)),
        ),
    ],
  );
  test('accepted rows, metadata, retention and pending replacement remain stable until apply', () {
    final view = FeedDisplaySnapshot();
    final initial = feed([3, 2]);
    view.observe(initial, definition: 'same');
    view.observe(feed([4, 3]), definition: 'same');
    expect(view.accepted, initial);
    view.observe(feed([5, 4]), definition: 'same');
    expect(view.accepted, initial);
    expect(view.pending!.posts.map(feedPostId), [5, 4]);
    view.apply(view.pending!, expectedGeneration: view.generation);
    expect(view.accepted!.posts.map(feedPostId), [5, 4]);
    expect(view.pending, isNull);
  });
  test(
    'settled empty initialization never accepts later retries automatically',
    () {
      final view = FeedDisplaySnapshot();
      view.observe(feed([], initialized: false), definition: 'same');
      view.settleInitialization(view.generation);
      view.observe(feed([2]), definition: 'same');
      expect(view.accepted!.posts, isEmpty);
      expect(view.pending!.posts.map(feedPostId), [2]);
    },
  );
  test('first useful results can settle initialization, reset stages later results', () {
    final view = FeedDisplaySnapshot();
    view.observe(feed([], initialized: false), definition: 0);
    view.observe(feed([2]), definition: 0);
    expect(view.accepted!.posts.map(feedPostId), [2]);
    view.observe(feed([], generation: 1), definition: 1);
    view.observe(feed([4], generation: 1), definition: 1);
    expect(view.accepted!.posts, isEmpty);
    expect(view.pending!.posts.map(feedPostId), [4]);
    view.apply(view.pending!, expectedGeneration: view.generation - 1);
    expect(view.accepted!.posts, isEmpty);
  });
}
