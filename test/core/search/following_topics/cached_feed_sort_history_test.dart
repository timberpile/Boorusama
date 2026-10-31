import 'package:boorusama/core/posts/listing/providers.dart';
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
      'cached sort blocks history and Newest restores it at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final historyRequests = <int>[];
        final harness = FollowingTopicHarness(
          overrides: [
            originAwarePostRepoProvider.overrideWith(
              (ref, config) => TestSearchPostRepository((
                query,
                page,
                limit,
              ) async {
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
        expect(find.text('History'), findsOneWidget);
        final sort = find.byKey(const ValueKey('cached-feed-sort'));
        final selector = tester
            .widget<BookmarkOptionSelector<CachedTopicFeedSort>>(sort);
        final descending = selector.optionLabel(
          CachedTopicFeedSort.scoreDescending,
        );
        await tester.tap(
          find.descendant(of: sort, matching: find.byType(Icon)).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(descending).last);
        await tester.pumpAndSettle();
        await drain(tester);

        final sorted = tester.widget<PostGrid<Post>>(grid).controller;
        expect(sorted.items.map((post) => post.id), [2, 1, 3]);
        expect(find.text('Load older posts'), findsNothing);
        await _fetchMore(tester, sorted);
        expect(historyRequests, isEmpty);
        expect(sorted.items.map((post) => post.id), [2, 1, 3]);
        expect(
          (await harness.repository.getFeeds()).single.posts,
          feed.posts,
          reason: 'Local sorting must not rewrite the stored snapshot order.',
        );

        expect(find.text('Cached'), findsOneWidget);
        await tester.tap(
          find.descendant(of: sort, matching: find.byType(Icon)).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(selector.optionLabel(CachedTopicFeedSort.newest)).last,
        );
        await tester.pumpAndSettle();
        await drain(tester);
        expect(sort, findsOneWidget);
        expect(find.text('History'), findsOneWidget);
        final restored = tester.widget<PostGrid<Post>>(grid).controller;
        expect(restored.items.map((post) => post.id), [1, 2, 3]);
        expect(restored.hasMore, isTrue);
        expect(historyRequests, isEmpty);
        await _fetchMore(tester, restored);
        expect(historyRequests, [1]);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'the actual Feed bar hides down and returns after a slight upward scroll',
    (tester) async {
      final harness = FollowingTopicHarness();
      addTearDown(harness.dispose);
      final source = topicFixture(query: 'cat');
      await harness.seed([source]);
      final feed = TopicFeed(
        id: 'scroll-toolbar',
        profileId: testProfile.id,
        name: 'Feed',
        sourceIds: [source.id],
        initializedSourceIds: [source.id],
        posts: [for (var i = 1; i <= 100; i++) _snapshot(i, i)],
      );
      await harness.repository.restoreFeeds(testProfile.id, [feed]);
      await harness.pump(
        tester,
        TopicFeedPage(feedId: feed.id, profileId: testProfile.id),
      );
      await drain(tester);
      final sort = find.byKey(const ValueKey('cached-feed-sort'));
      final grid = find.byType(PostGrid<Post>);
      expect(sort.hitTestable(), findsOneWidget);
      await tester.drag(grid, const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(sort.hitTestable(), findsNothing);
      await tester.drag(grid, const Offset(0, 32));
      await tester.pumpAndSettle();
      expect(sort.hitTestable(), findsOneWidget);
      final vertical = find.descendant(
        of: grid,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      expect(
        tester.state<ScrollableState>(vertical.first).position.pixels,
        greaterThan(200),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

StoredPostSnapshot _snapshot(int id, int score) =>
    const StoredPostCodec().encode(
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

Future<void> _fetchMore(
  WidgetTester tester,
  PostGridController<Post> controller,
) async {
  var completed = false;
  final pending = controller.fetchMore().then<void>((_) {
    completed = true;
  });
  // fetchMore owns a debounce timer; advance its controlled clock before
  // waiting for the completion signal rather than blocking the widget zone.
  await tester.pump(controller.debounceDuration);
  await drain(tester);
  expect(
    completed,
    isTrue,
    reason: 'The in-memory pagination request must complete.',
  );
  await pending;
}
