import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/search/following_topics/types.dart';

import 'topic_test_utils.dart';

void main() {
  test('reset fences old destination writes while checkpoint and other feed commit', () async {
    final repository = memorySubscriptionRepository();
    final created = DateTime.utc(2026, 11, 18);
    const profile = '00000000-0000-4000-8000-00000000000c';
    final source = await repository.create(
      profileId: profile,
      query: 'cat',
      name: 'Cats',
      id: 'cat',
      createdAt: created,
    );
    await repository.restoreFeeds(profile, [
      for (final id in ['first', 'second'])
        TopicFeed(id: id, profileId: profile, name: id, sourceIds: [source.id]),
    ]);
    final generations = {
      for (final feed in await repository.getFeeds())
        feed.id: feed.cacheGeneration,
    };
    await repository.clearAllFeedCaches();
    // Simulate a separate unaffected destination captured after its reset.
    final feeds = await repository.getFeeds();
    generations['second'] = feeds
        .firstWhere((f) => f.id == 'second')
        .cacheGeneration;
    final result = await repository.commitRefresh(
      SearchRefreshCommit(
        topicId: source.id,
        expectedCreatedAt: source.createdAt,
        expectedCheckpoint: null,
        startedAt: created.add(const Duration(minutes: 1)),
        identityRetentionBoundary: created,
        baseline: true,
        discoveredPosts: const [],
        expectedFeedGenerations: generations,
        feedPosts: [feedPostSnapshotFromPost(testSearchPost(42, created))],
      ),
    );
    expect(result, isNotNull);
    final saved = await repository.getFeeds();
    expect(saved.firstWhere((f) => f.id == 'first').posts, isEmpty);
    expect(saved.firstWhere((f) => f.id == 'second').posts.map(feedPostId), [
      42,
    ]);
    expect(
      (await repository.getById(source.id))!.lastSuccessfulCheckAt,
      isNotNull,
    );
    final reopened = await repository.getFeeds();
    expect(reopened.first.cacheGeneration, greaterThan(generations['first']!));
    expect(reopened.first.toJson().containsKey('cacheGeneration'), isFalse);
  });
}
