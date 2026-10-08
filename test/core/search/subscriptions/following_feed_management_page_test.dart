import 'dart:async';
import 'package:clock/clock.dart';
import 'package:i18n/i18n.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/following_feed_management_page.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/pinned_search_card.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/pinned_search_info_dialog.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'pinned_search_test_utils.dart';

void main() {
  late PinnedSearchHarness h;
  setUp(() => h = PinnedSearchHarness());
  tearDown(() => h.dispose());
  Future<SearchFollowingFeed> seed(WidgetTester tester) async {
    late SearchFollowingFeed feed;
    await tester.runAsync(() async {
      feed = await h.repository.saveFeed(
        profileId: otherTestProfile.id,
        name: 'Artists',
        queries: ['cat', 'dog'],
      );
      await h.seed([
        pinnedFixture(
          id: feed.sourceIds[0],
          profileId: otherTestProfile.id,
          query: 'cat',
          previewCount: 1,
          error: SearchRefreshErrorKind.network,
        ),
        pinnedFixture(
          id: feed.sourceIds[1],
          profileId: otherTestProfile.id,
          query: 'dog',
          name: null,
          checked: false,
          unreadCount: 0,
        ),
      ]);
      await h.container.read(searchSubscriptionsProvider.future);
    });
    await h.pump(tester, FollowingFeedManagementPage(feedId: feed.id));
    return feed;
  }

  testWidgets(
    'editor shows named cards and last post metadata without initialization',
    (tester) async {
      await seed(tester);
      expect(find.byType(PinnedSearchCard), findsNWidgets(2));
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
  testWidgets('member menus contain refresh edit remove without pin controls', (
    tester,
  ) async {
    await seed(tester);
    await tester.tap(
      find
          .descendant(
            of: find.byType(PinnedSearchCard).first,
            matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Info'), findsOneWidget);
    expect(find.text('Move to folder'), findsNothing);
    expect(find.text('Move up'), findsNothing);
  });
  testWidgets(
    'member Info opens cached timing without changing sources or membership',
    (tester) async {
      final feed = await seed(tester);
      final before = await tester.runAsync(h.repository.getAll);
      await tester.tap(
        find
            .descendant(
              of: find.byType(PinnedSearchCard).first,
              matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();
      final info = tester.widget<PinnedSearchInfoDialog>(
        find.byType(PinnedSearchInfoDialog),
      );
      expect(info.subscriptionId, feed.sourceIds.first);
      expect(info.feedSource, isTrue);
      expect(find.textContaining('Refresh interval: Adaptive'), findsOneWidget);
      expect(await tester.runAsync(h.repository.getAll), before);
      expect((await tester.runAsync(h.repository.getFeeds))!.single, feed);
      expect(h.requests, isEmpty);
      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await tester.pumpAndSettle();
      expect(find.byType(PinnedSearchInfoDialog), findsNothing);
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
        h.container.read(settingsProvider).followingFeedMemberSort,
        'oldestFirst',
      );
      expect(
        (await tester.runAsync(h.repository.getFeeds))!.single.sourceIds,
        feed.sourceIds,
      );
      expect(await tester.runAsync(h.repository.getAll), before);
      expect(h.requests, isEmpty);
      await h.pump(tester, FollowingFeedManagementPage(feedId: feed.id));
      await tester.tap(find.byTooltip('Sort by'));
      await tester.pumpAndSettle();
      final selected = tester.widget<PopupMenuButton<FollowingFeedMemberSort>>(
        find.byType(PopupMenuButton<FollowingFeedMemberSort>),
      );
      expect(selected.initialValue, FollowingFeedMemberSort.oldestFirst);
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
        of: find.byType(PinnedSearchCard).first,
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
        h.container.read(settingsProvider).followingFeedMemberSort,
        'lastRefresh',
      );
      expect(
        tester
            .widget<PinnedSearchCard>(find.byType(PinnedSearchCard).first)
            .subscription
            .query,
        'dog',
      );
      expect(await tester.runAsync(h.repository.getAll), before);
      expect((await tester.runAsync(h.repository.getFeeds))!.single, feed);
      await h.pump(tester, FollowingFeedManagementPage(feedId: feed.id));
      await tester.tap(find.byTooltip('Sort by'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuButton<FollowingFeedMemberSort>>(
              find.byType(PopupMenuButton<FollowingFeedMemberSort>),
            )
            .initialValue,
        FollowingFeedMemberSort.lastRefresh,
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
            .read(searchSubscriptionsProvider.notifier)
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
                of: find.byType(PinnedSearchCard).first,
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
        find.text('This name is shared by every feed containing this search.'),
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
              of: find.byType(PinnedSearchCard).first,
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
        find.text('Could not update the pinned search. Try again.'),
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
              of: find.byType(PinnedSearchCard).first,
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
              of: find.byType(PinnedSearchCard).first,
              matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuItem<PinnedSearchAction>>(
              find.widgetWithText(PopupMenuItem<PinnedSearchAction>, 'Refresh'),
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
                child: FollowingFeedManagementPage(feedId: feed.id),
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
        await tester.tap(find.byType(PopupMenuButton<FollowingFeedMemberSort>));
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
                of: find.byType(PinnedSearchCard).first,
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
              builder: (_, _) => FollowingFeedManagementPage(feedId: feed.id),
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
                      builder: (_) =>
                          FollowingFeedManagementPage(feedId: feed.id),
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
                of: find.byType(PinnedSearchCard).first,
                matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove'));
        await drain(tester);
        await tester.pumpAndSettle();
        if (remaining == 2) {
          expect(find.byType(PinnedSearchCard), findsOneWidget);
        }
      }
      expect(find.text('Manage feed'), findsOneWidget);
      expect(await tester.runAsync(h.repository.getFeeds), isEmpty);
      expect(h.requests, isEmpty);
    },
  );
}
