// Flutter imports:
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:kurumi/material.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/navigation/profile_management_page.dart';

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
  }) async {
    final backend = FakeBooruBackend();
    final harness = HeadlessAppHarness(
      booruBackend: backend,
      viewportSize: viewportSize,
      runtime: backend.createRuntime(
        platform: platform,
        configs: [backend.config, backend.configB],
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

  testWidgets(
    'the profile drag handle reorders without opening its context menu',
    (
      tester,
    ) async {
      final (harness, backend) = await mountProfiles(tester);
      final a = profile(backend.config.id);
      final b = profile(backend.configB.id);
      expect(tester.getCenter(a).dy, lessThan(tester.getCenter(b).dy));

      // Dragging shows extra copies of the profile, so measure before it starts.
      final distance =
          tester.getCenter(a).dy -
          tester.getCenter(b).dy -
          tester.getSize(a).height / 2;
      final handle = find.descendant(
        of: b,
        matching: find.byType(ReorderableDragStartListener),
      );
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump();
      expect(menuOpen(), isFalse);

      for (var step = 1; step <= 10; step++) {
        await gesture.moveBy(Offset(0, distance / 10));
        await tester.pump(const Duration(milliseconds: 16));
        if ((distance / 10 * step).abs() >= 30) {
          expect(menuOpen(), isFalse, reason: 'the menu would block the drag');
        }
      }
      await gesture.up();
      await harness.settle(tester);

      expect(menuOpen(), isFalse);
      await harness.pumpUntil(
        tester,
        () => tester.getCenter(b).dy < tester.getCenter(a).dy,
        description: 'persisted profile order to update the list',
      );
      expect(tester.getCenter(b).dy, lessThan(tester.getCenter(a).dy));
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
