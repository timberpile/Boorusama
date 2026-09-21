// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:kurumi/kurumi.dart';

void main() {
  testWidgets(
    'centers a fitting width while preserving vertical movement',
    (tester) async {
      final controller = await _pumpViewer(
        tester,
        contentSize: const Size(500, 3000),
      );

      controller.value = _transformation(
        scale: 2,
        x: 100,
        y: -200,
      );
      await tester.pump();

      _expectTranslation(controller, x: -500, y: -200);
    },
  );

  testWidgets(
    'centers a fitting height while preserving horizontal movement',
    (tester) async {
      final controller = await _pumpViewer(
        tester,
        contentSize: const Size(3000, 500),
      );

      controller.value = _transformation(
        scale: 2,
        x: -200,
        y: 100,
      );
      await tester.pump();

      _expectTranslation(controller, x: -200, y: -500);
    },
  );

  testWidgets('preserves valid movement when both axes overflow', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(1000, 1000),
    );

    controller.value = _transformation(
      scale: 2,
      x: -250,
      y: -750,
    );
    await tester.pump();

    _expectTranslation(controller, x: -250, y: -750);
  });

  testWidgets('clamps overflowing content to its nearest edge', (tester) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(500, 3000),
    );

    controller.value = _transformation(scale: 2, x: 100, y: 200);
    await tester.pump();
    _expectTranslation(controller, x: -500, y: 0);

    controller.value = _transformation(scale: 2, x: 100, y: -1200);
    await tester.pump();
    _expectTranslation(controller, x: -500, y: -1000);
  });

  testWidgets('preserves current behavior when constraints are disabled', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(500, 3000),
      constrainPanToContent: false,
    );

    controller.value = _transformation(scale: 2, x: 100, y: -200);
    await tester.pump();

    _expectTranslation(controller, x: 100, y: -200);
  });

  testWidgets('ignores absent content dimensions', (tester) async {
    final controller = await _pumpViewer(tester, contentSize: null);

    controller.value = _transformation(scale: 2, x: 100, y: -200);
    await tester.pump();

    _expectTranslation(controller, x: 100, y: -200);
  });

  testWidgets('ignores invalid content dimensions', (tester) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: Size.zero,
    );

    controller.value = _transformation(scale: 2, x: 100, y: -200);
    await tester.pump();

    _expectTranslation(controller, x: 100, y: -200);
  });

  testWidgets('recenters fitting content after the viewport resizes', (
    tester,
  ) async {
    final controller = TransformationController();
    addTearDown(controller.dispose);
    await _pumpViewer(
      tester,
      controller: controller,
      contentSize: const Size(500, 3000),
    );
    controller.value = _transformation(scale: 2, x: -500, y: -200);
    await tester.pump();

    await _pumpViewer(
      tester,
      controller: controller,
      viewportSize: const Size(1200, 1000),
      contentSize: const Size(500, 3000),
    );
    await tester.pump();

    _expectTranslation(controller, x: -600, y: -200);
  });

  testWidgets('reapplies bounds after intrinsic content dimensions change', (
    tester,
  ) async {
    final controller = TransformationController();
    addTearDown(controller.dispose);
    await _pumpViewer(
      tester,
      controller: controller,
      contentSize: const Size(500, 3000),
    );
    controller.value = _transformation(scale: 2, x: -500, y: -200);
    await tester.pump();

    await _pumpViewer(
      tester,
      controller: controller,
      contentSize: const Size(3000, 500),
    );
    await tester.pump();

    _expectTranslation(controller, x: -500, y: -500);
  });

  for (final scale in [5.7, 6.3]) {
    testWidgets('snaps an inclusive width threshold at scale $scale', (
      tester,
    ) async {
      final controller = await _pumpViewer(
        tester,
        contentSize: const Size(500, 3000),
        snapZoomToFit: true,
      );

      _startInteraction(tester);
      controller.value = _transformation(scale: scale, x: -200, y: -400);
      await tester.pump();
      expect(controller.value.getMaxScaleOnAxis(), closeTo(scale, 0.001));

      await _endInteraction(tester);

      expect(controller.value.getMaxScaleOnAxis(), closeTo(6, 0.001));
    });
  }

  testWidgets('snaps a near-fit height to the viewport height', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(3000, 500),
      snapZoomToFit: true,
    );

    _startInteraction(tester);
    controller.value = _transformation(scale: 5.8, x: -400, y: -200);
    await tester.pump();

    await _endInteraction(tester);

    expect(controller.value.getMaxScaleOnAxis(), closeTo(6, 0.001));
    expect(controller.value.entry(0, 0), closeTo(6, 0.001));
    expect(controller.value.entry(1, 1), closeTo(6, 0.001));
  });

  for (final scale in [5.69, 6.31]) {
    testWidgets('does not snap outside the threshold at scale $scale', (
      tester,
    ) async {
      final controller = await _pumpViewer(
        tester,
        contentSize: const Size(500, 3000),
        snapZoomToFit: true,
      );

      _startInteraction(tester);
      controller.value = _transformation(scale: scale, x: -200, y: -400);
      await tester.pump();

      await _endInteraction(tester);

      expect(controller.value.getMaxScaleOnAxis(), closeTo(scale, 0.001));
    });
  }

  testWidgets('snaps the proportionally closer dimension when both qualify', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(1000, 1020),
      snapZoomToFit: true,
    );

    _startInteraction(tester);
    controller.value = _transformation(scale: 1.04, x: -20, y: -20);
    await tester.pump();

    await _endInteraction(tester);

    expect(controller.value.getMaxScaleOnAxis(), closeTo(1.02, 0.001));
  });

  testWidgets('leaves near-fit zoom unchanged before the interaction ends', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(500, 3000),
      snapZoomToFit: true,
    );

    _startInteraction(tester);
    controller.value = _transformation(scale: 5.8, x: -200, y: -400);
    await tester.pump();

    expect(controller.value.getMaxScaleOnAxis(), closeTo(5.8, 0.001));
  });

  testWidgets('leaves the selected zoom unchanged when snapping is disabled', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(500, 3000),
      snapZoomToFit: false,
    );

    _startInteraction(tester);
    controller.value = _transformation(scale: 5.8, x: -200, y: -400);
    await tester.pump();

    await _endInteraction(tester);

    expect(controller.value.getMaxScaleOnAxis(), closeTo(5.8, 0.001));
  });

  testWidgets('does not snap when an interaction ends without scaling', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(500, 3000),
      snapZoomToFit: true,
    );
    controller.value = _transformation(scale: 5.8, x: -200, y: -400);
    await tester.pump();

    _startInteraction(tester);
    await _endInteraction(tester);

    expect(controller.value.getMaxScaleOnAxis(), closeTo(5.8, 0.001));
  });

  testWidgets('waits for post-pinch scale movement to settle before snapping', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(500, 3000),
      snapZoomToFit: true,
    );

    _startInteraction(tester);
    controller.value = _transformation(scale: 5.8, x: -200, y: -400);
    _endInteractionCallback(tester);
    controller.value = _transformation(scale: 5.9, x: -200, y: -400);
    await tester.pump(const Duration(milliseconds: 25));
    controller.value = _transformation(scale: 6.1, x: -200, y: -400);
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.value.getMaxScaleOnAxis(), closeTo(6, 0.001));
  });

  testWidgets('does not snap scale changes from a one-pointer interaction', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(500, 3000),
      snapZoomToFit: true,
    );

    _startInteraction(tester, pointerCount: 1);
    controller.value = _transformation(scale: 5.8, x: -200, y: -400);
    await _endInteraction(tester);

    expect(controller.value.getMaxScaleOnAxis(), closeTo(5.8, 0.001));
  });

  testWidgets('does not snap beyond the existing maximum scale', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(1200, 190),
      snapZoomToFit: true,
    );

    _startInteraction(tester);
    controller.value = _transformation(scale: 6, x: -200, y: -20);
    await _endInteraction(tester);

    expect(controller.value.getMaxScaleOnAxis(), closeTo(6, 0.001));
  });

  testWidgets('snaps a fitting dimension from below identity scale', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(1000, 1000),
      snapZoomToFit: true,
    );
    controller.value = _transformation(scale: 0.9, x: 40, y: 40);

    _startInteraction(tester);
    controller.value = _transformation(scale: 0.95, x: 25, y: 25);
    await _endInteraction(tester);

    expect(controller.value.entry(0, 0), closeTo(1, 0.001));
    expect(controller.value.entry(1, 1), closeTo(1, 0.001));
  });

  testWidgets('snaps after a real two-pointer pinch ends', (tester) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(1000, 1000),
      snapZoomToFit: true,
    );
    final first = await tester.startGesture(
      const Offset(120, 500),
      pointer: 1,
    );
    final second = await tester.startGesture(
      const Offset(880, 500),
      pointer: 2,
    );
    await tester.pump();

    await first.moveTo(const Offset(101, 500));
    await second.moveTo(const Offset(899, 500));
    await tester.pump();
    expect(controller.value.entry(0, 0), closeTo(1.05, 0.01));

    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    expect(controller.value.entry(0, 0), closeTo(1, 0.001));
    expect(controller.value.entry(1, 1), closeTo(1, 0.001));
  });
}

