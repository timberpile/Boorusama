import 'dart:io';

import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/providers/feed_member_preview_provider.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/search/following_topics/feed_member_preview_test.dart'
    show ByteCache;
import '../core/search/following_topics/following_topic_test_utils.dart';

void main() {
  testWidgets(
    'progress reuses a decoded cached preview; content publication invalidates it',
    (tester) async {
      await tester.runAsync(() async {
        final cache = ByteCache();
        final bytes = await File('test/fixtures/post_quality/target.png')
            .readAsBytes();
        cache.entries.addAll({
          'thumb': bytes,
          'sample': bytes,
          'original': bytes,
        });
        final mediaRequests = <String>[];
        final h = FollowingTopicHarness(
          loadImages: true,
          imageCacheManager: cache,
          onMediaRequest: (request) =>
              mediaRequests.add(request.uri.toString()),
          settings: Settings.defaultSettings.copyWith(
            listing: Settings.defaultSettings.listing.copyWith(
              imageQuality: ImageQuality.high,
            ),
          ),
        );
        addTearDown(h.dispose);
        var feed = await h.repository.saveFeed(
          profileId: testProfile.id,
          name: 'Populated previews',
          queries: ['cat'],
        );
        final id = feed.sourceIds.single;
        await h.seed([topicFixture(id: id, query: 'cat', previewCount: 1)]);
        feed = feed.copyWith(
          posts: [
            feedPostSnapshotFromJson({
              'id': 0,
              'createdAt': checkedAt.toIso8601String(),
              'thumbnail': 'thumb',
              'sample': 'sample',
              'original': 'original',
              'tags': ['cat'],
              'rating': 'general',
              'width': 100,
              'height': 100,
              'format': 'png',
            }, profileId: testProfile.id),
          ],
        );
        await h.repository.restoreFeeds(testProfile.id, [feed]);
        await h.container.read(followingTopicsProvider.future);
        final provider = feedMemberPreviewProvider((
          feedId: feed.id,
          sourceId: id,
        ));
        final subscription = h.container.listen(provider, (_, _) {});
        addTearDown(subscription.close);
        final original = h.container.read(provider.future);
        expect(await original, hasLength(1));
        final readCount = cache.reads.length;
        final progress = h.container
            .read(followingTopicsProvider.notifier)
            .beginRefreshProgress([id]);
        try {
          for (var i = 0; i < 20; i++) {
            progress.update(i.isEven ? [id] : const []);
            final next = h.container.read(provider.future);
            expect(await next, hasLength(1));
            expect(next, same(original));
          }
        } finally {
          progress.close();
        }
        expect(cache.reads.length, readCount);
        expect(mediaRequests, isEmpty);
        expect(h.requests, isEmpty);
        await h.container
            .read(followingTopicsProvider.notifier)
            .runSerializedMutation(
              (_) =>
                  h.seed([topicFixture(id: id, query: 'cat', previewCount: 0)]),
            );
        final changed = h.container.read(provider.future);
        expect(await changed, isEmpty);
        expect(identical(changed, original), isFalse);
      });
    },
  );
}
