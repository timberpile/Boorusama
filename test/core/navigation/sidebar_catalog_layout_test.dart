import 'package:boorusama/core/navigation/destination_definition.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/navigation_catalog_provider.dart';
import 'package:boorusama/core/settings/src/pages/settings_page.dart';
import 'package:boorusama/foundation/boot/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../../application/support/fake_booru_backend.dart';
import '../../application/support/headless_app_harness.dart';

Finder _destination(AppDestination id) => find.byKey(
  ValueKey('nav-destination:${DestinationId.app(id).toStorageKey()}'),
);

void main() {
  test('Donate retains its FOSS availability rule', () {
    for (final foss in [true, false]) {
      final container = ProviderContainer(
        overrides: [
          isFossBuildProvider.overrideWithValue(foss),
          navigationCapabilitiesProvider.overrideWithValue([]),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container
            .read(navigationCatalogProvider)
            .globalEntries
            .any(
              (entry) => entry.destination == AppDestination.donate,
            ),
        foss,
      );
    }
  });

  for (final width in [320.0, 390.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('catalog groups and reduced width fit $width at ${scale}x', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final backend = FakeBooruBackend();
        final harness = await HeadlessAppHarness.mount(
          tester,
          booruBackend: backend,
          viewportSize: Size(width, 800),
          runtime: backend.createRuntime(
            configs: [backend.config, backend.configB],
          ),
          additionalOverrides: [
            isFossBuildProvider.overrideWithValue(true),
            navigationCapabilitiesProvider.overrideWithValue([
              ProfileNavigationCapabilities(
                profileId: backend.config.id,
                caption: backend.config.name,
                profileIcon: backend.config.url,
                tools: [
                  SiteToolDefinition(
                    toolId: 'danbooru.explore',
                    label: (_) => 'Explore',
                    icon: Icons.explore,
                    availability: NavigationAvailability.available,
                  ),
                ],
                favorites: NavigationAvailability.available,
              ),
              ProfileNavigationCapabilities(
                profileId: backend.configB.id,
                caption: backend.configB.name,
                profileIcon: backend.configB.url,
                tools: [],
                favorites: NavigationAvailability.available,
              ),
            ]),
          ],
        );
        await harness.settle(tester);
        if (width < 1000) {
          await tester.tap(find.byKey(const Key('nav-menu-toggle')));
          await harness.settle(tester);
        }
        final list = find.byKey(const Key('nav-catalog-list'));
        expect(
          tester.getSize(list).width,
          width < 1000 ? (width - 48).clamp(240, 280) : 240,
        );
        final scrollable = find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scrollable).position;
        final ordered = [
          find.byKey(ValueKey('nav-profile-section:${backend.config.id}')),
          find.text('Explore'),
          find.byKey(const Key('nav-divider-profile-tools')),
          find.byKey(const Key('nav-shared-favorites')),
          _destination(AppDestination.blacklist),
          _destination(AppDestination.favoriteTags),
          _destination(AppDestination.bulkDownload),
          _destination(AppDestination.downloadManager),
          find.byKey(const Key('nav-divider-global-tools')),
          _destination(AppDestination.settings),
          _destination(AppDestination.support),
          _destination(AppDestination.donate),
        ];
        var previous = double.negativeInfinity;
        for (final row in ordered) {
          await tester.scrollUntilVisible(row, 100, scrollable: scrollable);
          await harness.settle(tester);
          final top = tester.getTopLeft(row).dy + position.pixels;
          expect(top, greaterThan(previous));
          previous = top;
        }
        for (final (id, label) in [
          (AppDestination.blacklist, 'Blacklist'),
          (AppDestination.favoriteTags, 'Favorite Tags'),
          (AppDestination.bulkDownload, 'Bulk Download'),
          (AppDestination.downloadManager, 'Download Manager'),
        ]) {
          await tester.scrollUntilVisible(
            _destination(id),
            -100,
            scrollable: scrollable,
          );
          expect(
            find.descendant(of: _destination(id), matching: find.text(label)),
            findsOneWidget,
          );
        }
        expect(
          find.byKey(ValueKey('nav-profile-section:${backend.configB.id}')),
          findsNothing,
        );
        await tester.scrollUntilVisible(
          _destination(AppDestination.settings),
          100,
          scrollable: scrollable,
        );
        await tester.tap(_destination(AppDestination.settings));
        await harness.settle(tester);
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('no divider or heading is emitted for absent profile tools', (
    tester,
  ) async {
    final harness = await HeadlessAppHarness.mount(
      tester,
      viewportSize: kMobileViewport,
      additionalOverrides: [
        navigationCapabilitiesProvider.overrideWithValue([]),
      ],
    );
    await harness.settle(tester);
    await tester.tap(find.byKey(const Key('nav-menu-toggle')));
    await harness.settle(tester);
    expect(find.byKey(const Key('nav-divider-profile-tools')), findsNothing);
    expect(find.byKey(const Key('nav-shared-favorites')), findsNothing);
    expect(find.byKey(const Key('nav-divider-global-tools')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