Matrix4 _transformation({
  required double scale,
  required double x,
  required double y,
}) => Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(x, y, 0);

Future<TransformationController> _pumpViewer(
  WidgetTester tester, {
  required Size? contentSize,
  TransformationController? controller,
  Size viewportSize = const Size(1000, 1000),
  bool constrainPanToContent = true,
  bool snapZoomToFit = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewportSize;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final viewerController = controller ?? TransformationController();
  if (controller == null) addTearDown(viewerController.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: KurumiInteractiveViewer(
        controller: viewerController,
        contentSize: contentSize,
        constrainPanToContent: constrainPanToContent,
        snapZoomToFit: snapZoomToFit,
        child: const SizedBox.expand(),
      ),
    ),
  );

  return viewerController;
}

Future<void> _endInteraction(WidgetTester tester) async {
  _endInteractionCallback(tester);
  await tester.pump(const Duration(milliseconds: 100));
}

void _endInteractionCallback(WidgetTester tester) {
  final viewer = tester.widget<InteractiveViewer>(
    find.byType(InteractiveViewer),
  );
  viewer.onInteractionEnd!(ScaleEndDetails());
}

void _startInteraction(WidgetTester tester, {int pointerCount = 2}) {
  final viewer = tester.widget<InteractiveViewer>(
    find.byType(InteractiveViewer),
  );
  viewer.onInteractionStart!(ScaleStartDetails());
  viewer.onInteractionUpdate!(ScaleUpdateDetails(pointerCount: pointerCount));
}

void _expectTranslation(
  TransformationController controller, {
  required double x,
  required double y,
}) {
  final translation = controller.value.getTranslation();
  expect(translation.x, closeTo(x, 0.001));
  expect(translation.y, closeTo(y, 0.001));
}
