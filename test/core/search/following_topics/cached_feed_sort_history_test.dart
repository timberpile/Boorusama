import 'package:boorusama/core/bookmarks/src/widgets/bookmark_option_selector.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/search/following_topics/src/pages/topic_feeds_page.dart';
import 'package:boorusama/core/search/following_topics/src/types/cached_topic_feed_filter.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

import 'following_topic_test_utils.dart';
import 'topic_test_utils.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'sort-only Feed Search blocks history and closing restores it at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final historyRequests = <int>[];
        final harness = FollowingTopicHarness(
          overrides: [
            originAwarePostRepoProvider.overrideWith(
              (ref, config) => TestSearchPostRepository((query, page, limit) async {
                historyRequests.add(page);
                return Either.of(
                  const PostResult<Post>(posts: [], total: 0, hasMore: false),
                );
              }),
            ),
          ],
        );
        addTearDown(harness.dispose);
        final source = topicFixture(query: 'cat');
        await harness.seed([source]);
        final feed = TopicFeed(
          id: 'sort-history',
          profileId: testProfile.id,
          name: 'Cached feed',
          sourceIds: [source.id],
          initializedSourceIds: [source.id],
          posts: [_snapshot(1, 5), _snapshot(2, 20), _snapshot(3, -1)],
        );
        await harness.repository.restoreFeeds(testProfile.id, [feed]);
        await harness.pump(
          tester,
          MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 640),
              textScaler: TextScaler.linear(scale),
            ),
            child: TopicFeedPage(feedId: feed.id, profileId: testProfile.id),
          ),
        );
        await drain(tester);
        final grid = find.byType(PostGrid<Post>);
        expect(grid, findsOneWidget);
        expect(historyRequests, isEmpty);
        expect(find.byKey(const ValueKey('cached-feed-sort')), findsNothing);

        await tester.tap(find.byKey(const ValueKey('toggle-cached-feed-search')));
        await tester.pumpAndSettle();
        final sort = find.byKey(const ValueKey('cached-feed-sort'));
        final selector = tester.widget<BookmarkOptionSelector<CachedTopicFeedSort>>(sort);
        final descending = selector.optionLabel(CachedTopicFeedSort.scoreDescending);
        await tester.ensureVisible(sort);
        await tester.tap(sort);
        await tester.pumpAndSettle();
        await tester.tap(find.text(descending).last);
        await tester.pumpAndSettle();
        await drain(tester);

        final sorted = tester.widget<PostGrid<Post>>(grid).controller;
        expect(sorted.items.map((post) => post.id), [2, 1, 3]);
        expect(find.text('Load older posts'), findsNothing);
        await sorted.fetchMore();
        await drain(tester);
        expect(historyRequests, isEmpty);
        expect(sorted.items.map((post) => post.id), [2, 1, 3]);
        expect(
          (await harness.repository.getFeeds()).single.posts,
          feed.posts,
          reason: 'Local sorting must not rewrite the stored snapshot order.',
        );

        await tester.tap(find.byKey(const ValueKey('toggle-cached-feed-search')));
        await tester.pumpAndSettle();
        await drain(tester);
        expect(sort, findsNothing);
        final restored = tester.widget<PostGrid<Post>>(grid).controller;
        expect(restored.items.map((post) => post.id), [1, 2, 3]);
        expect(restored.hasMore, isTrue);
        expect(historyRequests, isEmpty);
        await restored.fetchMore();
        await drain(tester);
        expect(historyRequests, [1]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

StoredPostSnapshot _snapshot(int id, int score) => const StoredPostCodec().encode(
  Post(
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
      score: score,
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
  ),
);
