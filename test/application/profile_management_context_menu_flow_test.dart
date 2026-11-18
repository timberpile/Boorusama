// Flutter imports:
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:kurumi/material.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/settings/providers.dart';

// Project imports:
import 'package:boorusama/core/navigation/profile_management_page.dart';
import 'package:boorusama/core/navigation/navigation_catalog_provider.dart';

import 'support/app_flow_driver.dart';

import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/platform.dart';

import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';
import 'support/keyboard_flow_driver.dart';

void main() {
  Future<(HeadlessAppHarness, FakeBooruBackend)> mountProfiles(
    WidgetTester tester, {
    AppPlatform platform = AppPlatform.android,
    Size? viewportSize,
    double textScale = 1,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final backend = FakeBooruBackend();
    final harness = HeadlessAppHarness(
      booruBackend: backend,
      viewportSize: viewportSize,
      runtime: backend.createRuntime(
        platform: platform,
        configs: [
          backend.config,
          backend.configB,
          BooruConfig.fromJson({
            ...backend.configB.toJson(),
            'id': '00000000-0000-4000-8000-000000000099',
            'name': 'Third profile',
          }),
        ],
        settings: Settings.defaultSettings,
      ),
    );
    addTearDown(() => harness.teardown(tester));
    await harness.pump(tester);
    await harness.pumpUntilFound(
      tester,
      find.byType(SliverPostGridImageGridItem),
    );
    await harness.settle(tester);
    await AppFlowDriver(tester: tester, harness: harness).openProfiles();
    return (harness, backend);
  }

  Finder profile(String id) => find.descendant(
    of: find.byType(ProfileManagementPage),
    matching: find.byKey(ValueKey(id)),
  );

  bool menuOpen() => find.text('Duplicate').evaluate().isNotEmpty;

  Finder handle(String id) => find.descendant(
    of: profile(id),
    matching: find.byType(ReorderableDragStartListener),
  );

  /// Holds a finger on [target] long enough for a long-press.
  Future<TestGesture> holdOn(WidgetTester tester, Finder target) async {
    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    return gesture;
  }

  testWidgets('long-pressing a profile opens its menu, which stays open '
      'after letting go', (tester) async {
    final (harness, backend) = await mountProfiles(tester);

    final gesture = await holdOn(tester, profile(backend.configB.id));
    expect(menuOpen(), isTrue);

    await gesture.up();
    await harness.settle(tester);
    expect(menuOpen(), isTrue);
  });

  testWidgets('a finger wobbling slightly while held keeps the menu open', (
    tester,
  ) async {
    final (harness, backend) = await mountProfiles(tester);

    final gesture = await holdOn(tester, profile(backend.configB.id));
    await gesture.moveBy(const Offset(-6, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(menuOpen(), isTrue);

    await gesture.up();
    await harness.settle(tester);
  });

  testWidgets('tapping the profile body still opens its editor', (
    tester,
  ) async {
    final (harness, backend) = await mountProfiles(tester);
    final body = find.descendant(
      of: profile(backend.configB.id),
      matching: find.text(backend.configB.name),
    );
    final router = GoRouter.of(tester.element(body));
    await tester.tap(body);
    await harness.pumpUntil(
      tester,
      () =>
          router.routeInformationProvider.value.uri.path ==
          '/boorus/${backend.configB.id}/update',
      description: 'profile body tap to open its editor',
    );
    expect(menuOpen(), isFalse);
  });

  testWidgets(
    'narrow enlarged RTL rows keep the handle separate from the menu',
    (
      tester,
    ) async {
      final (harness, backend) = await mountProfiles(
        tester,
        viewportSize: const Size(320, 900),
        textScale: 2,
      );
      Navigator.of(tester.element(find.byType(ProfileManagementPage)))
          .push<void>(
            MaterialPageRoute(
              builder: (_) => const Directionality(
                textDirection: TextDirection.rtl,
                child: ProfileManagementPage(),
              ),
            ),
          )
          .ignore();
      await harness.settle(tester);
      final body = find.descendant(
        of: profile(backend.configB.id),
        matching: find.text(backend.configB.name),
      );
      final handleRect = tester.getRect(handle(backend.configB.id));
      expect(handleRect.size, const Size(48, 48));
      expect(handleRect.right, lessThan(tester.getRect(body).left));
      final heldHandle = await holdOn(tester, handle(backend.configB.id));
      expect(menuOpen(), isFalse);
      await heldHandle.cancel();
      await harness.settle(tester);
      final heldBody = await holdOn(tester, body);
      expect(menuOpen(), isTrue);
      await heldBody.up();
      expect(tester.takeException(), isNull);
    },
  );

  for (final cancel in [false, true]) {
    testWidgets(
      'holding the profile drag handle without moving never opens a menu (cancel=$cancel)',
      (tester) async {
        final (harness, backend) = await mountProfiles(
          tester,
          viewportSize: cancel ? const Size(320, 900) : null,
          textScale: cancel ? 2 : 1,
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProfileManagementPage)),
        );
        final originalOrder = container
            .read(navigationProfilesProvider)
            .map((p) => p.id)
            .toList();
        final originalActive = container.read(currentBooruConfigProvider).id;
        final router = GoRouter.of(tester.element(profile(backend.configB.id)));
        final originalRoute = router.routeInformationProvider.value.uri;
        final gesture = await holdOn(tester, handle(backend.configB.id));
        expect(menuOpen(), isFalse);
        await gesture.moveBy(const Offset(-4, 0));
        await tester.pump(kLongPressTimeout * 2);
        expect(menuOpen(), isFalse);
        if (cancel) {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await harness.settle(tester);
        expect(menuOpen(), isFalse);
        expect(find.byType(ProfileManagementPage), findsOneWidget);
        expect(
          container.read(navigationProfilesProvider).map((p) => p.id),
          originalOrder,
        );
        expect(container.read(currentBooruConfigProvider).id, originalActive);
        expect(router.routeInformationProvider.value.uri, originalRoute);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final downward in [false, true]) {
    testWidgets(
      'the profile drag handle reorders after a long hold (downward=$downward)',
      (tester) async {
        final (harness, backend) = await mountProfiles(tester);
        const third = '00000000-0000-4000-8000-000000000099';
        final source = profile(backend.configB.id);
        final target = profile(downward ? third : backend.config.id);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProfileManagementPage)),
        );
        final active = container.read(currentBooruConfigProvider).id;
        // Measure before the reorder proxy introduces duplicate row keys.
        final distance =
            tester.getCenter(target).dy -
            tester.getCenter(source).dy +
            tester.getSize(target).height / 2 * (downward ? 1 : -1);
        final handleRect = tester.getRect(handle(backend.configB.id));
        expect(handleRect.size, const Size(48, 48));
        // The downward case also proves the empty edge of the handle is draggable.
        final start = downward
            ? handleRect.topLeft + const Offset(2, 2)
            : handleRect.center;
        final gesture = await tester.startGesture(start);
        await tester.pump(kLongPressTimeout * 2);
        expect(menuOpen(), isFalse);
        for (var step = 0; step < 10; step++) {
          await gesture.moveBy(Offset(0, distance / 10));
          await tester.pump(const Duration(milliseconds: 16));
          expect(menuOpen(), isFalse, reason: 'the menu would block the drag');
        }
        await gesture.up();
        await harness.settle(tester);
        final expected = downward
            ? [backend.config.id, third, backend.configB.id]
            : [backend.configB.id, backend.config.id, third];
        await harness.pumpUntil(
          tester,
          () =>
              container
                  .read(settingsProvider)
                  .booruConfigIdOrderList
                  .indexOf(backend.configB.id) ==
              (downward ? 2 : 0),
          description: 'held drag order to persist',
        );
        expect(
          container.read(settingsProvider).booruConfigIdOrderList,
          expected,
        );
        expect(
          container.read(navigationProfilesProvider).map((p) => p.id),
          expected,
        );
        expect(container.read(currentBooruConfigProvider).id, active);
        expect(menuOpen(), isFalse);
      },
    );
  }

  testWidgets(
    'downward and upward final indices persist across profile rebuild',
    (
      tester,
    ) async {
      final (harness, backend) = await mountProfiles(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfileManagementPage)),
      );
      const third = '00000000-0000-4000-8000-000000000099';
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(0, 2);
      await harness.settle(tester);
      expect(container.read(settingsProvider).booruConfigIdOrderList, [
        backend.configB.id,
        third,
        backend.config.id,
      ]);
      expect(
        tester.getTopLeft(profile(third)).dy,
        lessThan(tester.getTopLeft(profile(backend.config.id)).dy),
      );
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(2, 0);
      await harness.settle(tester);
      expect(container.read(settingsProvider).booruConfigIdOrderList, [
        backend.config.id,
        backend.configB.id,
        third,
      ]);
      expect(container.read(currentBooruConfigProvider).id, backend.config.id);
    },
  );

  testWidgets('right-clicking a profile on desktop opens its menu', (
    tester,
  ) async {
    final (harness, backend) = await mountProfiles(
      tester,
      platform: AppPlatform.macos,
      viewportSize: kDesktopViewport,
    );

    await tester.tap(
      handle(backend.configB.id),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await harness.settle(tester);
    expect(menuOpen(), isFalse);

    await tester.tap(
      profile(backend.configB.id),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await harness.settle(tester);

    expect(menuOpen(), isTrue);
  });

  testWidgets('the menu key on a focused profile opens its menu on the first '
      'item', (tester) async {
    final (harness, backend) = await mountProfiles(
      tester,
      platform: AppPlatform.macos,
      viewportSize: kDesktopViewport,
    );

    await KeyboardFlowDriver(
      tester: tester,
      harness: harness,
    ).focusOn(profile(backend.configB.id));
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await harness.settle(tester);

    expect(menuOpen(), isTrue);
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(
      find
          .ancestor(of: find.text('Edit'), matching: find.byType(Focus))
          .evaluate()
          .contains(focused),
      isTrue,
    );
  });
}
