import 'dart:async';

import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/search/following_topics/src/pages/topic_feeds_page.dart';
import 'package:boorusama/core/search/following_topics/src/pages/topic_feed_management_page.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:clock/clock.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'following_topic_test_utils.dart';

Future<TopicFeed> seed(
  WidgetTester tester,
  FollowingTopicHarness h, {
  int count = 25,
}) async {
  late TopicFeed feed;
  await tester.runAsync(() async {
    feed = await h.repository.saveFeed(
      profileId: testProfile.id,
      name: 'Artists',
      queries: [for (var i = 0; i < count; i++) 'artist_$i'],
    );
    await h.container.read(followingTopicsProvider.future);
  });
  return feed;
}

Future<T> finish<T>(WidgetTester tester, Future<T> operation) async {
  var completed = false;
  final result = operation.whenComplete(() => completed = true);
  await drain(tester);
  expect(completed, isTrue);
  return result;
}

void main() {
  testWidgets(
    'manual batches stay within selected feed and failing sources rotate out of the next batch',
    (tester) async {
      var now = checkedAt.add(const Duration(days: 2));
      final h = FollowingTopicHarness(
        clock: Clock(() => now),
        fetchPosts: (_, _, _, _) async =>
            Either.left(UnknownError(error: 'failure', message: 'failure')),
      );
      addTearDown(h.dispose);
      final feed = await seed(tester, h);
      await tester.runAsync(() async {
        await h.repository.saveFeed(
          profileId: otherTestProfile.id,
          name: 'Other',
          queries: ['other'],
        );
        await h.seed([
          ...await h.repository.getAll(),
          topicFixture(id: 'topic', query: 'independent'),
        ]);
        await h.container
            .read(followingTopicsProvider.notifier)
            .runSerializedMutation((_) async {});
      });
      final pinBefore = await tester.runAsync(
        () => h.repository.getById('topic'),
      );
      final notifier = h.container.read(followingTopicsProvider.notifier);
      final first = await finish(tester, notifier.refreshFeed(feed.id));
      expect(first, hasLength(10));
      expect(h.requests, hasLength(10));
      now = now.add(const Duration(minutes: 1));
      final second = await finish(tester, notifier.refreshFeed(feed.id));
      expect(second, hasLength(10));
      expect(h.requests.map((r) => r.query).toSet(), hasLength(20));
      expect(
        h.requests.every(
          (r) => r.profileId == testProfile.id && r.query.startsWith('artist_'),
        ),
        isTrue,
      );
      expect(
        await tester.runAsync(() => h.repository.getById('topic')),
        pinBefore,
      );
      expect(
        h.container
            .read(followingTopicsProvider)
            .requireValue
            .pendingRefreshIds,
        isEmpty,
      );
      expect(
        h.container.read(followingTopicsProvider).requireValue.refreshingFeedId,
        isNull,
      );
    },
  );

  testWidgets(
    'only one source runs at once, repeated taps coalesce, and another feed is not queued',
    (tester) async {
      final h = FollowingTopicHarness();
      addTearDown(h.dispose);
      final feed = await seed(tester, h, count: 2);
      late TopicFeed other;
      await tester.runAsync(() async {
        other = await h.container
            .read(followingTopicsProvider.notifier)
            .saveFeed(
              profileId: testProfile.id,
              name: 'Other',
              queries: ['other'],
            );
      });
      h.refreshGate = Completer<void>();
      final notifier = h.container.read(followingTopicsProvider.notifier);
      final run = notifier.refreshFeed(feed.id);
      await drain(tester);
      expect(h.requests, hasLength(1));
      expect(notifier.refreshFeed(feed.id), same(run));
      expect(await notifier.refreshFeed(other.id), isEmpty);
      expect(
        h.container.read(followingTopicsProvider).requireValue.refreshingFeedId,
        feed.id,
      );
      h.refreshGate!.complete();
      expect(await finish(tester, run), hasLength(2));
      expect(h.requests, hasLength(2));
      expect(h.requests.any((r) => r.query == 'other'), isFalse);
    },
  );

  testWidgets('site cooldown stops the batch after one response', (
    tester,
  ) async {
    final h = FollowingTopicHarness(
      fetchPosts: (_, _, _, _) async => Either.left(
        RateLimitedError(checkedAt.add(const Duration(days: 30))),
      ),
    );
    addTearDown(h.dispose);
    final feed = await seed(tester, h);
    final result = await finish(
      tester,
      h.container.read(followingTopicsProvider.notifier).refreshFeed(feed.id),
    );
    expect(result, hasLength(1));
    expect(result.single, isA<SearchRefreshDeferred>());
    expect(h.requests, hasLength(1));
  });

  testWidgets('deadline releases manual batch and starts no remaining source', (
    tester,
  ) async {
    final h = FollowingTopicHarness();
    addTearDown(h.dispose);
    final feed = await seed(tester, h, count: 2);
    h.refreshGate = Completer<void>();
    final run = h.container
        .read(followingTopicsProvider.notifier)
        .refreshFeed(feed.id);
    await drain(tester);
    expect(h.requests, hasLength(1));
    await tester.pump(const Duration(seconds: 21));
    await drain(tester);
    expect(await run, [const SearchRefreshDiscarded()]);
    expect(h.requests, hasLength(1));
    expect(
      h.container.read(followingTopicsProvider).requireValue.refreshingFeedId,
      isNull,
    );
    h.refreshGate!.complete();
    await drain(tester);
  });

  testWidgets('deleted feed cancels remaining membership work safely', (
    tester,
  ) async {
    final h = FollowingTopicHarness();
    addTearDown(h.dispose);
    final feed = await seed(tester, h, count: 2);
    h.refreshGate = Completer<void>();
    final notifier = h.container.read(followingTopicsProvider.notifier);
    final run = notifier.refreshFeed(feed.id);
    await drain(tester);
    await finish(tester, notifier.deleteFeed(feed.id));
    h.refreshGate!.complete();
    await finish(tester, run);
    expect(h.requests, hasLength(1));
    expect(await finish(tester, notifier.refreshFeed('missing')), isEmpty);
  });

  testWidgets(
    'feed menu Refresh runs a bounded batch even when automatic refresh is disabled',
    (tester) async {
      final h = FollowingTopicHarness(
        settings: Settings.defaultSettings.copyWith(
          searchRefresh: const SearchRefreshSettings(enabled: false),
        ),
        fetchPosts: (_, _, _, _) async =>
            Either.of(const PostResult(posts: <Post>[], total: 0)),
      );
      addTearDown(h.dispose);
      final feed = await seed(tester, h, count: 12);
      await h.pump(
        tester,
        TopicFeedPage(feedId: feed.id, profileId: testProfile.id),
      );
      await drain(tester);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh'));
      await drain(tester);
      expect(h.requests, hasLength(10));
      expect(
        h.container.read(followingTopicsProvider).requireValue.refreshingFeedId,
        isNull,
      );
    },
  );

  testWidgets('feed refresh shows stable determinate batch progress', (
    tester,
  ) async {
    final secondCheck = Completer<void>();
    var checks = 0;
    final h = FollowingTopicHarness(
      fetchPosts: (_, _, _, _) async {
        checks++;
        if (checks == 2) await secondCheck.future;
        return Either.of(const PostResult(posts: <Post>[], total: 0));
      },
    );
    addTearDown(h.dispose);
    final feed = await seed(tester, h, count: 2);
    await h.pump(
      tester,
      TopicFeedPage(feedId: feed.id, profileId: testProfile.id),
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh'));
    await drain(tester);

    final running = h.container.read(followingTopicsProvider).requireValue;
    expect(running.refreshingFeedId, feed.id);
    expect(running.feedRefreshChecked, 1);
    expect(running.feedRefreshTotal, 2);
    expect(find.text('Checked 1 of 2 · 1 remaining'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .value,
      0.5,
    );

    secondCheck.complete();
    await drain(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  for (final narrow in [false, true]) {
    testWidgets(
      'profile and last post share a row aligned to the right (narrow: $narrow)',
      (tester) async {
        if (narrow) {
          await tester.binding.setSurfaceSize(const Size(280, 700));
          addTearDown(() => tester.binding.setSurfaceSize(null));
        }
        final h = FollowingTopicHarness();
        addTearDown(h.dispose);
        final feed = await seed(tester, h, count: 1);
        Widget scaled(Widget page) => MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(narrow ? 2 : 1)),
          child: page,
        );
        await h.pump(tester, scaled(const TopicFeedsPage()));
        final profile = find.text(testProfile.url);
        final last = find.textContaining('Last post:');
        expect(
          tester.getCenter(last).dy,
          closeTo(tester.getCenter(profile).dy, 1),
        );
        expect(
          tester.getBottomRight(last).dx,
          closeTo(
            tester.getBottomRight(find.byType(FollowingTopicCardMetadata)).dx,
            1,
          ),
        );
        expect(tester.takeException(), isNull);
        await h.pump(
          tester,
          scaled(TopicFeedManagementPage(feedId: feed.id)),
        );
        expect(
          tester.getCenter(last).dy,
          closeTo(tester.getCenter(profile).dy, 1),
        );
        expect(
          tester.getBottomRight(last).dx,
          closeTo(
            tester.getBottomRight(find.byType(FollowingTopicCardMetadata)).dx,
            1,
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
