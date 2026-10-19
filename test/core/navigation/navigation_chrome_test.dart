import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_navigation_icon.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_router.dart';
import 'package:boorusama/core/navigation/navigation_catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));
  for (final width in [320.0, 390.0, 768.0, 1280.0]) {
    testWidgets('shell keeps menu and primary controls independent at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const browse = DestinationId.browse('a');
      const following = DestinationId.app(AppDestination.following);
      const bookmarks = DestinationId.app(AppDestination.bookmarks);
      late final DestinationRouterBinding binding;
      binding = DestinationRouterBinding(
        definitions: [
          for (final id in [browse, following, bookmarks])
            DestinationRouteDefinition(
              id: id,
              builder: (_, _) => Scaffold(body: Text(id.toStorageKey())),
            ),
        ],
        shellBuilder: (_, _, shell) => AppNavigationShell(
          navigationShell: shell,
          hasNewFollowingPosts: true,
          active: binding.idAt(shell.currentIndex),
          catalog: NavigationCatalog(
            profileSections: [],
            globalEntries: [],
            eligibleFavoritesProfileIds: [],
          ),
          browse: browse,
          collapsedProfiles: const {},
          onSelect: (id) async => binding.select(id),
          onFavorites: () async => false,
          onToggleProfile: (_) {},
        ),
      );
      final router = GoRouter.routingConfig(
        routingConfig: binding.routingConfig,
        initialLocation: browse.location,
      );
      binding.attach(router);
      addTearDown(router.dispose);
      addTearDown(binding.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWithValue(Settings.defaultSettings),
          ],
          child: BooruLocalization(
            child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  padding: const EdgeInsets.only(bottom: 24),
                  viewPadding: const EdgeInsets.only(bottom: 24),
                ),
                child: child!,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (width < 1000) {
        final location = router.routeInformationProvider.value.uri;
        await tester.tap(find.byKey(const Key('nav-menu-toggle')));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri, location);
        final scrim = tester.getRect(find.byType(DrawerController));
        final shortcut = tester.getRect(
          find.byKey(const Key('nav-shortcut-following')),
        );
        expect(scrim.bottom, lessThanOrEqualTo(shortcut.top));
        await tester.tap(find.byKey(const Key('nav-shortcut-following')));
        await tester.pumpAndSettle();
        expect(binding.currentDestination, following);
        expect(
          ProviderScope.containerOf(
            tester.element(find.byType(AppNavigationShell)),
          ).read(navigationChromeProvider).menuOpen,
          isFalse,
        );
      } else {
        expect(find.byKey(const Key('nav-menu-toggle')), findsNothing);
        await tester.tap(
          find.byKey(ValueKey('nav-destination:${following.toStorageKey()}')),
        );
        await tester.pumpAndSettle();
        expect(binding.currentDestination, following);
      }
      expect(find.byType(Badge), findsOneWidget);
      expect(
        tester
            .widget<FollowingTopicNavigationIcon>(
              find.byType(FollowingTopicNavigationIcon),
            )
            .hasNewPosts,
        isTrue,
      );
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(AppNavigationShell)),
      );
      final chrome = scope.read(navigationChromeProvider.notifier);
      final owner = Object();
      for (final hiddenByScroll in [false, true]) {
        chrome.show();
        if (hiddenByScroll)
          chrome.userScroll(delta: 30, pixels: 100, outOfRange: false);
        await tester.pumpAndSettle();
        chrome.setViewerFor(owner, active: true, immersive: false);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('nav-shortcut-browse')), findsNothing);
        final pageContext = tester.element(find.text(following.toStorageKey()));
        expect(MediaQuery.paddingOf(pageContext).bottom, 24);
        expect(MediaQuery.viewPaddingOf(pageContext).bottom, 24);
        chrome.setViewerFor(owner, active: false, immersive: false);
        await tester.pumpAndSettle();
        expect(
          MediaQuery.paddingOf(pageContext).bottom,
          width < 1000 ? 88 : 24,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
