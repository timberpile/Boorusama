import 'dart:async';

import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/navigation/navigation_controller.dart';
import 'package:boorusama/core/navigation/navigation_drawer_host.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:boorusama/core/search/search/widgets.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../../application/support/fake_booru_backend.dart';
import '../../application/support/headless_app_harness.dart';

Future<(HeadlessAppHarness, WidgetRef)> _mount(
  WidgetTester tester, {
  int area = 5,
  Size size = const Size(400, 844),
}) async {
  final backend = FakeBooruBackend();
  final harness = await HeadlessAppHarness.mount(
    tester,
    booruBackend: backend,
    viewportSize: size,
    runtime: backend.createRuntime(
      settings: Settings.defaultSettings.copyWith(
        swipeAreaToOpenSidebarPercentage: area,
      ),
    ),
  );
  await harness.pumpUntilFound(tester, find.byType(PostGrid));
  await harness.settle(tester);
  return (
    harness,
    tester.element(find.byType(AppNavigationShell)) as WidgetRef,
  );
}

Future<void> _open(
  WidgetTester tester,
  HeadlessAppHarness harness, {
  double x = 1,
}) async {
  await tester.dragFrom(Offset(x, 300), const Offset(320, 0));
  await harness.settle(tester);
}

void main() {
  test('uses the historical swipe-area calculation', () {
    for (final c in [
      (400.0, 0, 20.0),
      (400.0, 5, 20.0),
      (400.0, 25, 100.0),
      (400.0, 100, 400.0),
      (400.0, 150, 400.0),
      (320.0, 5, 20.0),
    ]) {
      expect(legacyDrawerEdgeDragWidth(c.$1, c.$2), c.$3);
    }
  });

  testWidgets(
    'edge opens, left swipe closes, Menu and Escape stay synchronized',
    (tester) async {
      final (harness, ref) = await _mount(tester);
      expect(find.byType(DrawerController), findsOneWidget);
      await _open(tester, harness);
      expect(ref.read(navigationChromeProvider).menuOpen, isTrue);
      expect(find.byIcon(Icons.close), findsNothing);
      // Sample a continuous swipe across the narrower drawer. A single sparse
      // move can jump straight to the framework controller's dismissed state.
      await tester.timedDragFrom(
        const Offset(250, 300),
        const Offset(-300, 0),
        const Duration(milliseconds: 400),
      );
      await harness.settle(tester);
      expect(ref.read(navigationChromeProvider).menuOpen, isFalse);
      expect(
        find.byKey(const Key('nav-catalog-list')).hitTestable(),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('nav-menu-toggle')));
      await harness.settle(tester);
      expect(ref.read(navigationChromeProvider).menuOpen, isTrue);
      expect(
        find.byKey(const Key('nav-catalog-list')).hitTestable(),
        findsOneWidget,
      );
      await tester.timedDragFrom(
        const Offset(250, 300),
        const Offset(-300, 0),
        const Duration(milliseconds: 400),
      );
      await harness.settle(tester);
      await tester.tap(find.byKey(const Key('nav-menu-toggle')));
      await harness.settle(tester);
      expect(ref.read(navigationChromeProvider).menuOpen, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await harness.settle(tester);
      expect(ref.read(navigationChromeProvider).menuOpen, isFalse);
      await _open(tester, harness);
      await tester.tap(find.byKey(const Key('nav-menu-toggle')));
      await harness.settle(tester);
      expect(ref.read(navigationChromeProvider).menuOpen, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('partial drag cancels and the scrim consumes the tap', (
    tester,
  ) async {
    final (harness, ref) = await _mount(tester);
    final drag = await tester.startGesture(const Offset(1, 300));
    await drag.moveBy(const Offset(60, 0));
    await tester.pump();
    await drag.cancel();
    await harness.settle(tester);
    expect(ref.read(navigationChromeProvider).menuOpen, isFalse);
    await _open(tester, harness);
    await tester.tapAt(const Offset(390, 250));
    await harness.settle(tester);
    expect(ref.read(navigationChromeProvider).menuOpen, isFalse);
    expect(find.byType(PostDetailsPageScaffold), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final area in [0, 5, 25, 100]) {
    testWidgets('framework hit region respects $area percent', (tester) async {
      final (harness, ref) = await _mount(tester, area: area);
      final drawer = tester.widget<DrawerController>(
        find.byType(DrawerController),
      );
      expect(drawer.edgeDragWidth, legacyDrawerEdgeDragWidth(400, area));
      await _open(tester, harness, x: 80);
      expect(ref.read(navigationChromeProvider).menuOpen, area >= 25);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Back closes only the drawer and preserves the nested search and grid',
    (tester) async {
      final (harness, ref) = await _mount(tester);
      final grid = tester.state(find.byType(PostGrid));
      final pageRef = tester.element(find.byType(PostGrid)) as WidgetRef;
      unawaited(
        goToSearchPage(
          pageRef,
          config: harness.booruBackend.config,
          tag: 'cat',
        ),
      );
      await harness.pumpUntilFound(tester, find.byType(SearchPage));
      await harness.settle(tester);
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await harness.settle(tester);
      final search = tester.state(find.byType(SearchPage));
      await _open(tester, harness);
      expect(ref.read(navigationChromeProvider).menuOpen, isTrue);
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      expect(ref.read(navigationChromeProvider).menuOpen, isFalse);
      expect(tester.state(find.byType(SearchPage)), same(search));
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      expect(find.byType(SearchPage), findsNothing);
      expect(tester.state(find.byType(PostGrid)), same(grid));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bottom shortcuts work outside the drawer and opening reveals the bar',
    (tester) async {
      final (harness, ref) = await _mount(tester);
      final chrome = ref.read(navigationChromeProvider.notifier);
      chrome.userScroll(delta: 30, pixels: 200, outOfRange: false);
      await harness.settle(tester);
      expect(ref.read(navigationChromeProvider).barVisible, isFalse);
      await _open(tester, harness);
      for (final target in [
        ('following', AppDestination.following),
        ('bookmarks', AppDestination.bookmarks),
      ]) {
        expect(
          find.byKey(Key('nav-shortcut-${target.$1}')).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.byKey(Key('nav-shortcut-${target.$1}')));
        await harness.settle(tester);
        expect(
          ref
              .read(navigationControllerProvider.notifier)
              .binding!
              .currentDestination,
          DestinationId.app(target.$2),
        );
        expect(ref.read(navigationChromeProvider).menuOpen, isFalse);
        await _open(tester, harness);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resizing closes compact drawer without remounting retained navigators',
    (tester) async {
      final (harness, ref) = await _mount(tester);
      final grid = tester.state(find.byType(PostGrid));
      await _open(tester, harness);
      harness.setViewport(tester, const Size(1200, 800));
      await harness.settle(tester);
      expect(ref.read(navigationChromeProvider).menuOpen, isFalse);
      expect(tester.state(find.byType(PostGrid)), same(grid));
      harness.setViewport(tester, const Size(400, 844));
      await harness.settle(tester);
      await _open(tester, harness);
      expect(ref.read(navigationChromeProvider).menuOpen, isTrue);
      expect(tester.state(find.byType(PostGrid)), same(grid));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'menu scrolls vertically and a branch-local modal blocks edge opening',
    (tester) async {
      final (harness, ref) = await _mount(tester, size: const Size(400, 500));
      await _open(tester, harness);
      final list = find.descendant(
        of: find.byType(NavigationDrawerHost),
        matching: find.byType(ListView),
      );
      final scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      await tester.drag(list, const Offset(0, -250));
      await harness.settle(tester);
      expect(position.pixels, greaterThan(0));
      expect(ref.read(navigationChromeProvider).menuOpen, isTrue);
      await tester.tap(find.byKey(const Key('nav-menu-toggle')));
      await harness.settle(tester);
      final context = tester.element(find.byType(PostGrid));
      unawaited(
        showDialog<void>(
          context: context,
          useRootNavigator: false,
          builder: (_) => const AlertDialog(content: Text('Branch modal')),
        ),
      );
      await harness.settle(tester);
      await _open(tester, harness);
      expect(ref.read(navigationChromeProvider).menuOpen, isFalse);
      expect(find.text('Branch modal'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      await _open(tester, harness);
      expect(ref.read(navigationChromeProvider).menuOpen, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selection, a root modal and viewer block opening without viewer clearance',
    (tester) async {
      final (harness, ref) = await _mount(tester);
      ref.read(navigationChromeProvider.notifier).setSelection(true);
      await harness.settle(tester);
      await _open(tester, harness);
      expect(ref.read(navigationChromeProvider).menuOpen, isFalse);
      ref.read(navigationChromeProvider.notifier).setSelection(false);
      await harness.settle(tester);
      unawaited(
        showDialog<void>(
          context: ref.context,
          builder: (_) => const AlertDialog(content: Text('Blocking dialog')),
        ),
      );
      await harness.settle(tester);
      await _open(tester, harness);
      expect(ref.read(navigationChromeProvider).menuOpen, isFalse);
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      await tester.tap(find.byType(SliverPostGridImageGridItem).first);
      await harness.pumpUntilFound(
        tester,
        find.byType(PostDetailsPageScaffold),
      );
      await harness.settle(tester);
      expect(find.byKey(const Key('nav-menu-toggle')), findsNothing);
      final viewerContext = tester.element(
        find.byType(PostDetailsPageScaffold),
      );
      expect(MediaQuery.paddingOf(viewerContext).bottom, 0);
      expect(MediaQuery.viewPaddingOf(viewerContext).bottom, 0);
      await _open(tester, harness);
      expect(ref.read(navigationChromeProvider).menuOpen, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
