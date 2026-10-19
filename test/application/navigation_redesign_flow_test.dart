import 'dart:async';

import 'package:boorusama/core/download_manager/src/pages/download_manager_page.dart';

import 'package:boorusama/core/search/search/src/widgets/search_context_profile_picker.dart';
import 'package:boorusama/core/navigation/profile_context_menu.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';

import 'package:boorusama/core/navigation/navigation_catalog_provider.dart';
import 'package:boorusama/core/navigation/destination_definition.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/navigation/navigation_destination_pages.dart';
import 'package:boorusama/core/settings/src/pages/settings_page.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/search/following_topics/widgets.dart';
import 'package:boorusama/core/search/search/widgets.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/navigation/navigation_controller.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/router.dart';

import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets(
    'real app retains Browse grids across profiles and primary destinations',
    (tester) async {
      final backend = FakeBooruBackend();
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        viewportSize: kMobileViewport,
        runtime: backend.createRuntime(
          configs: [backend.config, backend.configB],
        ),
      );
      await harness.pumpUntilFound(
        tester,
        find.byType(SliverPostGridImageGridItem),
      );
      expect(find.byType(AppNavigationShell), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppNavigationShell)),
      );
      final controller = container.read(navigationControllerProvider.notifier);
      final router = container.read(routerProvider);
      final gridA = tester.state(find.byType(PostGrid).first);
      expect(await controller.selectBrowseProfile(backend.configB.id), isTrue);
      await harness.pumpUntil(
        tester,
        () => backend.requests.whereType<FakeBooruPostRequest>().any(
          (r) => r.siteUrl == backend.configB.url,
        ),
      );
      await harness.settle(tester);
      expect(tester.state(find.byType(PostGrid).first), isNot(same(gridA)));
      await tester.tap(find.byKey(const ValueKey('nav-shortcut-following')));
      await harness.settle(tester);
      expect(
        router.routeInformationProvider.value.uri.path,
        DestinationId.app(AppDestination.following).location,
      );
      await controller.selectBrowseProfile(backend.config.id);
      await harness.settle(tester);
      expect(tester.state(find.byType(PostGrid).first), same(gridA));
      await tester.tap(find.byType(SliverPostGridImageGridItem).first);
      await harness.pumpUntilFound(
        tester,
        find.byType(PostDetailsPageScaffold),
      );
      await harness.settle(tester);
      expect(
        await harness.pumpUntilComplete(
          tester,
          controller.selectDestination(
            const DestinationId.app(AppDestination.bookmarks),
          ),
        ),
        isTrue,
      );
      await harness.settle(tester);
      expect(find.byType(PostDetailsPageScaffold), findsNothing);
      await controller.selectBrowseProfile(backend.config.id);
      await harness.settle(tester);
      expect(tester.state(find.byType(PostGrid).first), same(gridA));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'real Favorites preserves both sessions independently of Browse',
    (tester) async {
      final backend = FakeBooruBackend();
      final profiles = [backend.config, backend.configB];
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        viewportSize: kMobileViewport,
        runtime: backend.createRuntime(configs: profiles),
        additionalOverrides: [
          navigationCapabilitiesProvider.overrideWithValue([
            for (final p in profiles)
              ProfileNavigationCapabilities(
                profileId: p.id,
                caption: p.name,
                profileIcon: p.url,
                tools: [],
                favorites: NavigationAvailability.available,
              ),
          ]),
        ],
      );
      await harness.pumpUntilFound(tester, find.byType(PostGrid));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppNavigationShell)),
      );
      final controller = container.read(navigationControllerProvider.notifier);
      final eligible = profiles.map((p) => p.id).toList();
      await controller.selectFavoritesProfile(backend.config.id, eligible);
      await harness.pumpUntil(
        tester,
        () => backend.requests.whereType<FakeBooruPostRequest>().any(
          (r) => r.query == 'fav:tester' && r.siteUrl == backend.config.url,
        ),
      );
      await harness.settle(tester);
      final first = tester.state(find.byType(PostGrid).first);
      await controller.selectFavoritesProfile(backend.configB.id, eligible);
      await harness.pumpUntil(
        tester,
        () => backend.requests.whereType<FakeBooruPostRequest>().any(
          (r) => r.query == 'fav:tester' && r.siteUrl == backend.configB.url,
        ),
      );
      await harness.settle(tester);
      expect(container.read(currentBooruConfigProvider).id, backend.config.id);
      container.read(routerProvider).go('/favorites?cid=${backend.config.id}');
      await harness.settle(tester);
      expect(tester.state(find.byType(PostGrid).first), same(first));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Following contextual search retains explicit source and draft across Browse changes',
    (tester) async {
      final backend = FakeBooruBackend();
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        viewportSize: kMobileViewport,
        runtime: backend.createRuntime(
          configs: [backend.config, backend.configB],
        ),
      );
      await harness.pumpUntilFound(tester, find.byType(PostGrid));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppNavigationShell)),
      );
      final controller = container.read(navigationControllerProvider.notifier);
      await controller.selectDestination(
        const DestinationId.app(AppDestination.following),
      );
      await harness.settle(tester);
      final pageRef =
          tester.element(find.byType(FollowingTopicsPage)) as WidgetRef;
      unawaited(
        goToSearchPage(
          pageRef,
          config: backend.configB,
          tag: 'cityscape',
          originatingTopicId: 'topic-b',
        ),
      );
      await harness.pumpUntilFound(tester, find.byType(SearchPage));
      await harness.settle(tester);
      expect(find.byType(ProfileContextMenuButton), findsOneWidget);
      final search = tester.state(find.byType(SearchPage));
      final location = container.read(routerProvider).state.uri;
      expect(location.queryParameters['_profile'], backend.configB.id);
      expect(
        backend.requests.whereType<FakeBooruPostRequest>().any(
          (r) => r.query == 'cityscape' && r.siteUrl == backend.configB.url,
        ),
        isTrue,
      );
      expect(
        (tester.element(
          find.byType(SearchContextProfilePicker),
        ) as WidgetRef).readConfig.id,
        backend.configB.id,
      );
      await controller.selectBrowseProfile(backend.config.id);
      await harness.settle(tester);
      await controller.selectDestination(
        const DestinationId.app(AppDestination.following),
      );
      await harness.settle(tester);
      expect(tester.state(find.byType(SearchPage)), same(search));
      expect(container.read(routerProvider).state.uri, location);
      expect(
        (tester.element(
          find.byType(SearchContextProfilePicker),
        ) as WidgetRef).readConfig.id,
        backend.configB.id,
      );
      await controller.selectBrowseProfile(backend.configB.id);
      await harness.settle(tester);
      await controller.selectDestination(
        const DestinationId.app(AppDestination.following),
      );
      await harness.settle(tester);
      await tester.tap(find.byType(ProfileContextMenuButton));
      await harness.settle(tester);
      await tester.tap(find.text(backend.config.name));
      await harness.settle(tester);
      expect(
        (tester.element(
          find.byType(SearchContextProfilePicker),
        ) as WidgetRef).readConfig.id,
        backend.config.id,
      );
      expect(container.read(currentBooruConfigProvider).id, backend.configB.id);
      expect(
        container.read(navigationControllerProvider).lastFavoritesProfileId,
        isNull,
      );
      expect(
        controller.binding!.currentDestination,
        const DestinationId.app(AppDestination.following),
      );
      expect(
        backend.requests.whereType<FakeBooruPostRequest>().any(
          (r) => r.siteUrl == backend.config.url && r.query == 'cityscape',
        ),
        isTrue,
      );
      await controller.selectBrowseProfile(backend.configB.id);
      await harness.settle(tester);
      await controller.selectDestination(
        const DestinationId.app(AppDestination.following),
      );
      await harness.settle(tester);
      expect(
        (tester.element(
          find.byType(SearchContextProfilePicker),
        ) as WidgetRef).readConfig.id,
        backend.config.id,
      );
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      expect(find.byType(FollowingTopicsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'zero-profile startup retains local organization and management',
    (tester) async {
      final backend = FakeBooruBackend();
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        runtime: backend.createRuntime(
          configs: [],
          initialConfig: BooruConfig.empty,
        ),
      );
      await harness.pumpUntilFound(tester, find.byType(NavigationRecoveryPage));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppNavigationShell)),
      );
      final controller = container.read(navigationControllerProvider.notifier);
      for (final destination in [
        AppDestination.bookmarks,
        AppDestination.following,
        AppDestination.profiles,
        AppDestination.backups,
        AppDestination.settings,
      ]) {
        expect(
          await controller.selectDestination(DestinationId.app(destination)),
          isTrue,
        );
        await harness.settle(tester);
        expect(tester.takeException(), isNull, reason: destination.name);
      }
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(backend.requests.whereType<FakeBooruPostRequest>(), isEmpty);
      container
          .read(routerProvider)
          .go('/download_manager?filter=failed&group=review');
      await harness.pumpUntilFound(
        tester,
        find.byType(DownloadManagerGatewayPage),
      );
      final downloads = tester.widget<DownloadManagerGatewayPage>(
        find.byType(DownloadManagerGatewayPage),
      );
      expect(downloads.filter, 'failed');
      expect(downloads.group, 'review');
      final router = container.read(routerProvider);
      final following = const DestinationId.app(AppDestination.following);
      router.go('${following.location}/search?_profile=missing-profile');
      await harness.settle(tester);
      expect(find.byType(SearchPage), findsNothing);
      expect(
        find.text('This profile is unavailable. Choose a profile to continue.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('Back closes Menu, then local child, then returns to Browse', (
    tester,
  ) async {
    final backend = FakeBooruBackend();
    final harness = await HeadlessAppHarness.mount(
      tester,
      booruBackend: backend,
    );
    await harness.pumpUntilFound(tester, find.byType(PostGrid));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppNavigationShell)),
    );
    final controller = container.read(navigationControllerProvider.notifier);
    await controller.selectDestination(
      const DestinationId.app(AppDestination.following),
    );
    await harness.settle(tester);
    final pageRef =
        tester.element(find.byType(FollowingTopicsPage)) as WidgetRef;
    unawaited(goToSearchPage(pageRef, config: backend.config, tag: 'cat'));
    await harness.pumpUntilFound(tester, find.byType(SearchPage));
    await harness.settle(tester);
    await tester.tap(find.byKey(const ValueKey('nav-menu-toggle')));
    await harness.settle(tester);
    await tester.binding.handlePopRoute();
    await harness.settle(tester);
    expect(container.read(navigationChromeProvider).menuOpen, isFalse);
    expect(find.byType(SearchPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await harness.settle(tester);
    expect(find.byType(SearchPage), findsNothing);
    expect(find.byType(FollowingTopicsPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await harness.settle(tester);
    expect(
      controller.binding!.currentDestination,
      DestinationId.browse(backend.config.id),
    );
    expect(tester.takeException(), isNull);
  });
}
