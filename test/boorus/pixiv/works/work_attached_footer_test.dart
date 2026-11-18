import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/explore/widgets.dart';
import 'package:boorusama/boorus/pixiv/works/work_presentation.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/widgets/native_content_grid.dart';
import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_profile_scope.dart';
import 'package:boorusama/core/navigation/destination_router.dart';
import 'package:boorusama/core/navigation/navigation_catalog.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/navigation/navigation_panel_geometry.dart';
import 'package:boorusama/core/posts/explores/widgets.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kurumi/material.dart';

import '../../../core/search/following_topics/following_topic_test_utils.dart';
import '../../../support/navigation_panel_test_utils.dart';
import 'work_test_fixtures.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('real shell keeps Ranking attached and full height at $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final config = workAccess().config!;
      final harness = FollowingTopicHarness(
        profiles: [config],
        listingSettings: Settings.defaultSettings.listing.copyWith(
          pageMode: scale == 2 ? PageMode.paginated : PageMode.infinite,
        ),
        overrides: [
          currentReadOnlyBooruConfigProvider.overrideWith((ref) => config),
          pixivClientProvider.overrideWith(
            (ref, _) => _Client(paginated: scale == 2),
          ),
          booruGroupCapabilityProvider.overrideWith(
            (ref, _) => createPixivGroupCapability(ref),
          ),
        ],
      );
      addTearDown(harness.dispose);
      final explore = DestinationId.tool(config.id, 'pixiv.explore');
      final browse = DestinationId.browse(config.id);
      late final DestinationRouterBinding binding;
      binding = DestinationRouterBinding(
        definitions: [
          DestinationRouteDefinition(
            id: explore,
            builder: (_, _) => const PixivExplorePage(),
          ),
          DestinationRouteDefinition(
            id: browse,
            builder: (_, _) => const Scaffold(body: Text('Other destination')),
          ),
        ],
        navigatorWrapper: (_, id, selected, navigator) => ProviderScope(
          overrides: [
            currentDestinationRouteObserverProvider.overrideWithValue(
              binding.observerFor(id)!,
            ),
          ],
          child: DestinationScope(
            id: id,
            active: selected,
            child: DestinationPageActivity(child: navigator),
          ),
        ),
        shellBuilder: (_, _, shell) => AppNavigationShell(
          navigationShell: shell,
          active: binding.idAt(shell.currentIndex),
          browse: browse,
          catalog: NavigationCatalog(
            profileSections: [],
            globalEntries: [],
            eligibleFavoritesProfileIds: [],
          ),
          collapsedProfiles: const {},
          onSelect: (id) async => binding.select(id),
          onFavorites: () async => false,
          onToggleProfile: (_) {},
        ),
      );
      final router = GoRouter.routingConfig(
        routingConfig: binding.routingConfig,
        initialLocation: explore.location,
      );
      binding.attach(router);
      addTearDown(binding.dispose);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        harness.wrap(
          MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => themeBuilder(
              context,
              MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                  viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
                ),
                child: child!,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chrome = harness.container.read(navigationChromeProvider.notifier);
      NavigationPanelGeometry geometry() =>
          NavigationPanelScope.maybeOf(tester.element(navigationPanel()))!
              .motion
              .value;
      final date = find.byType(DateTimeSelector);
      final nav = find.byKey(const ValueKey('nav-shortcut-browse'));
      final initialDate = tester.getRect(date);
      final initialNav = tester.getRect(nav);
      final total = geometry().totalExtent;
      expect(total, greaterThan(88));
      final grid = find
          .descendant(
            of: find.byType(NativeContentGrid),
            matching: find.byType(CustomScrollView),
          )
          .first;
      expect(tester.getRect(grid).bottom, 800);
      void attached() {
        final currentDate = tester.getRect(date);
        final currentNav = tester.getRect(nav);
        expect(currentDate.bottom, closeTo(currentNav.top, .01));
        expect(
          currentDate.top - initialDate.top,
          closeTo(currentNav.top - initialNav.top, .01),
        );
        expect(
          currentNav.top - initialNav.top,
          closeTo(geometry().displacement, .01),
        );
        expect(tester.getRect(grid).bottom, 800);
      }

      attached();
      chrome.userScroll(
        delta: total * .35,
        pixels: 300,
        outOfRange: false,
        extent: total,
      );
      await tester.pump();
      attached();
      chrome.endScroll(pixels: 300);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      attached();
      final beforeReverse = tester.getTopLeft(nav).dy;
      chrome.userScroll(
        delta: total,
        pixels: 500,
        outOfRange: false,
        extent: total,
      );
      await tester.pump();
      attached();
      expect(date.hitTestable(), findsNothing);
      expect(nav.hitTestable(), findsNothing);
      chrome.endScroll(pixels: 500);
      chrome.show();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      attached();
      expect(tester.getTopLeft(nav).dy, greaterThan(beforeReverse));
      await tester.pumpAndSettle();
      attached();
      await tester.tap(
        find.descendant(
          of: find.byType(PixivExplorePage),
          matching: find.text('Following'),
        ),
      );
      await tester.pumpAndSettle();
      expect(date, findsNothing);
      expect(geometry().footerExtent, 0);
      await tester.tap(find.text('Ranking'));
      await tester.pumpAndSettle();
      attached();
      await tester.tap(date);
      await tester.pumpAndSettle();
      expect(geometry().totalExtent, total);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      attached();
      binding.select(browse);
      await tester.pumpAndSettle();
      expect(geometry().footerExtent, 0);
      expect(harness.container.read(navigationFooterExtentsProvider), isEmpty);
      binding.select(explore);
      await tester.pumpAndSettle();
      attached();
      final viewport = tester
          .state<ScrollableState>(
            find.descendant(of: grid, matching: find.byType(Scrollable)).first,
          )
          .position;
      viewport.jumpTo(300);
      await tester.pumpAndSettle();
      final drag = await tester.startGesture(tester.getCenter(grid));
      await drag.moveBy(const Offset(0, -25));
      await tester.pump();
      final startPixels = viewport.pixels;
      final startNav = tester.getTopLeft(nav).dy;
      await drag.moveBy(const Offset(0, -20));
      await tester.pump();
      attached();
      expect(
        tester.getTopLeft(nav).dy - startNav,
        closeTo(viewport.pixels - startPixels, .01),
      );
      await drag.up();
      await tester.pumpAndSettle();
      chrome.show();
      await tester.pumpAndSettle();
      attached();

      chrome.userScroll(
        delta: total * .4,
        pixels: 300,
        outOfRange: false,
        extent: total,
      );
      await tester.pump();
      chrome.endScroll(pixels: 300);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final interruptPixels = viewport.pixels;
      final interruptTop = tester.getTopLeft(nav).dy;
      final interrupt = await tester.startGesture(tester.getCenter(grid));
      await interrupt.moveBy(const Offset(0, -30));
      await tester.pump();
      expect(
        tester.getTopLeft(nav).dy - interruptTop,
        closeTo(viewport.pixels - interruptPixels, .01),
        reason: 'a drag must continue from rendered progress during a snap',
      );
      await interrupt.up();
      await tester.pumpAndSettle();
      chrome.show();
      await tester.pumpAndSettle();
      attached();

      final viewer = Object();
      chrome.setViewerFor(
        viewer,
        active: true,
        immersive: false,
        routeProgress: 0,
      );
      for (final progress in [0.25, 0.75, 1.0]) {
        chrome.setViewerProgressFor(viewer, progress);
        await tester.pump();
        attached();
      }
      chrome.setViewerFor(
        viewer,
        active: true,
        immersive: false,
        closing: true,
      );
      for (final progress in [.5, .25, 0.0]) {
        chrome.setViewerProgressFor(viewer, progress);
        await tester.pump();
        attached();
      }
      chrome.setViewerFor(viewer, active: false, immersive: false);
      await tester.pumpAndSettle();
      attached();
      chrome.setSelection(true);
      await tester.pump();
      expect(date.hitTestable(), findsNothing);
      chrome.setSelection(false);
      await tester.pumpAndSettle();
      attached();
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      expect(date.hitTestable(), findsNothing);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      attached();

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      chrome.userScroll(
        delta: total * .8,
        pixels: 500,
        outOfRange: false,
        extent: total,
      );
      chrome.endScroll(pixels: 500);
      await tester.pump();
      expect(geometry().hiddenFraction, 1);
      chrome.show();
      await tester.pump();
      expect(geometry().hiddenFraction, 0);
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pumpAndSettle();
      final gridController = NativeContentGrid.controllerOf(
        tester.element(grid),
      );
      viewport.jumpTo(viewport.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('Work 159').hitTestable(), findsOneWidget);
      expect(
        tester.getRect(find.text('Work 159')).bottom,
        lessThanOrEqualTo(tester.getRect(date).top),
      );
      if (scale == 2) {
        final next = find.byIcon(Icons.chevron_right);
        expect(next.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(next).bottom,
          lessThanOrEqualTo(tester.getRect(date).top),
        );
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(gridController.page, 2);
      }
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();
      expect(nav, findsNothing);
      expect(date.hitTestable(), findsOneWidget);
      expect(harness.container.read(navigationFooterExtentsProvider), isEmpty);
      expect(
        NativeContentGrid.controllerOf(
          tester.element(grid),
        ),
        same(gridController),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}

class _Client extends PixivClient {
  _Client({required this.paginated}) : super(accessToken: 'fixture');
  final bool paginated;
  PixivIllustListResult result(int page) => PixivIllustListResult(
    hasMore: paginated && page == 1,
    illusts: [for (var i = 0; i < 40; i++) work(id: 120 + (page - 1) * 40 + i)],
  );
  @override
  Future<PixivIllustListResult> getRanking({
    PixivRankingMode mode = PixivRankingMode.day,
    DateTime? date,
    int page = 1,
  }) async => result(page);
  @override
  Future<PixivIllustListResult> getFollowedIllusts({
    PixivFollowRestrict restrict = PixivFollowRestrict.all,
    int page = 1,
  }) async => result(page);
  @override
  Future<PixivIllustListResult> getRecommendedIllusts({int page = 1}) async =>
      result(page);
}
