import 'package:boorusama/core/posts/pools/pool_grid_item.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:boorusama/core/posts/details/src/routes/routes.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:boorusama/core/posts/details_pageview/src/post_details_overlay.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:go_router/go_router.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final hidden in [false, true]) {
    for (final detailsEnabled in [false, true]) {
      testWidgets(
        'dismissal never reveals Back (hidden=$hidden, details=$detailsEnabled)',
        (tester) async {
          final controller = PostDetailsPageViewController(
            initialPage: 0,
            totalPage: 1,
            initialHideOverlay: hidden,
            checkIfLargeScreen: () => false,
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            controller.dispose();
          });
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: PostDetailsOverlay(
                  controller: controller,
                  leftActions: const [],
                  actions: const [],
                  detailsEnabled: detailsEnabled,
                  isLargeScreen: false,
                  overlayCurvedAnimation: null,
                ),
              ),
            ),
          );
          final back = find.byIcon(Symbols.arrow_back_ios);
          expect(
            back,
            hidden && detailsEnabled ? findsNothing : findsOneWidget,
          );
          controller.freestyleMoving.value = true;
          controller.hideOverlay(includeSystemStatus: false);
          await tester.pump();
          expect(back, findsNothing);
        },
      );
    }
  }

  testWidgets(
    'downward viewer drag locks horizontal paging until the gesture ends',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PostDetailsPageViewController(
        initialPage: 0,
        totalPage: 2,
        checkIfLargeScreen: () => false,
      );
      try {
        await tester.pumpWidget(
          BooruLocalization(
            child: MaterialApp(
              home: Scaffold(
                body: PostDetailsPageView(
                  controller: controller,
                  itemCount: 2,
                  swipeDownThreshold: 5000,
                  checkIfLargeScreen: () => false,
                  detailsSliversBuilder: (_, _) => const [],
                  itemBuilder: (_, index) => ColoredBox(
                    key: ValueKey(('swipe-lock-page', index)),
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final gesture = await tester.startGesture(const Offset(200, 250));
        await gesture.moveBy(const Offset(10, 110));
        await tester.pump();
        expect(controller.freestyleMoving.value, isTrue);
        expect(controller.animating.value, isFalse);

        await gesture.moveBy(const Offset(-175, 55));
        await tester.pump();
        expect(
          controller.pageController.page,
          closeTo(0, 0.001),
          reason: 'horizontal movement must not page during dismissal',
        );
        expect(controller.page, 0);

        await gesture.up();
        await tester.pumpAndSettle();
        expect(controller.animating.value, isFalse);
        expect(controller.freestyleMoving.value, isFalse);
        expect(controller.page, 0);

        // A programmatic page change must release only this gesture's gate.
        final interrupted = await tester.startGesture(const Offset(200, 250));
        await interrupted.moveBy(const Offset(0, 110));
        await tester.pump();
        expect(controller.freestyleMoving.value, isTrue);
        controller.pageController.jumpToPage(1);
        await tester.pump();
        expect(controller.page, 1);
        expect(controller.freestyleMoving.value, isFalse);
        expect(controller.animating.value, isFalse);
        await interrupted.up();
        await tester.pumpAndSettle();
        expect(controller.page, 1);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets(
    'unmounting during a held downward dismissal defers notifier release',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PostDetailsPageViewController(
        initialPage: 0,
        totalPage: 1,
        checkIfLargeScreen: () => false,
      );
      try {
        await tester.pumpWidget(
          BooruLocalization(
            child: MaterialApp(
              home: Scaffold(
                body: PostDetailsPageView(
                  controller: controller,
                  itemCount: 1,
                  swipeDownThreshold: 5000,
                  checkIfLargeScreen: () => false,
                  detailsSliversBuilder: (_, _) => const [],
                  itemBuilder: (_, _) => const ColoredBox(
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final held = await tester.startGesture(const Offset(200, 250));
        await held.moveBy(const Offset(0, 110));
        await tester.pump();
        expect(controller.freestyleMoving.value, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
        await tester.pump();
        expect(controller.freestyleMoving.value, isFalse);
        expect(controller.freestyleMoveOffset.value, Offset.zero);
        await held.up();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets(
    'removing the Viewer during a held horizontal drag is safe',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PostDetailsPageViewController(
        initialPage: 0,
        totalPage: 2,
        checkIfLargeScreen: () => false,
      );
      try {
        await tester.pumpWidget(
          BooruLocalization(
            child: MaterialApp(
              home: Scaffold(
                body: PostDetailsPageView(
                  controller: controller,
                  itemCount: 2,
                  checkIfLargeScreen: () => false,
                  detailsSliversBuilder: (_, _) => const [],
                  itemBuilder: (_, index) => ColoredBox(
                    color: index == 0 ? Colors.red : Colors.blue,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final held = await tester.startGesture(const Offset(200, 200));
        await held.moveBy(const Offset(-100, 0));
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
        await held.up();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets(
    'downward dismissal keeps image width, horizontal position and release position',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PostDetailsPageViewController(
        initialPage: 0,
        totalPage: 1,
        initialHideOverlay: true,
        checkIfLargeScreen: () => false,
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/viewer'),
                child: const Text('Open'),
              ),
            ),
          ),
          GoRoute(
            path: '/viewer',
            pageBuilder: (context, state) => PostDetailsTransitionPage(
              key: state.pageKey,
              child: Scaffold(
                key: const ValueKey('viewer-surface'),
                backgroundColor: Colors.black,
                body: PostDetailsPageView(
                  controller: controller,
                  itemCount: 1,
                  swipeDownThreshold: 300,
                  checkIfLargeScreen: () => false,
                  mediaSizeBuilder: (_) => const Size(200, 300),
                  detailsSliversBuilder: (_, _) => const [],
                  itemBuilder: (_, _) => const Center(
                    child: SizedBox(
                      key: ValueKey('drag-image'),
                      width: 200,
                      height: 300,
                      child: ColoredBox(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
      try {
        await tester.pumpWidget(
          BooruLocalization(child: MaterialApp.router(routerConfig: router)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final image = find.byKey(const ValueKey('drag-image'));
        final surface = find.byKey(const ValueKey('viewer-surface'));
        final initialSurface = tester.getRect(surface);
        final initial = tester.getRect(image);
        expect(ModalRoute.of(tester.element(image))!.opaque, isFalse);
        // A downward gesture below the configured threshold must return
        // the route to its original position instead of dismissing it.
        final shortDrag = await tester.startGesture(initial.center);
        await shortDrag.moveBy(const Offset(0, 120));
        await tester.pump();
        final shortHeld = tester.getRect(surface);
        expect(shortHeld.top, closeTo(initialSurface.top + 120, .1));
        await shortDrag.up();
        await tester.pump();
        expect(controller.freestyleMoving.value, isTrue);
        expect(tester.getRect(surface).top, closeTo(shortHeld.top, .1));
        await tester.pump(const Duration(milliseconds: 60));
        final returning = tester.getRect(surface).top;
        expect(returning, lessThan(shortHeld.top));
        expect(returning, greaterThan(initialSurface.top));
        expect(controller.freestyleMoving.value, isTrue);
        await tester.pumpAndSettle();
        expect(surface, findsOneWidget);
        expect(controller.freestyleMoving.value, isFalse);
        expect(tester.getRect(surface), initialSurface);

        final drag = await tester.startGesture(initial.center);
        await drag.moveBy(const Offset(20, 320));
        await tester.pump();
        final held = tester.getRect(image);
        expect(
          held.left,
          closeTo(initial.left, .1),
          reason: 'dismissal has no sideways travel',
        );
        expect(
          held.size,
          initial.size,
          reason: 'dismissal must not shrink the image',
        );
        expect(held.top, closeTo(initial.top + 320, .1));
        expect(
          tester.getRect(surface).top,
          closeTo(initialSurface.top + 320, .1),
          reason: 'the entire Viewer moves instead of only its image',
        );
        expect(controller.freestyleMoving.value, isTrue);
        await drag.up();
        await tester.pump();
        expect(
          tester.getRect(image).top,
          closeTo(held.top, .1),
          reason: 'release never resets the image',
        );
        for (var frame = 0; frame < 4; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final closing = tester.getRect(image);
          expect(closing.top, greaterThanOrEqualTo(held.top));
          expect(closing.left, closeTo(initial.left, .1));
          expect(closing.size, initial.size);
          expect(
            tester.getRect(surface).top,
            greaterThanOrEqualTo(initialSurface.top + 320),
            reason: 'the entire Viewer continues down after release',
          );
        }
        await tester.pumpAndSettle();
        expect(image, findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        controller.dispose();
      }
    },
  );

  testWidgets(
    'side entry never paints a full-screen frame over the timeline before sliding',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              backgroundColor: Colors.blue,
              body: SizedBox(
                width: 100,
                height: 120,
                child: PoolGridItem(
                  name: 'Work',
                  total: 3,
                  image: const ColoredBox(color: Colors.red),
                  onTap: () => context.push('/viewer'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/viewer',
            pageBuilder: (_, state) => PostDetailsTransitionPage(
              key: state.pageKey,
              child: const ColoredBox(
                key: ValueKey('viewer-page'),
                color: Colors.black,
              ),
            ),
          ),
        ],
      );
      try {
        await tester.pumpWidget(
          BooruLocalization(
            child: RepaintBoundary(
              key: boundary,
              child: MaterialApp.router(routerConfig: router),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PoolGridItem));
        await tester.pump();
        final pixels = await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData();
          image.dispose();
          return data!.buffer.asUint8List();
        });
        const center = (400 * 400 + 200) * 4;
        expect(pixels!.sublist(center, center + 4), [
          33,
          150,
          243,
          255,
        ], reason: 'the first painted frame must still show the timeline');
        var previous = 400.0;
        for (final delay in [1, 8, 16, 32, 48, 64, 80, 80]) {
          await tester.pump(Duration(milliseconds: delay));
          final rect = tester.getRect(
            find.byKey(const ValueKey('viewer-page')),
          );
          expect(rect.left, lessThanOrEqualTo(previous + .01));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.top, 0);
          previous = rect.left;
        }
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byKey(const ValueKey('viewer-page'))),
          const Rect.fromLTWH(0, 0, 400, 800),
        );
        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 32));
        final exiting = tester.getRect(
          find.byKey(const ValueKey('viewer-page')),
        );
        expect(exiting.left, 0);
        expect(exiting.top, greaterThan(0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    },
  );
}
