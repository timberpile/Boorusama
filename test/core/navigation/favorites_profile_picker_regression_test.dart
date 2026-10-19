import 'package:boorusama/boorus/danbooru/posts/favorites/src/favorites_page.dart';
import 'package:boorusama/boorus/gelbooru/favorites/widgets.dart';
import 'package:boorusama/core/boorus/defaults/widgets.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:flutter/services.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/navigation/destination_definition.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/navigation_catalog_provider.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/navigation/navigation_controller.dart';
import 'package:boorusama/core/navigation/profile_context_menu.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/search/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../application/support/fake_booru_backend.dart';
import '../../application/support/headless_app_harness.dart';
import '../../support/boorusama_test_runtime.dart';

// Only the engine's page factory is substituted. Both production Favorites
// pages, destination scopes, repositories, picker and navigation remain real.
class _FavoritesBuilder extends BaseBooruBuilder {
  _FavoritesBuilder(this.danbooru);
  final bool danbooru;
  @override
  FavoritesPageBuilder get favoritesPageBuilder =>
      (_) => danbooru
      ? const DanbooruFavoritesPageInternal(username: 'tester')
      : const GelbooruFavoritesPageInternal(uid: 'tester');
}

void main() {
  for (final danbooru in [true, false]) {
    testWidgets(
      '${danbooru ? 'Danbooru' : 'Gelbooru'} real Favorites has one logo after Search and independent retained accounts',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final backend = FakeBooruBackend();
        final unavailable = BooruConfig.fromJson({
          ...backend.config.toJson(),
          'id': '00000000-0000-4000-8000-000000000003',
          'name': 'Unavailable',
        });
        final profiles = [backend.config, backend.configB, unavailable];
        final eligibility = StateProvider(
          (_) => [backend.config.id, backend.configB.id],
        );
        final harness = await HeadlessAppHarness.mount(
          tester,
          booruBackend: backend,
          viewportSize: const Size(320, 700),
          runtime: backend.createRuntime(
            configs: profiles,
            booruConfigRepository: MemoryBooruConfigRepository(
              configs: profiles,
            ),
          ),
          additionalOverrides: [
            booruBuilderProvider.overrideWith(
              (_, _) => _FavoritesBuilder(danbooru),
            ),
            navigationCapabilitiesProvider.overrideWith(
              (ref) => [
                for (final p in ref.watch(booruConfigProvider))
                  ProfileNavigationCapabilities(
                    profileId: p.id,
                    caption: p.name,
                    profileIcon: p.url,
                    tools: [],
                    favorites: ref.watch(eligibility).contains(p.id)
                        ? NavigationAvailability.available
                        : NavigationAvailability.requiresAccount,
                  ),
              ],
            ),
          ],
        );
        await harness.pumpUntilFound(tester, find.byType(PostGrid));
        await harness.settle(tester);
        final ref =
            tester.element(find.byType(AppNavigationShell)) as WidgetRef;
        final controller = ref.read(navigationControllerProvider.notifier);
        await controller.selectFavoritesProfile(
          backend.config.id,
          ref.read(eligibility),
        );
        await harness.settle(tester);
        expect(
          find.byType(
            danbooru
                ? DanbooruFavoritesPageInternal
                : GelbooruFavoritesPageInternal,
          ),
          findsOneWidget,
        );
        expect(find.byType(ProfileContextMenuButton), findsOneWidget);
        expect(find.byIcon(Symbols.search), findsOneWidget);
        expect(
          tester.getCenter(find.byType(ProfileContextMenuButton)).dx,
          greaterThan(tester.getCenter(find.byIcon(Symbols.search)).dx),
        );
        final firstGrid = tester.state(find.byType(PostGrid));
        await tester.tap(find.byType(ProfileContextMenuButton));
        await harness.settle(tester);
        expect(find.text(backend.config.name), findsOneWidget);
        expect(find.text(backend.configB.name), findsOneWidget);
        expect(find.byIcon(Icons.check), findsOneWidget);
        expect(find.text(unavailable.name), findsNothing);
        final menu = tester.getRect(find.byType(SingleChildScrollView));
        expect(menu.left, greaterThanOrEqualTo(12));
        expect(menu.right, lessThanOrEqualTo(308));
        await tester.tap(find.text(backend.configB.name));
        await harness.settle(tester);
        final secondGrid = tester.state(find.byType(PostGrid));
        expect(secondGrid, isNot(same(firstGrid)));
        expect(ref.read(currentBooruConfigProvider).id, backend.config.id);
        expect(
          ref.read(navigationControllerProvider).lastFavoritesProfileId,
          backend.configB.id,
        );
        await tester.tap(find.byIcon(Symbols.search));
        await harness.pumpUntilFound(tester, find.byType(SearchPage));
        await harness.settle(tester);
        final searchRef = tester.element(find.byType(SearchPage)) as WidgetRef;
        expect(searchRef.readConfig.id, backend.configB.id);
        expect(
          ref.read(routerProvider).state.uri.path,
          startsWith(DestinationId.favorites(backend.configB.id).location),
        );
        expect(
          backend.requests.whereType<FakeBooruPostRequest>().any(
            (r) =>
                r.siteUrl == backend.configB.url &&
                r.query == (danbooru ? 'ordfav:tester' : 'fav:tester'),
          ),
          isTrue,
        );
        await tester.binding.handlePopRoute();
        await harness.settle(tester);
        await tester.tap(find.byType(ProfileContextMenuButton));
        await harness.settle(tester);
        await tester.tap(find.text(backend.config.name));
        await harness.settle(tester);
        expect(tester.state(find.byType(PostGrid)), same(firstGrid));
        expect(
          ref.read(navigationControllerProvider).lastBrowseProfileId,
          backend.config.id,
        );
        // Keep the popup open while an account loses eligibility. A stale row
        // must never send the operation to another destination/account.
        await tester.tap(find.byType(ProfileContextMenuButton));
        await harness.settle(tester);
        final pendingSelection = tester
            .widget<ProfileContextMenuButton>(
              find.byType(ProfileContextMenuButton),
            )
            .onSelected;
        ref.read(eligibility.notifier).state = [backend.config.id];
        await harness.settle(tester);
        // A tap already queued by the popup still carries its old callback.
        pendingSelection(backend.configB.id);
        await harness.settle(tester);
        final stale = find.text(backend.configB.name);
        if (stale.evaluate().isNotEmpty) {
          await tester.tap(stale);
          await harness.settle(tester);
        } else {
          await tester.tapAt(const Offset(5, 500));
          await harness.settle(tester);
        }
        expect(
          controller.binding!.currentDestination,
          DestinationId.favorites(backend.config.id),
        );
        expect(ref.read(currentBooruConfigProvider).id, backend.config.id);
        expect(find.byType(ProfileContextMenuButton), findsOneWidget);
        ref.read(eligibility.notifier).state = [
          backend.config.id,
          backend.configB.id,
        ];
        await harness.settle(tester);
        await tester.tap(find.byType(ProfileContextMenuButton));
        await harness.settle(tester);
        final removedSelection = tester
            .widget<ProfileContextMenuButton>(
              find.byType(ProfileContextMenuButton),
            )
            .onSelected;
        ref.read(navigationChromeProvider.notifier).setSelection(true);
        await harness.settle(tester);
        removedSelection(backend.configB.id);
        await harness.settle(tester);
        expect(
          controller.binding!.currentDestination,
          DestinationId.favorites(backend.config.id),
        );
        ref.read(navigationChromeProvider.notifier).setSelection(false);
        await harness.settle(tester);
        await harness.pumpUntilComplete(
          tester,
          ref.read(booruConfigProvider.notifier).delete(backend.configB),
        );
        removedSelection(backend.configB.id);
        await harness.settle(tester);
        expect(
          controller.binding!.currentDestination,
          DestinationId.favorites(backend.config.id),
        );
        expect(
          ref
              .read(navigationProfilesProvider)
              .any((p) => p.id == backend.configB.id),
          isFalse,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await harness.settle(tester);
        // One eligible account still identifies its owner; selection blocks it.
        ref.read(navigationChromeProvider.notifier).setSelection(true);
        await harness.settle(tester);
        await tester.tap(
          find.byType(ProfileContextMenuButton),
          warnIfMissed: false,
        );
        await harness.settle(tester);
        expect(find.text(backend.config.name), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
