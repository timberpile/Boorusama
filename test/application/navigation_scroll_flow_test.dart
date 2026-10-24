import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  for (final travel in [20.0, 70.0]) {
    testWidgets(
      'held grid drag moves navigation pixel for pixel, travel=$travel',
      (tester) async {
        final backend = FakeBooruBackend()
          ..posts.addAll(testPostRange(103, 150));
        final harness = await HeadlessAppHarness.mount(
          tester,
          booruBackend: backend,
          phone: TestPhone.portrait,
        );
        await harness.pumpUntilFound(tester, find.byType(PostGrid));
        await harness.settle(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(AppNavigationShell)),
        );
        final scroll = tester
            .state<ScrollableState>(postGridScrollable())
            .position;
        scroll.jumpTo(300);
        await harness.settle(tester);
        final bar = find.byKey(const Key('nav-shortcut-browse'));
        final originalTop = tester.getTopLeft(bar).dy;
        expect(container.read(navigationChromeProvider).barHiddenFraction, 0);
        final gesture = await tester.startGesture(const Offset(200, 400));
        // Cross touch slop before comparing content and chrome displacement.
        await gesture.moveBy(const Offset(0, -25));
        await tester.pump();
        final startPixels = scroll.pixels;
        final startTop = tester.getTopLeft(bar).dy;
        await gesture.moveBy(Offset(0, -travel));
        await tester.pump();
        final movedTop = tester.getTopLeft(bar).dy;
        expect(
          movedTop - startTop,
          closeTo(scroll.pixels - startPixels, 0.001),
        );
        expect(movedTop, greaterThan(originalTop));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.getTopLeft(bar).dy, movedTop);
        // Direction changes take effect immediately, without a new threshold.
        final reversePixels = scroll.pixels;
        await gesture.moveBy(const Offset(0, 6));
        await tester.pump();
        expect(
          tester.getTopLeft(bar).dy - movedTop,
          closeTo(scroll.pixels - reversePixels, 0.001),
        );
        await gesture.up();
        await harness.settle(tester);
        expect(
          container.read(navigationChromeProvider).barScrollActive,
          isFalse,
        );
        expect(
          container.read(navigationChromeProvider).barHiddenFraction,
          travel < 49 ? 0 : 1,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
