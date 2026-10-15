import 'package:boorusama/core/blacklists/widgets.dart';
import 'package:boorusama/core/bookmarks/widgets.dart';
import 'package:boorusama/core/bulk_downloads/widgets.dart';
import 'package:boorusama/core/download_manager/widgets.dart';
import 'package:boorusama/core/home/src/controllers/home_page_controller.dart';
import 'package:boorusama/core/home/src/pages/home_page_scaffold.dart';
import 'package:boorusama/core/home/src/types/custom_home.dart';
import 'package:boorusama/core/home/src/types/booru_config_selector_position.dart';
import 'package:boorusama/core/home/src/widgets/home_navigation_tile.dart';
import 'package:boorusama/core/home/src/widgets/side_bar_menu.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/search/widgets.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/routes.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_navigation_icon.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/tags/favorites/widgets.dart';
import 'package:boorusama/foundation/boot/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'following_topic_test_utils.dart';

void main() {
  late FollowingTopicHarness harness;
  late HomePageController controller;

  void initialize() {
    harness = FollowingTopicHarness();
    controller = HomePageController(scaffoldKey: GlobalKey<ScaffoldState>());
    addTearDown(harness.dispose);
    addTearDown(controller.dispose);
  }

  Widget desktopMenu({CustomHomeViewKey? viewKey, double width = 220}) =>
      SizedBox(
        width: width,
        child: Consumer(
          builder: (context, ref, _) => Column(
            children: coreDesktopTabBuilder(
              ref,
              BoxConstraints(maxWidth: width),
              viewKey,
              true,
              false,
              false,
            ),
          ),
        ),
      );

  Widget scaffold(Widget child) => InheritedHomePageController(
    controller: controller,
    child: Scaffold(body: child),
  );

  Widget mobileMenu() => ProviderScope(
    overrides: [
      settingsProvider.overrideWithValue(
        Settings.defaultSettings.copyWith(
          booruConfigSelectorPosition: BooruConfigSelectorPosition.bottom,
        ),
      ),
      customHomeViewKeyProvider.overrideWithValue(null),
      hasPremiumProvider.overrideWithValue(true),
      hasBooruConfigsProvider.overrideWithValue(false),
      isFossBuildProvider.overrideWithValue(true),
    ],
    child: const SideBarMenu(),
  );

  Finder pinnedBadge(bool mobile) => find.descendant(
    of: mobile
        ? find.byType(FollowingTopicNavigationIcon)
        : find.byWidgetPredicate(
            (widget) =>
                widget is HomeNavigationTile &&
                widget.title == 'Following Topics',
          ),
    matching: find.byType(Badge),
  );

  for (final c in [
    (name: 'mobile', mobile: true),
    (name: 'desktop', mobile: false),
  ]) {
    testWidgets(
      '${c.name} NEW badges cover all profiles and clear after reading all topics',
      (tester) async {
        initialize();
        await harness.seed([
          topicFixture(),
          topicFixture(
            id: 'dogs',
            query: 'dog',
            name: 'Dogs',
            position: 1,
            unreadCount: 5,
          ),
          topicFixture(
            id: 'other',
            profileId: '00000000-0000-4000-8000-000000000063',
            unreadCount: 90,
          ),
        ]);
        await harness.pump(
          tester,
          scaffold(c.mobile ? mobileMenu() : desktopMenu()),
        );
        expect(pinnedBadge(c.mobile), findsOneWidget);
        expect(find.text('8'), findsNothing);
        expect(find.text('90'), findsNothing);
        await harness.container
            .read(followingTopicsProvider.notifier)
            .markRead('cats');
        await settle(tester);
        expect(pinnedBadge(c.mobile), findsOneWidget);
        harness.container
            .read(selectedTestProfileProvider.notifier)
            .select(otherTestProfile);
        await settle(tester);
        expect(pinnedBadge(c.mobile), findsOneWidget);
        await harness.container
            .read(followingTopicsProvider.notifier)
            .markRead('other');
        await settle(tester);
        expect(pinnedBadge(c.mobile), findsOneWidget);
        harness.container
            .read(selectedTestProfileProvider.notifier)
            .select(testProfile);
        await settle(tester);
        expect(pinnedBadge(c.mobile), findsOneWidget);
        await harness.container
            .read(followingTopicsProvider.notifier)
            .markRead('dogs');
        await settle(tester);
        expect(pinnedBadge(c.mobile), findsNothing);
        expect(find.text('Following Topics'), findsOneWidget);
      },
    );
  }

  for (final c in [
    (width: 62.0, selected: false),
    (width: 63.0, selected: true),
    (width: 70.0, selected: false),
    (width: 100.0, selected: true),
    (width: 160.0, selected: false),
    (width: 220.0, selected: true),
  ]) {
    testWidgets(
      'desktop NEW badge at ${c.width.toInt()} pixels with selection ${c.selected} stays inside its tile',
      (tester) async {
        initialize();
        await harness.seed([topicFixture(unreadCount: 1234)]);
        await harness.pump(tester, scaffold(desktopMenu(width: c.width)));
        final tile = find.byWidgetPredicate(
          (widget) =>
              widget is HomeNavigationTile &&
              widget.title == 'Following Topics',
        );
        if (c.selected) {
          await tester.tap(tile);
          await settle(tester);
        }
        final badge = find.descendant(of: tile, matching: find.byType(Badge));
        expect(badge, findsOneWidget);
        expect(find.text('1234'), findsNothing);
        final tileBounds = tester.getRect(tile);
        final badgeBounds = tester.getRect(badge);
        expect(badgeBounds.width, greaterThan(0));
        expect(badgeBounds.left, greaterThanOrEqualTo(tileBounds.left));
        expect(badgeBounds.right, lessThanOrEqualTo(tileBounds.right));
        await harness.container
            .read(followingTopicsProvider.notifier)
            .markRead('cats');
        await settle(tester);
        expect(find.byType(Badge), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final c in [
    (name: 'default', key: null),
    (name: 'explicit default', key: const CustomHomeViewKey.defaultValue()),
    (name: 'alternate', key: const CustomHomeViewKey('bookmark')),
  ]) {
    testWidgets(
      '${c.name} desktop tiles select their matching pages after the insertion',
      (tester) async {
        initialize();
        await harness.pump(tester, scaffold(desktopMenu(viewKey: c.key)));
        final views = [
          const SizedBox.shrink(),
          const SizedBox.shrink(),
          const SizedBox.shrink(),
          ...coreDesktopViewBuilder(previousItemCount: 3, viewKey: c.key),
        ];
        final cases = [
          if (c.name == 'alternate') (title: 'Search', page: SearchPage),
          (title: 'Your Bookmarks', page: BookmarkGroupBrowserPage),
          (title: 'Following Topics', page: FollowingTopicsPage),
          (title: 'Your Blacklist', page: BlacklistedTagPage),
          (title: 'Favorite Tags', page: FavoriteTagsPage),
          (title: 'Bulk Download', page: BulkDownloadPage),
          (title: 'Download Manager', page: DownloadManagerGatewayPage),
        ];
        for (final entry in cases) {
          final tile = tester
              .widgetList<HomeNavigationTile>(find.byType(HomeNavigationTile))
              .singleWhere(
                (tile) => tile.title.toLowerCase() == entry.title.toLowerCase(),
              );
          await tester.tap(find.text(tile.title));
          await settle(tester);
          expect(
            views[controller.value].runtimeType,
            entry.page,
            reason: entry.title,
          );
        }
      },
    );
  }

  testWidgets('mobile navigation opens the registered following-topic page', (
    tester,
  ) async {
    initialize();
    final registeredHome = harness.container.read(
      Provider((ref) => Routes.home(ref)),
    );
    expect(
      registeredHome.routes.whereType<GoRoute>().any(
        (route) =>
            route.path == 'following-topics' &&
            route.name == '/following-topics',
      ),
      isTrue,
    );
    harness.router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => scaffold(mobileMenu()),
          routes: [followingTopicRoutes],
        ),
      ],
    );
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(
      harness.wrap(
        MaterialApp.router(routerConfig: harness.router, builder: themeBuilder),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Following Topics'));
    await settle(tester);
    expect(find.byType(FollowingTopicsPage), findsOneWidget);
    expect(find.text('No topics yet'), findsOneWidget);
  });
  for (final legacyPath in ['/pinned-searches', '/following-feeds']) {
    testWidgets('legacy deep link $legacyPath redirects to Following Topics', (
      tester,
    ) async {
      await tester.runAsync(() async {
        initialize();
      });
      harness.router = GoRouter(
        initialLocation: legacyPath,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(),
            routes: [
              followingTopicRoutes,
              ...legacyFollowingTopicRoutes,
            ],
          ),
        ],
      );
      addTearDown(harness.router.dispose);
      await tester.runAsync(
        () => harness.container.read(followingTopicsProvider.future),
      );
      await tester.pumpWidget(
        harness.wrap(
          MaterialApp.router(
            routerConfig: harness.router,
            builder: themeBuilder,
          ),
        ),
      );
      await drain(tester);
      await tester.pumpAndSettle();
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        '/following-topics',
      );
      expect(find.byType(FollowingTopicsPage), findsOneWidget);
    });
  }
}
