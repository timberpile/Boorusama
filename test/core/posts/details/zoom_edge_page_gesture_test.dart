import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

import 'package:boorusama/core/posts/details/src/types/post_viewer_transformation_controller.dart';
import 'package:boorusama/core/posts/details/src/widgets/zoom_edge_page_gesture.dart';
import 'package:boorusama/core/posts/details_pageview/src/post_details_page_view_controller.dart';
import 'package:boorusama/core/posts/details_pageview/src/zoom_page_navigation_scope.dart';

void main() {
  testWidgets('edge ring fills over 160dp and navigates only on release', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.zoomAtRightEdge();
    await tester.pump();

    final drag = await tester.startGesture(harness.center);
    await drag.moveBy(const Offset(-40, 0));
    await tester.pump();
    final ring = find.byType(CircularProgressIndicator);
    expect(
      tester.widget<CircularProgressIndicator>(ring).value,
      closeTo(0.25, 0.01),
    );
    final fade = find.ancestor(of: ring, matching: find.byType(Opacity)).first;
    expect(tester.widget<Opacity>(fade).opacity, closeTo(0.5, 0.01));
    expect(
      tester.getRect(ring).center.dx,
      greaterThan(harness.size.width - 40),
    );
    expect(harness.nextCount, 0);

    await drag.moveBy(const Offset(-40, 0));
    await tester.pump();
    expect(
      tester.widget<CircularProgressIndicator>(ring).value,
      closeTo(0.5, 0.01),
    );
    expect(tester.widget<Opacity>(fade).opacity, 1);

    await drag.moveBy(const Offset(-80, 0));
    await tester.pump();
    expect(tester.widget<CircularProgressIndicator>(ring).value, 1);
    expect(harness.nextCount, 0);
    await drag.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(ring, findsNothing);
    expect(harness.nextCount, 1);
  });

  for (final scenario in [
    (secondMove: -209.0, outward: 159, progress: 159 / 160, navigations: 0),
    (secondMove: -210.0, outward: 160, progress: 1.0, navigations: 1),
    (secondMove: -211.0, outward: 161, progress: 1.0, navigations: 1),
  ]) {
    testWidgets(
      'a crossing pull ${scenario.outward}dp beyond the clamp commits ${scenario.navigations} page on release',
      (tester) async {
        final harness = _Harness();
        addTearDown(harness.dispose);
        await _mount(tester, harness);
        harness.matrix.value = Matrix4.diagonal3Values(2, 2, 1)
          ..setTranslationRaw(-750, -400, 0);
        harness.controller.zoom.value = true;
        await tester.pump();
        expect(
          harness.transform.horizontalEdges(harness.contentSize)?.right,
          isFalse,
        );

        final drag = await tester.startGesture(harness.center);
        await drag.moveBy(const Offset(-100, 0));
        expect(harness.matrix.value.getTranslation().x, -750);
        await drag.moveBy(Offset(scenario.secondMove, 0));
        await tester.pump();
        expect(harness.matrix.value.getTranslation().x, -800);
        expect(
          harness.transform.horizontalEdges(harness.contentSize)?.right,
          isTrue,
        );
        final ring = find.byType(CircularProgressIndicator);
        expect(
          tester.widget<CircularProgressIndicator>(ring).value,
          closeTo(scenario.progress, 0.01),
        );
        expect(harness.nextCount, 0);
        await drag.up();
        await tester.pump(const Duration(milliseconds: 100));
        expect(harness.nextCount, scenario.navigations);
      },
    );
  }

  for (final scenario in [
    (secondMove: -109.0, progress: 159 / 160, navigations: 0),
    (secondMove: -110.0, progress: 1.0, navigations: 1),
  ]) {
    testWidgets(
      'batched edge moves reach ${scenario.navigations} navigation after release',
      (tester) async {
        final harness = _Harness();
        addTearDown(harness.dispose);
        await _mount(tester, harness);
        harness.zoomAtRightEdge();
        await tester.pump();

        final drag = await tester.startGesture(harness.center, pointer: 17);
        final pointer = TestPointer(17)..down(harness.center);
        tester.binding.handlePointerEventForSource(
          pointer.move(harness.center + const Offset(-50, 0)),
          source: TestBindingEventSource.test,
        );
        tester.binding.handlePointerEventForSource(
          pointer.move(harness.center + Offset(-50 + scenario.secondMove, 0)),
          source: TestBindingEventSource.test,
        );
        await tester.pump();
        final ring = find.byType(CircularProgressIndicator);
        expect(
          tester.widget<CircularProgressIndicator>(ring).value,
          closeTo(scenario.progress, 0.001),
        );
        expect(harness.nextCount, 0);

        await drag.up();
        await tester.pump(const Duration(milliseconds: 100));
        expect(harness.nextCount, scenario.navigations);
      },
    );
  }

  for (final scenario in [
    (lastMove: -109.0, progress: 159 / 160, navigations: 0),
    (lastMove: -110.0, progress: 1.0, navigations: 1),
  ]) {
    testWidgets(
      'batched crossing and pull commit ${scenario.navigations} page after release',
      (tester) async {
        final harness = _Harness();
        addTearDown(harness.dispose);
        await _mount(tester, harness);
        harness.matrix.value = Matrix4.diagonal3Values(2, 2, 1)
          ..setTranslationRaw(-750, -400, 0);
        harness.controller.zoom.value = true;
        await tester.pump();

        final drag = await tester.startGesture(harness.center, pointer: 21);
        await drag.moveBy(const Offset(-100, 0));
        expect(harness.matrix.value.getTranslation().x, -750);
        final pointer = TestPointer(21)
          ..down(harness.center + const Offset(-100, 0));
        tester.binding.handlePointerEventForSource(
          pointer.move(harness.center + const Offset(-200, 0)),
          source: TestBindingEventSource.test,
        );
        tester.binding.handlePointerEventForSource(
          pointer.move(harness.center + Offset(-200 + scenario.lastMove, 0)),
          source: TestBindingEventSource.test,
        );
        await tester.pump();
        expect(harness.matrix.value.getTranslation().x, -800);
        expect(
          tester
              .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator),
              )
              .value,
          closeTo(scenario.progress, 0.001),
        );
        expect(harness.nextCount, 0);

        await drag.up();
        await tester.pump(const Duration(milliseconds: 100));
        expect(harness.nextCount, scenario.navigations);
      },
    );
  }

  testWidgets('a first move that has not panned to the clamp shows no ring', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.matrix.value = Matrix4.diagonal3Values(2, 2, 1)
      ..setTranslationRaw(-750, -400, 0);
    harness.controller.zoom.value = true;
    await tester.pump();

    final drag = await tester.startGesture(harness.center);
    await drag.moveBy(const Offset(-200, 0));
    await tester.pump();
    expect(harness.matrix.value.getTranslation().x, -750);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await drag.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 0);
  });

  testWidgets('subthreshold and unavailable pulls show no armed action', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.zoomAtRightEdge();
    await tester.pump();

    final short = await tester.startGesture(harness.center);
    await short.moveBy(const Offset(-159, 0));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await short.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(harness.nextCount, 0);

    harness.hasNext = false;
    await tester.pumpWidget(harness.build());
    final unavailable = await tester.startGesture(harness.center);
    await unavailable.moveBy(const Offset(-170, 0));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await unavailable.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 0);
  });

  testWidgets('reversal hides the ring and cannot commit on release', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.zoomAtRightEdge();
    await tester.pump();

    final drag = await tester.startGesture(harness.center);
    await drag.moveBy(const Offset(-60, 0));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await drag.moveBy(const Offset(3, 0));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await drag.moveBy(const Offset(-80, 0));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await drag.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 0);
  });

  testWidgets('a second pointer hides a painted ring while both remain down', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.zoomAtRightEdge();
    await tester.pump();

    final first = await tester.startGesture(harness.center, pointer: 1);
    await first.moveBy(const Offset(-48, 0));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final second = await tester.startGesture(
      harness.center + const Offset(40, 0),
      pointer: 2,
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await first.up();
    await second.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 0);
  });

  testWidgets('right-to-left Next ring appears at the left viewport edge', (
    tester,
  ) async {
    final harness = _Harness(direction: TextDirection.rtl);
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.zoomAtLeftEdge();
    await tester.pump();

    final drag = await tester.startGesture(harness.center);
    await drag.moveBy(const Offset(80, 0));
    await tester.pump();
    final ring = find.byType(CircularProgressIndicator);
    expect(
      tester.widget<CircularProgressIndicator>(ring).value,
      closeTo(0.5, 0.01),
    );
    expect(tester.getRect(ring).center.dx, lessThan(40));
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    await drag.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 0);
  });

  for (final size in [const Size(400, 800), const Size(800, 1200)]) {
    testWidgets(
      'navigates only on release after an outward edge drag at $size',
      (
        tester,
      ) async {
        final harness = _Harness(size: size);
        addTearDown(harness.dispose);
        await _mount(tester, harness);
        harness.zoomAtRightEdge();
        await tester.pump(const Duration(milliseconds: 100));

        final drag = await tester.startGesture(harness.center);
        await drag.moveBy(const Offset(-170, 0));
        await tester.pump(const Duration(milliseconds: 100));
        expect(harness.nextCount, 0);
        await drag.up();
        await tester.pump(const Duration(milliseconds: 100));
        expect(harness.nextCount, 1);
      },
    );
  }

  testWidgets('pans normally until the image reaches its true fitted edge', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.zoomAtCenter();
    await tester.pump(const Duration(milliseconds: 100));

    final drag = await tester.startGesture(harness.center);
    await drag.moveBy(const Offset(-110, 0));
    await drag.moveBy(const Offset(-110, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.matrix.value.getTranslation().x, lessThan(-400));
    await drag.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 0);

    harness.zoomAtRightEdge();
    await tester.pump(const Duration(milliseconds: 100));
    final outward = await tester.startGesture(harness.center);
    await outward.moveBy(const Offset(-170, 0));
    await outward.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 1);
  });

  testWidgets('ignores subthreshold, reversed, vertical, and cancelled drags', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.zoomAtRightEdge();
    await tester.pump(const Duration(milliseconds: 100));

    final short = await tester.startGesture(harness.center);
    await short.moveBy(const Offset(-40, 0));
    await short.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 0);

    final reversed = await tester.startGesture(harness.center);
    await reversed.moveBy(const Offset(-170, 0));
    await reversed.moveBy(const Offset(10, 0));
    await reversed.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 0);

    harness.matrix.value = Matrix4.diagonal3Values(2, 2, 1)
      ..setTranslationRaw(-800, -200, 0);
    await tester.pump(const Duration(milliseconds: 100));
    final verticalBefore = harness.matrix.value.getTranslation().y;
    final vertical = await tester.startGesture(harness.center);
    await vertical.moveBy(const Offset(-10, -50));
    await vertical.moveBy(const Offset(-10, -50));
    await vertical.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.matrix.value.getTranslation().y, lessThan(verticalBefore));
    expect(harness.nextCount, 0);

    final cancelled = await tester.startGesture(harness.center);
    await cancelled.moveBy(const Offset(-170, 0));
    await cancelled.cancel();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 0);
  });

  testWidgets('small reversals cannot accumulate a 160dp edge handoff', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.zoomAtRightEdge();
    await tester.pump();

    final drag = await tester.startGesture(harness.center);
    await drag.moveBy(const Offset(-20, 0));
    for (var i = 0; i < 160; i++) {
      await drag.moveBy(const Offset(1, 0));
      await drag.moveBy(const Offset(-1, 0));
    }
    await drag.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 0);
  });

  for (final scenario in [
    (
      name: 'LTR right edge toward Next',
      textDirection: TextDirection.ltr,
      outward: -1.0,
    ),
    (
      name: 'LTR left edge toward Previous',
      textDirection: TextDirection.ltr,
      outward: 1.0,
    ),
    (
      name: 'RTL left edge toward Next',
      textDirection: TextDirection.rtl,
      outward: 1.0,
    ),
    (
      name: 'RTL right edge toward Previous',
      textDirection: TextDirection.rtl,
      outward: -1.0,
    ),
  ]) {
    testWidgets('a slow full reversal cancels ${scenario.name}', (
      tester,
    ) async {
      final harness = _Harness(
        contentSize: const Size(100, 401),
        direction: scenario.textDirection,
      );
      addTearDown(harness.dispose);
      await _mount(tester, harness);
      harness.transform.onPageSettled(0);
      expect(
        harness.transform.tryAutoStartComicStrip(
          postId: 1,
          contentSize: harness.contentSize,
          enabled: true,
        ),
        isTrue,
      );
      harness.controller.zoom.value = true;
      await tester.pump();
      expect(
        harness.transform.horizontalEdges(harness.contentSize),
        (left: true, right: true),
      );

      final drag = await tester.startGesture(harness.center);
      await drag.moveBy(Offset(20 * scenario.outward, 0));
      for (var i = 0; i < 100; i++) {
        await drag.moveBy(Offset(-scenario.outward, 0));
      }
      for (var i = 0; i < 260; i++) {
        await drag.moveBy(Offset(scenario.outward, 0));
      }
      await drag.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(harness.nextCount, 0);
      expect(harness.previousCount, 0);
    });
  }

  testWidgets('a steady outward drag still navigates a fit-width comic', (
    tester,
  ) async {
    final harness = _Harness(contentSize: const Size(100, 401));
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.transform.onPageSettled(0);
    expect(
      harness.transform.tryAutoStartComicStrip(
        postId: 1,
        contentSize: harness.contentSize,
        enabled: true,
      ),
      isTrue,
    );
    harness.controller.zoom.value = true;
    await tester.pump();

    final drag = await tester.startGesture(harness.center);
    await drag.moveBy(const Offset(-12, 0));
    for (var i = 0; i < 160; i++) {
      await drag.moveBy(const Offset(-1, 0));
    }
    expect(harness.nextCount, 0);
    await drag.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 1);
  });

  testWidgets('two one-dp inward jitters preserve an outward handoff', (
    tester,
  ) async {
    final harness = _Harness(contentSize: const Size(100, 401));
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.transform.onPageSettled(0);
    expect(
      harness.transform.tryAutoStartComicStrip(
        postId: 1,
        contentSize: harness.contentSize,
        enabled: true,
      ),
      isTrue,
    );
    harness.controller.zoom.value = true;
    await tester.pump();

    final drag = await tester.startGesture(harness.center);
    await drag.moveBy(const Offset(-30, 0));
    await drag.moveBy(const Offset(1, 0));
    await drag.moveBy(const Offset(1, 0));
    await drag.moveBy(const Offset(-1, 0));
    await drag.moveBy(const Offset(-1, 0));
    await drag.moveBy(const Offset(-130, 0));
    await drag.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 1);
  });

  testWidgets('newly available navigation cannot use an already held drag', (
    tester,
  ) async {
    final harness = _Harness(hasNext: false);
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.zoomAtRightEdge();
    await tester.pump();

    final drag = await tester.startGesture(harness.center);
    await drag.moveBy(const Offset(-170, 0));
    harness.hasNext = true;
    await tester.pumpWidget(harness.build());
    await drag.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 0);

    final freshDrag = await tester.startGesture(harness.center);
    await freshDrag.moveBy(const Offset(-170, 0));
    await freshDrag.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 1);
  });

  testWidgets('a changed navigation target invalidates a held drag', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.zoomAtRightEdge();
    await tester.pump();

    final drag = await tester.startGesture(harness.center);
    await drag.moveBy(const Offset(-170, 0));
    harness.nextActionId = 2;
    await tester.pumpWidget(harness.build());
    await drag.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 0);
  });

  testWidgets('a second pointer cancels navigation without stealing pinch', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.zoomAtRightEdge();
    await tester.pump(const Duration(milliseconds: 100));

    final first = await tester.startGesture(harness.center, pointer: 1);
    final second = await tester.startGesture(
      harness.center + const Offset(50, 0),
      pointer: 2,
    );
    await first.moveBy(const Offset(-170, 0));
    await second.moveBy(const Offset(170, 0));
    await first.up();
    await second.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 0);
  });

  for (final state in ['zoom', 'page', 'sheet', 'settled page']) {
    testWidgets('a $state change during the drag cancels navigation', (
      tester,
    ) async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await _mount(tester, harness);
      harness.zoomAtRightEdge();
      await tester.pump(const Duration(milliseconds: 100));

      final drag = await tester.startGesture(harness.center);
      await drag.moveBy(const Offset(-170, 0));
      switch (state) {
        case 'zoom':
          harness.controller.zoom.value = false;
          harness.controller.zoom.value = true;
        case 'page':
          harness.controller.currentPage.value = 1;
          harness.controller.currentPage.value = 0;
        case 'sheet':
          harness.controller.sheetState.value = SheetState.expanded;
          harness.controller.sheetState.value = SheetState.collapsed;
        case 'settled page':
          harness.settled.value = 1;
          harness.settled.value = 0;
      }
      await tester.pump(const Duration(milliseconds: 100));
      await drag.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(harness.nextCount, 0);
    });
  }

  testWidgets('hidden toolbar and auto-fitted comics still navigate', (
    tester,
  ) async {
    final harness = _Harness(contentSize: const Size(100, 401));
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.transform.onPageSettled(0);
    expect(
      harness.transform.tryAutoStartComicStrip(
        postId: 1,
        contentSize: harness.contentSize,
        enabled: true,
      ),
      isTrue,
    );
    harness.controller.zoom.value = true;
    harness.controller.hideOverlay();
    await tester.pump(const Duration(milliseconds: 100));

    expect(harness.controller.overlay.value, isFalse);
    final verticalBefore = harness.matrix.value.getTranslation().y;
    final scroll = await tester.startGesture(harness.center);
    await scroll.moveBy(const Offset(0, -100));
    await scroll.moveBy(const Offset(0, -100));
    await scroll.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.matrix.value.getTranslation().y, lessThan(verticalBefore));
    expect(harness.nextCount, 0);
    final drag = await tester.startGesture(harness.center);
    await drag.moveBy(const Offset(-170, 0));
    await drag.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 1);
  });

  testWidgets(
    'unzoomed, expanded, non-image, and notes contexts do not navigate',
    (
      tester,
    ) async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await _mount(tester, harness);
      Future<void> drag() async {
        final gesture = await tester.startGesture(harness.center);
        await gesture.moveBy(const Offset(-170, 0));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 100));
      }

      await drag();
      expect(harness.nextCount, 0);

      harness.zoomAtRightEdge();
      harness.controller.sheetState.value = SheetState.expanded;
      await tester.pump(const Duration(milliseconds: 100));
      await drag();
      expect(harness.nextCount, 0);

      harness.controller.sheetState.value = SheetState.collapsed;
      harness.enabled = false;
      await _mount(tester, harness);
      await drag();
      expect(harness.nextCount, 0);
    },
  );

  testWidgets('the relevant physical edge respects right-to-left paging', (
    tester,
  ) async {
    final harness = _Harness(direction: TextDirection.rtl);
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.zoomAtLeftEdge();
    await tester.pump(const Duration(milliseconds: 100));

    final next = await tester.startGesture(harness.center);
    await next.moveBy(const Offset(170, 0));
    await next.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.nextCount, 1);
    expect(harness.previousCount, 0);

    harness.zoomAtRightEdge();
    await tester.pump(const Duration(milliseconds: 100));
    final previous = await tester.startGesture(harness.center);
    await previous.moveBy(const Offset(-170, 0));
    await previous.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.previousCount, 1);
  });

  testWidgets(
    'an unavailable Next bound has no gesture or screen-reader action',
    (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final harness = _Harness(hasNext: false);
      addTearDown(harness.dispose);
      await _mount(tester, harness);
      harness.zoomAtRightEdge();
      await tester.pump(const Duration(milliseconds: 100));

      final drag = await tester.startGesture(harness.center);
      await drag.moveBy(const Offset(-170, 0));
      await drag.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(harness.nextCount, 0);
      expect(_action('Next page'), findsNothing);
      expect(_action('Previous page'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('screen-reader actions navigate without visible controls', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final harness = _Harness();
    addTearDown(harness.dispose);
    await _mount(tester, harness);
    harness.zoomAtRightEdge();
    await tester.pump(const Duration(milliseconds: 100));

    expect(_action('Next page'), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
    final node = tester.getSemantics(_action('Next page'));
    final actionId = CustomSemanticsAction.getIdentifier(
      const CustomSemanticsAction(label: 'Next page'),
    );
    expect(
      node.getSemanticsData().customSemanticsActionIds,
      contains(actionId),
    );
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      actionId,
    );
    expect(harness.nextCount, 1);
    semantics.dispose();
  });
}

Finder _action(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      (widget.properties.customSemanticsActions?.keys.any(
            (action) => action.label == label,
          ) ??
          false),
);

Future<void> _mount(WidgetTester tester, _Harness harness) async {
  tester.view.physicalSize = harness.size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(harness.build());
}

class _Harness {
  _Harness({
    this.size = const Size(800, 1200),
    this.contentSize = const Size(100, 100),
    this.direction = TextDirection.ltr,
    this.hasNext = true,
  }) : controller = PostDetailsPageViewController(
         initialPage: 0,
         totalPage: 2,
         checkIfLargeScreen: () => size.width >= 800,
         disableAnimation: true,
       ),
       matrix = TransformationController() {
    transform = PostViewerTransformationController(matrix)..viewportSize = size;
  }

  final Size size;
  final Size contentSize;
  final TextDirection direction;
  bool hasNext;
  var nextActionId = 1;
  final PostDetailsPageViewController controller;
  final TransformationController matrix;
  final settled = ValueNotifier<int?>(0);
  late final PostViewerTransformationController transform;
  var enabled = true;
  var nextCount = 0;
  var previousCount = 0;

  Offset get center => Offset(size.width / 2, size.height / 2);

  Widget build() => MaterialApp(
    home: Scaffold(
      body: Directionality(
        textDirection: direction,
        child: Center(
          child: SizedBox.fromSize(
            size: size,
            child: ZoomEdgePageGesture(
              transform: transform,
              pageController: controller,
              currentSettledPage: settled,
              pageIndex: 0,
              contentSize: contentSize,
              enabled: enabled,
              navigation: ZoomPageNavigationScope(
                previousLabel: 'Previous page',
                nextLabel: 'Next page',
                previousActionId: -1,
                nextActionId: hasNext ? nextActionId : null,
                onPrevious: () => previousCount++,
                onNext: hasNext ? () => nextCount++ : null,
                child: const SizedBox.shrink(),
              ),
              child: KurumiInteractiveViewer(
                controller: matrix,
                contentSize: contentSize,
                constrainPanToContent: true,
                onTransformationChanged: controller.onTransformationChanged,
                child: const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  void zoomAtRightEdge() => _zoomAt(-size.width, -400);
  void zoomAtLeftEdge() => _zoomAt(0, -400);
  void zoomAtCenter() => _zoomAt(-size.width / 2, -400);

  void _zoomAt(double x, double y) {
    matrix.value = Matrix4.diagonal3Values(2, 2, 1)..setTranslationRaw(x, y, 0);
    controller.zoom.value = true;
  }

  void dispose() {
    settled.dispose();
    matrix.dispose();
    controller.dispose();
  }
}
