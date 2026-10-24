import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/navigation/navigation_chrome_route_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final destination in ['/following-topics', '/following-topics/feed/edit']) {
    testWidgets('leaving a viewer for $destination reveals the bar', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final chrome = container.read(navigationChromeProvider.notifier);
      MaterialPageRoute<void> page(String name) => MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: (_) => const SizedBox(),
      );
      final feed = page('/following-topics/feed');
      final viewer = page('/details');
      final target = page(destination);
      final popup = RawDialogRoute<void>(
        pageBuilder: (_, _, _) => const SizedBox(),
      );
      Widget host(Route<dynamic> route) => UncontrolledProviderScope(
        container: container,
        child: NavigationChromeRouteSync(
          route: route,
          child: const SizedBox(),
        ),
      );
      double hidden() =>
          container.read(navigationChromeProvider).barHiddenFraction;

      await tester.pumpWidget(host(feed));
      chrome.userScroll(delta: 100, pixels: 300, outOfRange: false);
      expect(hidden(), 1);
      await tester.pumpWidget(host(viewer));
      await tester.pumpWidget(host(popup));
      await tester.pumpWidget(host(viewer));
      expect(hidden(), 1);

      // Returning to the same feed still preserves its scroll state.
      await tester.pumpWidget(host(feed));
      expect(hidden(), 1);
      await tester.pumpWidget(host(viewer));

      // Replacing/unwinding the viewer to another page must not inherit it.
      await tester.pumpWidget(host(target));
      await tester.pump();
      expect(hidden(), 0);
      expect(tester.takeException(), isNull);
    });
  }
}
