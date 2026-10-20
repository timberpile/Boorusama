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
      if (width < 1000) {
        final slide = find.ancestor(
          of: find.byKey(const Key('nav-shortcut-browse')),
          matching: find.byType(AnimatedSlide),
        );
        double offset() => tester
            .widget<FractionalTranslation>(
              find.descendant(
                of: slide,
                matching: find.byType(FractionalTranslation),
              ),
            )
            .translation
            .dy;
        final contents = find
            .ancestor(
              of: find.byKey(const Key('nav-shortcut-browse')),
              matching: find.byType(Material),
            )
            .first;
        final originalContents = tester.widget(contents);
        chrome.userScroll(
          delta: 22,
          pixels: 100,
          outOfRange: false,
          extent: 88,
        );
        await tester.pump();
        expect(offset(), 0.25);
        expect(tester.widget(contents), same(originalContents));
        await tester.pump(const Duration(milliseconds: 80));
        expect(offset(), 0.25);
        chrome.userScroll(
          delta: -11,
          pixels: 89,
          outOfRange: false,
          extent: 88,
        );
        await tester.pump();
        expect(offset(), 0.125);
        chrome.endScroll(pixels: 89);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(offset(), allOf(greaterThan(0), lessThan(0.125)));
        await tester.pumpAndSettle();
        expect(offset(), 0);
      }
      for (final hiddenByScroll in [false, true]) {
        chrome.show();
        if (hiddenByScroll)
          chrome.userScroll(delta: 100, pixels: 100, outOfRange: false);
        await tester.pumpAndSettle();
        final bar = find.ancestor(
          of: find.byKey(const Key('nav-shortcut-browse')),
          matching: find.byType(AnimatedSlide),
        );
        final barState = width < 1000 ? tester.state(bar) : null;
        chrome.setViewerFor(owner, active: true, immersive: false);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('nav-shortcut-browse')), findsNothing);
        final pageContext = tester.element(find.text(following.toStorageKey()));
        expect(MediaQuery.paddingOf(pageContext).bottom, 24);
        expect(MediaQuery.viewPaddingOf(pageContext).bottom, 24);
        chrome.setViewerFor(
          owner,
          active: true,
          immersive: false,
          closing: true,
        );
        await tester.pump();
        if (width < 1000) {
          expect(tester.state(bar), same(barState));
          Offset translation() => tester
              .widget<FractionalTranslation>(
                find.descendant(
                  of: bar,
                  matching: find.byType(FractionalTranslation),
                ),
              )
              .translation;
          expect(
            translation(),
            hiddenByScroll ? const Offset(0, 1) : Offset.zero,
          );
        }
        // The viewer still owns layout clearance during its reverse transition.
        expect(scope.read(navigationChromeProvider).viewerOpen, isTrue);
        expect(MediaQuery.paddingOf(pageContext).bottom, 24);
        chrome.setViewerFor(owner, active: true, immersive: false);
        await tester.pump();
        expect(find.byKey(const Key('nav-shortcut-browse')), findsNothing);
        chrome.setViewerFor(owner, active: false, immersive: false);
        await tester.pump();
        await tester.pumpAndSettle();
        if (width < 1000) {
          expect(
            tester.getTopLeft(find.byKey(const Key('nav-shortcut-browse'))).dy,
            hiddenByScroll ? greaterThanOrEqualTo(800) : lessThan(800),
          );
        }
        expect(
          MediaQuery.paddingOf(pageContext).bottom,
          width < 1000 ? 88 : 24,
        );
      }
      if (width < 1000) {
        chrome.show();
        chrome.setViewerFor(owner, active: true, immersive: false);
        await tester.pumpAndSettle();
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pump();
        chrome.setViewerFor(owner, active: false, immersive: false);
        await tester.pump();
        final slide = find.ancestor(
          of: find.byKey(const Key('nav-shortcut-browse')),
          matching: find.byType(AnimatedSlide),
        );
        expect(
          tester
              .widget<FractionalTranslation>(
                find.descendant(
                  of: slide,
                  matching: find.byType(FractionalTranslation),
                ),
              )
              .translation,
          Offset.zero,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
