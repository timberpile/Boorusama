import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/providers/feed_member_preview_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feed_member_preview_test.dart' show ByteCache;
import 'following_topic_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'refresh progress does not restart cache-only member previews',
    () async {
      final h = FollowingTopicHarness(
        loadImages: true,
        imageCacheManager: ByteCache(),
      );
      addTearDown(h.dispose);
      final feed = await h.repository.saveFeed(
        profileId: testProfile.id,
        name: 'Preview activity',
        queries: ['cat'],
      );
      await h.seed([
        topicFixture(id: feed.sourceIds.single, previewCount: 1),
      ]);
      await h.container.read(followingTopicsProvider.future);
      final provider = feedMemberPreviewProvider((
        feedId: feed.id,
        sourceId: feed.sourceIds.single,
      ));
      final subscription = h.container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final original = h.container.read(provider.future);
      expect(await original, isEmpty);

      final progress = h.container
          .read(followingTopicsProvider.notifier)
          .beginRefreshProgress(feed.sourceIds);
      addTearDown(progress.close);
      for (var i = 0; i < 10; i++) {
        progress.update(i.isEven ? feed.sourceIds : const []);
        final current = h.container.read(provider.future);
        await current;
        expect(identical(current, original), isTrue);
      }
      expect(h.requests, isEmpty);
    },
  );

  test('a real library publication still refreshes member inputs', () async {
    final h = FollowingTopicHarness(
      loadImages: true,
      imageCacheManager: ByteCache(),
    );
    addTearDown(h.dispose);
    final feed = await h.repository.saveFeed(
      profileId: testProfile.id,
      name: 'Preview publication',
      queries: ['cat'],
    );
    await h.seed([
      topicFixture(id: feed.sourceIds.single, previewCount: 1),
    ]);
    await h.container.read(followingTopicsProvider.future);
    final provider = feedMemberPreviewProvider((
      feedId: feed.id,
      sourceId: feed.sourceIds.single,
    ));
    final subscription = h.container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final original = h.container.read(provider.future);
    await original;

    await h.container
        .read(followingTopicsProvider.notifier)
        .runSerializedMutation(
          (_) => h.seed([
            topicFixture(id: feed.sourceIds.single, previewCount: 2),
          ]),
        );
    final updated = h.container.read(provider.future);
    await updated;
    expect(identical(updated, original), isFalse);
    expect(h.requests, isEmpty);
  });
}
