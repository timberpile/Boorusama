import 'dart:async';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/search/following_topics/src/pages/topic_feeds_page.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/topic_feed_info_dialog.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_info_dialog.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'following_topic_test_utils.dart';
import 'topic_test_utils.dart';

void main() {
  late FollowingTopicHarness h;
  setUp(() => h = FollowingTopicHarness());
  tearDown(() => h.dispose());

  Future<TopicFeed> seed(
    WidgetTester tester, {
    bool checked = true,
  }) async {
    late TopicFeed feed;
    await tester.runAsync(() async {
      feed = await h.repository.saveFeed(
        profileId: testProfile.id,
        name: 'Artists',
        queries: ['cat', 'dog'],
      );
      await h.seed([
        topicFixture(
          id: feed.sourceIds.first,
          query: 'cat',
          checked: checked,
          error: checked ? SearchRefreshErrorKind.rateLimited : null,
        ),
        topicFixture(
          id: feed.sourceIds.last,
          query: 'dog',
          name: 'Dogs',
          checked: false,
          unreadCount: 0,
        ),
      ]);
      await h.container.read(followingTopicsProvider.future);
    });
    return feed;
  }

  Future<void> openInfo(WidgetTester tester) async {
    await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Info').last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'opened feed moves cached status into a dismissible reactive Info dialog',
    (tester) async {
      final feed = await seed(tester);
      await h.pump(
        tester,
        TopicFeedPage(feedId: feed.id, profileId: testProfile.id),
      );
      await drain(tester);
      expect(find.textContaining('checked'), findsNothing);
      expect(find.textContaining('Last checked:'), findsNothing);
      expect(
        find.text('Rate limited by the site. Try again later.'),
        findsNothing,
      );
      final before = await tester.runAsync(h.repository.getAll);
      await openInfo(tester);
      expect(find.byType(TopicFeedInfoDialog), findsOneWidget);
      expect(find.text('1/2 topics checked · 1 errors'), findsOneWidget);
      expect(find.textContaining('Last checked:'), findsOneWidget);
      expect(
        find.text('Rate limited by the site. Try again later.'),
        findsOneWidget,
      );
      expect(h.requests, isEmpty);
      expect(await tester.runAsync(h.repository.getAll), before);
      final refresh = h.container
          .read(followingTopicsProvider.notifier)
          .refresh(feed.sourceIds.last);
      await drain(tester);
      await refresh;
      await drain(tester);
      expect(find.textContaining('2/2'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TopicFeedInfoDialog), findsNothing);
      expect(find.textContaining('Last checked:'), findsNothing);
    },
  );

  testWidgets(
    'active refresh progress stays visible while maintenance text is hidden',
    (tester) async {
      final feed = await seed(tester);
      await h.pump(
        tester,
        TopicFeedPage(feedId: feed.id, profileId: testProfile.id),
      );
      await drain(tester);
      h.refreshGate = Completer<void>();
      final refresh = h.container
          .read(followingTopicsProvider.notifier)
          .refresh(feed.sourceIds.last);
      await drain(tester);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('sources checked'), findsNothing);
      h.refreshGate!.complete();
      await drain(tester);
      await refresh;
      await drain(tester);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets('Last post uses the newest cached upload timestamp', (
    tester,
  ) async {
    final feed = await seed(tester);
    final latest = DateTime.now().subtract(const Duration(hours: 2));
    await tester.runAsync(() async {
      await h.container
          .read(followingTopicsProvider.notifier)
          .runSerializedMutation(
            (repo) => repo.restoreFeeds(testProfile.id, [
              feed.copyWith(
                posts: [
                  feedPostSnapshotFromPost(
                    testSearchPost(1, latest.subtract(const Duration(days: 1))),
                  ),
                  feedPostSnapshotFromPost(testSearchPost(2, latest)),
                ],
              ),
            ]),
          );
    });
    await h.pump(tester, const TopicFeedsPage());
    expect(find.text('Last post: 2 hours ago'), findsOneWidget);
    expect(h.requests, isEmpty);
  });

  testWidgets(
    'never checked and empty or deleted feeds are safe without requests',
    (tester) async {
      final feed = await seed(tester, checked: false);
      await h.pump(tester, TopicFeedInfoDialog(feedId: feed.id));
      expect(find.text('Never checked'), findsOneWidget);
      expect(find.textContaining('0/2'), findsOneWidget);
      await tester.runAsync(() async {
        await h.container
            .read(followingTopicsProvider.notifier)
            .runSerializedMutation(
              (repo) => repo.restoreFeeds(testProfile.id, [
                feed.copyWith(sourceIds: []),
              ]),
            );
      });
      await drain(tester);
      expect(find.textContaining('0/0'), findsOneWidget);
      expect(find.text('Never checked'), findsOneWidget);
      await tester.runAsync(
        () => h.container
            .read(followingTopicsProvider.notifier)
            .deleteFeed(feed.id),
      );
      await drain(tester);
      expect(find.text('No topic feeds yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(h.requests, isEmpty);
    },
  );

  testWidgets(
    'feed overview shows last post and profile-local persistent move actions',
    (tester) async {
      final first = await seed(tester);
      late TopicFeed second;
      await tester.runAsync(() async {
        await h.container
            .read(followingTopicsProvider.notifier)
            .saveFeed(
              profileId: otherTestProfile.id,
              name: 'Other profile',
              queries: ['bird'],
            );
        second = await h.container
            .read(followingTopicsProvider.notifier)
            .saveFeed(
              profileId: testProfile.id,
              name: 'Second',
              queries: ['fish'],
            );
      });
      await h.pump(tester, const TopicFeedsPage());
      expect(find.textContaining('Last post:'), findsNWidgets(3));
      await tester.tap(
        find.byWidgetPredicate((w) => w is PopupMenuButton).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuItem<String>>(
              find.widgetWithText(PopupMenuItem<String>, 'Move up'),
            )
            .enabled,
        isFalse,
      );
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Edit feed'), findsNothing);
      await tester.tap(find.text('Move down'));
      await drain(tester);
      final stored = (await tester.runAsync(h.repository.getFeeds))!;
      expect(
        stored.where((f) => f.profileId == testProfile.id).map((f) => f.id),
        [second.id, first.id],
      );
      expect(
        stored.firstWhere((f) => f.profileId == otherTestProfile.id).position,
        0,
      );
      await tester.tap(
        find
            .descendant(
              of: find.widgetWithText(Card, 'Second'),
              matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuItem<String>>(
              find.widgetWithText(PopupMenuItem<String>, 'Move up'),
            )
            .enabled,
        isFalse,
      );
      await tester.tap(find.text('Move down'));
      await drain(tester);
      expect(
        (await tester.runAsync(
          h.repository.getFeeds,
        ))!.where((f) => f.profileId == testProfile.id).map((f) => f.id),
        [first.id, second.id],
      );
      await tester.runAsync(() async {
        final notifier = h.container.read(followingTopicsProvider.notifier);
        await notifier.moveFeed(second.id, up: true);
        await notifier.moveFeed(second.id, up: true);
        await notifier.moveFeed('deleted', up: true);
      });
      await drain(tester);
      expect(
        (await tester.runAsync(
          h.repository.getFeeds,
        ))!.where((f) => f.profileId == testProfile.id).map((f) => f.id),
        [second.id, first.id],
      );
      expect(h.requests, isEmpty);
    },
  );

  for (final feedEnabled in [true, false]) {
    testWidgets(
      'source Info uses feed refresh scope ($feedEnabled) and starts no requests',
      (tester) async {
        h.dispose();
        h = FollowingTopicHarness(
          settings: Settings.defaultSettings.copyWith(
            searchRefresh: SearchRefreshSettings(
              followingTopicsEnabled: !feedEnabled,
              topicFeedsEnabled: feedEnabled,
            ),
          ),
        );
        final feed = await seed(tester);
        await h.pump(tester, TopicFeedInfoDialog(feedId: feed.id));
        await tester.tap(find.text('Cats · Info'));
        await tester.pumpAndSettle();
        expect(find.byType(FollowingTopicInfoDialog), findsOneWidget);
        expect(
          find.textContaining('Refresh interval: Adaptive'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Next refresh: Not scheduled'),
          feedEnabled ? findsNothing : findsOneWidget,
        );
        expect(h.requests, isEmpty);
      },
    );
  }

  testWidgets(
    'Info remains scrollable and dismissible at 280dp with enlarged text and keyboard',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(280, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final feed = await seed(tester);
      await h.pump(
        tester,
        MediaQuery(
          data: const MediaQueryData(
            size: Size(280, 700),
            textScaler: TextScaler.linear(2),
            viewInsets: EdgeInsets.only(bottom: 250),
          ),
          child: Scaffold(body: TopicFeedInfoDialog(feedId: feed.id)),
        ),
      );
      expect(
        find.widgetWithText(TextButton, 'OK').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
