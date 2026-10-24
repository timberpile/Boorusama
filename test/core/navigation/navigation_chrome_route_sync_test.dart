import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/navigation/navigation_chrome_route_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('returning from a scrolled feed reveals bottom navigation', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final chrome = container.read(navigationChromeProvider.notifier);

    final feed = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/following-topics/feed'),
      builder: (_) => const SizedBox(),
    );
    final overview = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/following-topics'),
      builder: (_) => const SizedBox(),
    );
    final editor = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/following-topics/feed/edit'),
      builder: (_) => const SizedBox(),
    );
    final viewer = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/details'),
      builder: (_) => const SizedBox(),
    );
    final popup = RawDialogRoute<void>(
      pageBuilder: (_, _, _) => const SizedBox(),
    );

    Widget host(Route<dynamic> route) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: NavigationChromeRouteSync(
          route: route,
          child: const SizedBox(),
        ),
      ),
    );
    void hide() => chrome.userScroll(
      delta: 100,
      pixels: 300,
      outOfRange: false,
    );
    double hidden() =>
        container.read(navigationChromeProvider).barHiddenFraction;

    await tester.pumpWidget(host(feed));
    hide();
    expect(hidden(), 1);

    // Rebuilding or opening a popup must not reveal a scrolled feed's bar.
    await tester.pumpWidget(host(popup));
    await tester.pumpWidget(host(feed));
    expect(hidden(), 1);

    // Opening/closing the post viewer retains the feed's scroll chrome.
    await tester.pumpWidget(host(viewer));
    await tester.pumpWidget(host(feed));
    expect(hidden(), 1);

    // Leaving the feed for either a non-scrollable parent or editor resets it.
    await tester.pumpWidget(host(overview));
    await tester.pump();
    expect(hidden(), 0);
    await tester.pumpWidget(host(feed));
    hide();
    expect(hidden(), 1);
    await tester.pumpWidget(host(editor));
    await tester.pump();
    expect(hidden(), 0);

    // Returning to a feed does not disable its normal scroll-driven hiding.
    await tester.pumpWidget(host(feed));
    hide();
    expect(hidden(), 1);
    chrome.userScroll(
      delta: -100,
      pixels: 200,
      outOfRange: false,
    );
    expect(hidden(), 0);
    expect(tester.takeException(), isNull);
  });
}
