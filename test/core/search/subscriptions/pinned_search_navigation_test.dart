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
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/routes.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/pinned_searches_page.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/tags/favorites/widgets.dart';
import 'package:boorusama/foundation/boot/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pinned_search_test_utils.dart';

void main() {
  late PinnedSearchHarness harness;
  late HomePageController controller;

  void initialize() {
    harness = PinnedSearchHarness();
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

  for (final c in [
    (name: 'mobile', mobile: true),
    (name: 'desktop', mobile: false),
  ]) {
    testWidgets(
      '${c.name} NEW badges follow the profile and clear after reading all its pins',
      (tester) async {
        initialize();
        await harness.seed([
          pinnedFixture(),
          pinnedFixture(
            id: 'dogs',
            query: 'dog',
            name: 'Dogs',
            position: 1,
            unreadCount: 5,
          ),
          pinnedFixture(id: 'other', profileId: 99, unreadCount: 90),
        ]);
        await harness.pump(
          tester,
          scaffold(c.mobile ? mobileMenu() : desktopMenu()),
        );
        expect(find.byType(Badge), findsOneWidget);
        expect(find.text('8'), findsNothing);
        expect(find.text('90'), findsNothing);
        await harness.container
            .read(searchSubscriptionsProvider.notifier)
            .markRead('cats');
        await settle(tester);
        expect(find.byType(Badge), findsOneWidget);
        harness.container
            .read(selectedTestProfileProvider.notifier)
            .select(otherTestProfile);
        await settle(tester);
        expect(find.byType(Badge), findsOneWidget);
        await harness.container
            .read(searchSubscriptionsProvider.notifier)
            .markRead('other');
        await settle(tester);
        expect(find.byType(Badge), findsNothing);
        harness.container
            .read(selectedTestProfileProvider.notifier)
            .select(testProfile);
        await settle(tester);
        expect(find.byType(Badge), findsOneWidget);
        await harness.container
            .read(searchSubscriptionsProvider.notifier)
            .markRead('dogs');
        await settle(tester);
        expect(find.byType(Badge), findsNothing);
        expect(find.text('Pinned Searches'), findsOneWidget);
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
        await harness.seed([pinnedFixture(unreadCount: 1234)]);
        await harness.pump(tester, scaffold(desktopMenu(width: c.width)));
        final tile = find.byWidgetPredicate(
          (widget) =>
              widget is HomeNavigationTile && widget.title == 'Pinned Searches',
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
            .read(searchSubscriptionsProvider.notifier)
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
          (title: 'Pinned Searches', page: PinnedSearchesPage),
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

  testWidgets('mobile navigation opens the registered pinned-search page', (
    tester,
  ) async {
    initialize();
    final registeredHome = harness.container.read(
      Provider((ref) => Routes.home(ref)),
    );
    expect(
      registeredHome.routes.whereType<GoRoute>().any(
        (route) =>
            route.path == 'pinned-searches' && route.name == '/pinned-searches',
      ),
      isTrue,
    );
    harness.router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => scaffold(mobileMenu()),
          routes: [pinnedSearchRoutes],
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
    await tester.tap(find.text('Pinned Searches'));
    await settle(tester);
    expect(find.byType(PinnedSearchesPage), findsOneWidget);
    expect(find.text('No pinned searches yet'), findsOneWidget);
  });
}
