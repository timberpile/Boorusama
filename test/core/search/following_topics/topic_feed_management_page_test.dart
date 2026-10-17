import 'dart:async';
import 'package:clock/clock.dart';
import 'package:i18n/i18n.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/search/following_topics/src/pages/topic_feed_management_page.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_info_dialog.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'following_topic_test_utils.dart';

void main() {
  late FollowingTopicHarness h;
  setUp(() => h = FollowingTopicHarness());
  tearDown(() => h.dispose());
  Future<TopicFeed> seed(WidgetTester tester) async {
    late TopicFeed feed;
    await tester.runAsync(() async {
      feed = await h.repository.saveFeed(
        profileId: otherTestProfile.id,
        name: 'Artists',
        queries: ['cat', 'dog'],
      );
      await h.seed([
        topicFixture(
          id: feed.sourceIds[0],
          profileId: otherTestProfile.id,
          query: 'cat',
          previewCount: 1,
          error: SearchRefreshErrorKind.network,
        ),
        topicFixture(
          id: feed.sourceIds[1],
          profileId: otherTestProfile.id,
          query: 'dog',
          name: null,
          checked: false,
          unreadCount: 0,
        ),
      ]);
      await h.container.read(followingTopicsProvider.future);
    });
    await h.pump(tester, TopicFeedManagementPage(feedId: feed.id));
    return feed;
  }

  testWidgets(
    'editor shows named cards and last post metadata without initialization',
    (tester) async {
      await seed(tester);
      expect(find.byType(FollowingTopicCard), findsNWidgets(2));
      expect(find.text('Cats'), findsOneWidget);
      expect(find.text('cat'), findsOneWidget);
      expect(find.textContaining('Last post:'), findsNWidgets(2));
      expect(find.textContaining('Last checked:'), findsNothing);
      expect(find.text('NEW'), findsOneWidget);
      expect(
        find.text('Could not connect. Try refreshing again.'),
        findsOneWidget,
      );
      expect(h.requests, isEmpty);
    },
  );
  testWidgets(
    'member menus contain refresh edit remove without topic controls',
    (
      tester,
    ) async {
      await seed(tester);
      await tester.tap(
        find
            .descendant(
              of: find.byType(FollowingTopicCard).first,
              matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Unfollow'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Move to folder'), findsNothing);
      expect(find.text('Move up'), findsNothing);
    },
  );
  testWidgets(
    'member Details opens cached timing without changing membership',
    (tester) async {
      final feed = await seed(tester);
      final before = await tester.runAsync(h.repository.getAll);
      await tester.tap(
        find
            .descendant(
              of: find.byType(FollowingTopicCard).first,
              matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      final info = tester.widget<FollowingTopicInfoDialog>(
        find.byType(FollowingTopicInfoDialog),
      );
      expect(info.topicId, feed.sourceIds.first);
      expect(find.textContaining('Refresh interval: Adaptive'), findsOneWidget);
      expect(await tester.runAsync(h.repository.getAll), before);
      expect((await tester.runAsync(h.repository.getFeeds))!.single, feed);
      expect(h.requests, isEmpty);
      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await tester.pumpAndSettle();
      expect(find.byType(FollowingTopicInfoDialog), findsNothing);
    },
  );

  testWidgets(
    'sort changes display and survives reopen without changing membership or read state',
    (tester) async {
      final feed = await seed(tester);
      final before = await tester.runAsync(h.repository.getAll);
      await tester.tap(find.byTooltip('Sort by'));
      await tester.pumpAndSettle();
      expect(find.text('Added Date'), findsOneWidget);
      expect(find.text('Newest first'), findsOneWidget);
      await tester.tap(find.text('Oldest first'));
      await drain(tester);
      expect(
        h.container.read(settingsProvider).topicFeedMemberSort,
        'oldestFirst',
      );
      expect(
        (await tester.runAsync(h.repository.getFeeds))!.single.sourceIds,
        feed.sourceIds,
      );
      expect(await tester.runAsync(h.repository.getAll), before);
      expect(h.requests, isEmpty);
      await h.pump(tester, TopicFeedManagementPage(feedId: feed.id));
      await tester.tap(find.byTooltip('Sort by'));
      await tester.pumpAndSettle();
      final selected = tester.widget<PopupMenuButton<TopicFeedMemberSort>>(
        find.byType(PopupMenuButton<TopicFeedMemberSort>),
      );
      expect(selected.initialValue, TopicFeedMemberSort.oldestFirst);
    },
  );
  testWidgets(
    'cards show last successful refresh below last post and refresh sorting persists without source mutations',
    (tester) async {
      final feed = await withClock(
        Clock.fixed(checkedAt.add(const Duration(hours: 2))),
        () => seed(tester),
      );
      expect(find.text('Last refresh: 2 hours ago'), findsOneWidget);
      expect(find.text('Last refresh: Never checked'), findsOneWidget);
      final lastPost = find.descendant(
        of: find.byType(FollowingTopicCard).first,
        matching: find.textContaining('Last post:'),
      );
      final lastRefresh = find.text('Last refresh: 2 hours ago');
      expect(
        tester.getCenter(lastRefresh).dy,
        greaterThan(tester.getCenter(lastPost).dy),
      );
      expect(
        tester.getBottomRight(lastRefresh).dx,
        closeTo(tester.getBottomRight(lastPost).dx, 1),
      );
      final before = await tester.runAsync(h.repository.getAll);
      await tester.tap(find.byTooltip('Sort by'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last refresh (oldest first)'));
      await drain(tester);
      expect(
        h.container.read(settingsProvider).topicFeedMemberSort,
        'lastRefresh',
      );
      expect(
        tester
            .widget<FollowingTopicCard>(find.byType(FollowingTopicCard).first)
            .topic
            .query,
        'dog',
      );
      expect(await tester.runAsync(h.repository.getAll), before);
      expect((await tester.runAsync(h.repository.getFeeds))!.single, feed);
      await h.pump(tester, TopicFeedManagementPage(feedId: feed.id));
      await tester.tap(find.byTooltip('Sort by'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuButton<TopicFeedMemberSort>>(
              find.byType(PopupMenuButton<TopicFeedMemberSort>),
            )
            .initialValue,
        TopicFeedMemberSort.lastRefresh,
      );
      expect(h.requests, isEmpty);
    },
  );

  testWidgets(
    'name edit explains sharing, cancel is inert and clearing restores the query title',
    (tester) async {
      final feed = await seed(tester);
      await tester.runAsync(() async {
        await h.container
            .read(followingTopicsProvider.notifier)
            .saveFeed(
              profileId: otherTestProfile.id,
              name: 'Shared',
              queries: ['cat'],
            );
      });
      await tester.pump();
      Future<void> edit() async {
        await tester.tap(
          find
              .descendant(
                of: find.byType(FollowingTopicCard).first,
                matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
      }

      final before = await tester.runAsync(h.repository.getAll);
      await edit();
      expect(find.text('Query: cat'), findsOneWidget);
      expect(
        find.text('Changes to this name apply wherever this topic appears.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Ignored');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await tester.runAsync(h.repository.getAll), before);
      await edit();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Save'));
      await drain(tester);
      await tester.pumpAndSettle();
      expect(find.text('Cats'), findsNothing);
      final stored = (await tester.runAsync(
        () => h.repository.getById(feed.sourceIds.first),
      ))!;
      expect(stored.name, isNull);
      expect(stored.hasNewPosts, isTrue);
      expect(
        stored.previews,
        before!.firstWhere((s) => s.id == feed.sourceIds.first).previews,
      );
      expect(h.requests, isEmpty);
    },
  );
  testWidgets(
    'failed name save stays inline and keeps the typed name for retry',
    (tester) async {
      await seed(tester);
      await tester.tap(
        find
            .descendant(
              of: find.byType(FollowingTopicCard).first,
              matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Retry name');
      h.box.failWrites = true;
      await tester.tap(find.text('Save'));
      await drain(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Retry name',
      );
      expect(
        find.text('Could not update the topic. Try again.'),
        findsOneWidget,
      );
      h.box.failWrites = false;
      await tester.tap(find.text('Save'));
      await drain(tester);
      await tester.pumpAndSettle();
      expect(find.text('Retry name'), findsOneWidget);
    },
  );
  testWidgets(
    'refresh marks only its source busy and preserves other usable rows',
    (tester) async {
      await seed(tester);
      h.refreshGate = Completer<void>();
      await tester.tap(
        find
            .descendant(
              of: find.byType(FollowingTopicCard).first,
              matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh'));
      await drain(tester);
      expect(h.requests, hasLength(1));
      expect(h.requests.single.query, 'cat');
      expect(h.requests.single.profileId, otherTestProfile.id);
      expect(find.text('Refreshing…'), findsOneWidget);
      await tester.tap(
        find
            .descendant(
              of: find.byType(FollowingTopicCard).first,
              matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuItem<FollowingTopicAction>>(
              find.widgetWithText(
                PopupMenuItem<FollowingTopicAction>,
                'Refresh',
              ),
            )
            .enabled,
        isFalse,
      );
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      h.refreshGate!.complete();
      await drain(tester);
      expect(find.text('Refreshing…'), findsNothing);
    },
  );
  for (final locale in ['en-US', 'de-DE']) {
    testWidgets(
      '$locale cards and name dialog remain reachable at narrow width and doubled text',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(280, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(() => ensureI18nInitialized('en-US'));
        final feed = await seed(tester);
        await tester.runAsync(() => ensureI18nInitialized(locale));
        await tester.pumpWidget(
          h.wrap(
            MaterialApp(
              builder: themeBuilder,
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: TopicFeedManagementPage(feedId: feed.id),
              ),
            ),
          ),
        );
        await drain(tester);
        expect(tester.takeException(), isNull);
        expect(
          find.textContaining(
            locale == 'de-DE' ? 'Zuletzt aktualisiert:' : 'Last refresh:',
          ),
          findsNWidgets(2),
        );
        await tester.tap(find.byType(PopupMenuButton<TopicFeedMemberSort>));
        await tester.pumpAndSettle();
        expect(
          find
              .text(
                locale == 'de-DE'
                    ? 'Letzte Aktualisierung (älteste zuerst)'
                    : 'Last refresh (oldest first)',
              )
              .hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tapAt(Offset.zero);
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .descendant(
                of: find.byType(FollowingTopicCard).first,
                matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(locale == 'de-DE' ? 'Bearbeiten' : 'Edit'));
        await tester.pumpAndSettle();
        expect(
          find.text(locale == 'de-DE' ? 'Speichern' : 'Save'),
          findsOneWidget,
        );
        expect(
          find.text(locale == 'de-DE' ? 'Abbrechen' : 'Cancel'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final failRead in [false, true]) {
    testWidgets(
      '${failRead ? 'failed' : 'successful'} mark read preserves exact owner navigation semantics',
      (tester) async {
        final feed = await seed(tester);
        Uri? opened;
        h.router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => TopicFeedManagementPage(feedId: feed.id),
            ),
            GoRoute(
              path: '/search',
              builder: (_, state) {
                opened = state.uri;
                return const Scaffold(body: Text('Opened search'));
              },
            ),
          ],
        );
        addTearDown(h.router.dispose);
        await tester.pumpWidget(
          h.wrap(
            MaterialApp.router(routerConfig: h.router, builder: themeBuilder),
          ),
        );
        await drain(tester);
        expect(h.container.read(currentBooruConfigProvider).id, testProfile.id);
        h.box.failWrites = failRead;
        await tester.tap(find.text('Cats'));
        await drain(tester);
        if (failRead) {
          expect(opened, isNull);
          expect(
            h.container.read(currentBooruConfigProvider).id,
            testProfile.id,
          );
        } else {
          expect(opened!.queryParameters['query'], 'cat');
          expect(
            h.container.read(currentBooruConfigProvider).id,
            otherTestProfile.id,
          );
        }
        final stored = (await tester.runAsync(
          () => h.repository.getById(feed.sourceIds.first),
        ))!;
        expect(stored.hasNewPosts, failRead);
        expect(h.requests, isEmpty);
      },
    );
  }

  testWidgets(
    'remove changes only selected membership and deleting the last member returns to its parent',
    (tester) async {
      final feed = await seed(tester);
      await tester.pumpWidget(
        h.wrap(
          MaterialApp(
            builder: themeBuilder,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TopicFeedManagementPage(feedId: feed.id),
                    ),
                  ),
                  child: const Text('Manage feed'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Manage feed'));
      await tester.pumpAndSettle();
      for (var remaining = 2; remaining > 0; remaining--) {
        await tester.tap(
          find
              .descendant(
                of: find.byType(FollowingTopicCard).first,
                matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unfollow'));
        await drain(tester);
        await tester.pumpAndSettle();
        if (remaining == 2) {
          expect(find.byType(FollowingTopicCard), findsOneWidget);
        }
      }
      expect(find.text('Manage feed'), findsOneWidget);
      expect(await tester.runAsync(h.repository.getFeeds), isEmpty);
      expect(h.requests, isEmpty);
    },
  );
}
