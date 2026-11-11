import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/search/following_topics/src/pages/topic_feeds_page.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

import 'following_topic_test_utils.dart';
import 'topic_test_utils.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'feed count follows cached, history and filtered posts at $scale',
      (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final requests = <int>[];
        final harness = FollowingTopicHarness(
          overrides: [
            originAwarePostRepoProvider.overrideWith(
              (ref, config) => TestSearchPostRepository((
                query,
                page,
                limit,
              ) async {
                requests.add(page);
                return Either.of(
                  PostResult(posts: [_post(4)], total: 9999, hasMore: false),
                );
              }),
            ),
          ],
        );
        addTearDown(harness.dispose);
        final source = topicFixture(query: 'cat');
        await harness.seed([source]);
        final feed = TopicFeed(
          id: 'loaded-count',
          profileId: testProfile.id,
          name: 'Feed',
          sourceIds: [source.id],
          initializedSourceIds: [source.id],
          posts: [
            for (var id = 1; id <= 3; id++)
              const StoredPostCodec().encode(_post(id)),
          ],
        );
        await harness.repository.restoreFeeds(testProfile.id, [feed]);
        await harness.pump(
          tester,
          MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 640),
              textScaler: TextScaler.linear(scale),
              viewInsets: const EdgeInsets.only(bottom: 220),
            ),
            child: TopicFeedPage(feedId: feed.id, profileId: testProfile.id),
          ),
        );
        await drain(tester);
        expect(find.text('3 posts').hitTestable(), findsOneWidget);
        final controller = tester
            .widget<PostGrid<Post>>(find.byType(PostGrid<Post>))
            .controller;
        var completed = false;
        final pending = controller.fetchMore().then<void>(
          (_) => completed = true,
        );
        await tester.pump(controller.debounceDuration);
        await drain(tester);
        expect(completed, isTrue);
        await pending;
        expect(controller.total, 4);
        expect(find.text('4 posts'), findsOneWidget);
        expect(find.text('9999 posts'), findsNothing);
        expect(requests, [1]);

        final field = find.byType(TextField);
        await tester.enterText(field, 'no_matching_tag');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await drain(tester);
        expect(find.text('0 posts'), findsOneWidget);
        expect(requests, [1]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Post _post(int id) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.danbooru,
    booruId: BooruType.danbooru.id,
    source: testProfile.url,
  ),
  core: PostCoreData(
    id: id,
    createdAt: checkedAt.subtract(Duration(days: id)),
    thumbnailImageUrl: '',
    sampleImageUrl: '',
    originalImageUrl: '',
    tags: const {'cat'},
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: id,
    duration: 0,
    fileSize: 0,
    format: 'jpg',
    height: 100,
    md5: '',
    videoThumbnailUrl: '',
    videoUrl: '',
    width: 100,
  ),
  booruData: const LegacyPostData(typeKey: 'test', custom: {}),
);
