import 'dart:async';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/create/src/widgets/create_booru_config_name_field.dart';
import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_definition.dart';
import 'package:boorusama/core/navigation/navigation_catalog_provider.dart';
import 'package:boorusama/core/navigation/navigation_controller.dart';
import 'package:boorusama/core/navigation/navigation_destination_pages.dart';
import 'package:boorusama/core/navigation/profile_management_page.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/settings/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../../application/support/app_flow_driver.dart';
import '../../application/support/application_test_store.dart';
import '../../application/support/fake_booru_backend.dart';
import '../../application/support/headless_app_harness.dart';

void main() {
  testWidgets(
    'Favorites recovery opens the retained Settings category and duplication keeps explicit IDs',
    (tester) async {
      final backend = FakeBooruBackend();
      final store = ApplicationTestStore.withProfiles(
        backend.config,
        additional: [backend.configB],
      );
      final harness = await store.mount(
        tester,
        backend: backend,
        viewportSize: kMobileViewport,
      );
      await harness.settle(tester);
      final ref = tester.element(find.byType(AppNavigationShell)) as WidgetRef;
      final controller = ref.read(navigationControllerProvider.notifier);
      await controller.selectDestination(
        const DestinationId.app(AppDestination.settings),
      );
      await harness.settle(tester);
      await tester.tap(
        find.byKey(const ValueKey('settings-navigation-privacy')),
      );
      await harness.settle(tester);
      await controller.selectDestination(
        const DestinationId.app(AppDestination.favoritesRecovery),
      );
      await harness.settle(tester);
      expect(find.byType(NavigationRecoveryPage), findsOneWidget);
      await tester.tap(find.text('Profiles'));
      await harness.settle(tester);
      expect(find.byType(ProfileManagementPage), findsOneWidget);
      expect(
        controller.binding!.currentDestination,
        const DestinationId.app(AppDestination.settings),
      );
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openProfileMenu(backend.configB);
      await tester.tap(find.text('Duplicate'));
      await harness.pumpUntil(tester, () => store.configs.length == 3);
      await harness.settle(tester);
      final copy = store.configs.singleWhere(
        (p) => p.id != backend.config.id && p.id != backend.configB.id,
      );
      expect(copy.name, '${backend.configB.name} copy');
      expect(copy.url, backend.configB.url);
      expect(
        ref.read(navigationControllerProvider).lastBrowseProfileId,
        backend.config.id,
      );
      expect(find.byKey(ValueKey(copy.id)), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final count in [0, 1, 3]) {
    testWidgets('Settings offers an explicit list with $count profiles', (
      tester,
    ) async {
      final backend = FakeBooruBackend();
      final profiles = [
        backend.config,
        backend.configB,
        BooruConfig.fromJson({
          ...backend.config.toJson(),
          'id': '00000000-0000-4000-8000-000000000003',
          'name': 'Account C',
        }),
      ].take(count).toList();
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        viewportSize: kMobileViewport,
        runtime: backend.createRuntime(
          configs: profiles,
          initialConfig: profiles.firstOrNull ?? BooruConfig.empty,
        ),
      );
      await harness.settle(tester);
      final ref = tester.element(find.byType(AppNavigationShell)) as WidgetRef;
      final catalog = ref.read(navigationCatalogProvider);
      expect(
        catalog.globalEntries.map((e) => e.destination),
        isNot(contains(AppDestination.profiles)),
      );
      await ref
          .read(navigationControllerProvider.notifier)
          .selectDestination(const DestinationId.app(AppDestination.settings));
      await harness.settle(tester);
      expect(find.text('Edit Current Profile'), findsNothing);
      expect(find.text('BOORU SETTINGS'), findsNothing);
      final entry = find.byKey(const ValueKey('settings-navigation-profiles'));
      expect(entry, findsOneWidget);
      await tester.tap(entry);
      await harness.settle(tester);
      expect(find.byType(ProfileManagementPage), findsOneWidget);
      expect(find.byType(BooruConfigNameField), findsNothing);
      expect(find.text('Add'), findsOneWidget);
      for (final p in profiles) {
        expect(find.byKey(ValueKey(p.id)), findsOneWidget);
      }
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      expect(find.byType(ProfileManagementPage), findsNothing);
      expect(entry, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'editing B preserves Browse A and Favorites C and returns to Settings',
    (tester) async {
      final backend = FakeBooruBackend();
      final c = BooruConfig.fromJson({
        ...backend.config.toJson(),
        'id': '00000000-0000-4000-8000-000000000003',
        'name': 'Account C',
      });
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        viewportSize: kMobileViewport,
        runtime: backend.createRuntime(
          configs: [backend.config, backend.configB, c],
        ),
        additionalOverrides: [
          navigationCapabilitiesProvider.overrideWithValue([
            for (final p in [backend.config, backend.configB, c])
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
      await harness.settle(tester);
      final ref = tester.element(find.byType(AppNavigationShell)) as WidgetRef;
      final controller = ref.read(navigationControllerProvider.notifier);
      await controller.selectFavoritesProfile(c.id, [c.id]);
      await harness.settle(tester);
      await controller.selectDestination(
        const DestinationId.app(AppDestination.settings),
      );
      await harness.settle(tester);
      await tester.tap(
        find.byKey(const ValueKey('settings-navigation-profiles')),
      );
      await harness.settle(tester);
      await tester.tap(find.text(backend.configB.name));
      await harness.pumpUntilFound(tester, find.byType(BooruConfigNameField));
      await harness.settle(tester);
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(BooruConfigNameField),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, backend.configB.name);
      expect(
        ref.read(routerProvider).state.uri.path,
        contains(backend.configB.id),
      );
      expect(
        ref.read(navigationControllerProvider).lastBrowseProfileId,
        backend.config.id,
      );
      expect(
        ref.read(navigationControllerProvider).lastFavoritesProfileId,
        c.id,
      );
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      expect(find.byType(ProfileManagementPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      expect(find.byType(ProfileManagementPage), findsNothing);
      expect(
        find.byKey(const ValueKey('settings-navigation-profiles')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Profiles deep link opens cold and retained Settings without duplicate toolbars',
    (tester) async {
      final backend = FakeBooruBackend();
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        viewportSize: const Size(1200, 850),
      );
      await harness.settle(tester);
      final ref = tester.element(find.byType(AppNavigationShell)) as WidgetRef;
      unawaited(openProfilesSettingsPage(ref));
      await harness.settle(tester);
      expect(find.byType(ProfileManagementPage), findsOneWidget);
      expect(find.text('Profiles'), findsNWidgets(2));
      expect(find.text('Add'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('settings-navigation-privacy')),
      );
      await harness.settle(tester);
      await ref
          .read(navigationControllerProvider.notifier)
          .selectBrowseProfile(backend.config.id);
      await harness.settle(tester);
      unawaited(openProfilesSettingsPage(ref));
      await harness.settle(tester);
      expect(find.byType(ProfileManagementPage), findsOneWidget);
      expect(find.byIcon(Icons.manage_accounts), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
