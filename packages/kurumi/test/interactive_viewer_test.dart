// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/src/vendor/flutter/interactive_viewer.dart' as vendor;

void main() {
  testWidgets('toggling interactions retains a stateful media child', (
    tester,
  ) async {
    Future<void> pump(bool enabled) => tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 180,
          child: KurumiInteractiveViewer(
            enable: enabled,
            onTap: () {},
            child: const _Media(),
          ),
        ),
      ),
    );
    await pump(true);
    final original = tester.state<_MediaState>(find.byType(_Media));
    original.position = const Duration(seconds: 17);
    original.playing = true;
    await pump(false);
    expect(tester.state<_MediaState>(find.byType(_Media)), same(original));
    expect(
      tester.state<_MediaState>(find.byType(_Media)).position,
      const Duration(seconds: 17),
    );
    expect(tester.state<_MediaState>(find.byType(_Media)).playing, isTrue);
    await pump(true);
    expect(tester.state<_MediaState>(find.byType(_Media)), same(original));
    expect(
      tester.state<_MediaState>(find.byType(_Media)).position,
      const Duration(seconds: 17),
    );
    expect(tester.state<_MediaState>(find.byType(_Media)).playing, isTrue);
  });

  testWidgets('preserves the classic zoom and reset behavior', (tester) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(1000, 6000),
    );

    await _doubleTap(tester);
    expect(controller.value.getMaxScaleOnAxis(), closeTo(6, 0.001));

    await _doubleTap(tester);
    expect(controller.value.isIdentity(), isTrue);
  });

  for (final testCase in [
    (
      name: 'ordinary portrait',
      image: const Size(1200, 1800),
      zoom: 2.2515439657,
    ),
    (
      name: 'square image',
      image: const Size(1000, 1000),
      zoom: 2.45,
    ),
    (
      name: 'very tall comic',
      image: const Size(1000, 4000),
      zoom: 1.8181818,
    ),
    (
      name: 'very wide panorama',
      image: const Size(4000, 1000),
      zoom: 4.4,
    ),
  ]) {
    testWidgets(
      'Classic zooms a ${testCase.name} conservatively in portrait',
      (tester) async {
        final controller = await _pumpViewer(
          tester,
          contentSize: testCase.image,
          viewportSize: const Size(400, 880),
        );
        await _doubleTap(tester, position: const Offset(200, 440));
        expect(
          controller.value.getMaxScaleOnAxis(),
          closeTo(testCase.zoom, 0.001),
        );
        await _doubleTap(tester, position: const Offset(200, 440));
        expect(controller.value.isIdentity(), isTrue);
      },
    );
  }

  for (final testCase in [
    (
      name: 'ordinary portrait',
      image: const Size(1200, 1800),
      zoom: 2.5,
    ),
    (
      name: 'square image',
      image: const Size(1000, 1000),
      zoom: 2.2,
    ),
    (
      name: 'very tall comic',
      image: const Size(1000, 4000),
      zoom: 4.0,
    ),
    (
      name: 'wide panorama',
      image: const Size(4400, 1000),
      zoom: 2.0,
    ),
    (
      name: 'extra-wide panorama is not capped at ordinary 2.5x',
      image: const Size(10000, 1000),
      zoom: 10 / 2.2,
    ),
    (
      name: 'matching landscape image still zooms visibly',
      image: const Size(2200, 1000),
      zoom: 1.15,
    ),
    (
      name: 'just below the panorama transition',
      image: const Size(2399, 1000),
      zoom: 1.15,
    ),
    (
      name: 'just above the panorama transition',
      image: const Size(2401, 1000),
      zoom: 1.15,
    ),
  ]) {
    testWidgets(
      'Classic uses ${testCase.name} geometry in landscape',
      (tester) async {
        final controller = await _pumpViewer(
          tester,
          contentSize: testCase.image,
          viewportSize: const Size(880, 400),
        );
        await _doubleTap(tester, position: const Offset(440, 200));
        expect(
          controller.value.getMaxScaleOnAxis(),
          closeTo(testCase.zoom, 0.001),
        );
        await _doubleTap(tester, position: const Offset(440, 200));
        expect(controller.value.isIdentity(), isTrue);
      },
    );
  }

  testWidgets('Classic does not snap upward to the other dimension', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(1100, 1000),
      viewportSize: const Size(400, 880),
    );

    await _doubleTap(tester, position: const Offset(200, 440));

    // The detail target is ~2.403x, while the nearby fit is 2.42x.
    // The target must not be enlarged by automatic snapping.
    expect(controller.value.getMaxScaleOnAxis(), closeTo(2.402866, 0.001));
    await _doubleTap(tester, position: const Offset(200, 440));
    expect(controller.value.isIdentity(), isTrue);
  });

  testWidgets('Classic still snaps downward to avoid two-axis panning', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(1020, 1000),
      viewportSize: const Size(400, 880),
    );

    await _doubleTap(tester, position: const Offset(200, 440));

    // The raw target is ~2.448x; 2.244x fits the image height exactly.
    // Snapping down is within 10% and avoids unnecessary 2D panning.
    expect(controller.value.getMaxScaleOnAxis(), closeTo(2.244, 0.001));
  });

  testWidgets('Classic preserves the tap point during detail zoom', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(1000, 1000),
      viewportSize: const Size(400, 880),
      constrainPanToContent: false,
    );
    const point = Offset(150, 350);
    final originalPoint = controller.toScene(point);
    await _doubleTap(tester, position: point);
    expect(controller.toScene(point).dx, closeTo(originalPoint.dx, 0.001));
    expect(controller.toScene(point).dy, closeTo(originalPoint.dy, 0.001));
  });

  testWidgets('Classic resets a manually zoomed image directly', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(1200, 1800),
      viewportSize: const Size(400, 880),
      constrainPanToContent: false,
    );
    controller.value = _transformation(scale: 2, x: -100, y: -200);
    await tester.pump();
    await _doubleTap(tester, position: const Offset(200, 440));
    expect(controller.value.isIdentity(), isTrue);
  });

  testWidgets('Classic restores a pre-existing Comic reading position', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(1000, 10000),
      viewportSize: const Size(400, 880),
      constrainPanToContent: false,
    );
    final widthFit = (400 / 880) / 0.1;
    final baseline = _transformation(
      scale: widthFit,
      x: -150,
      y: -500,
    );
    controller.value = baseline;
    await tester.pump();

    await _doubleTap(tester, position: const Offset(200, 440));
    expect(
      controller.value.getMaxScaleOnAxis(),
      closeTo(widthFit * 2.0, 0.001),
    );
    await _doubleTap(tester, position: const Offset(200, 440));
    expect(controller.value.entry(0, 0), closeTo(widthFit, 0.001));
    _expectTranslation(controller, x: -150, y: -500);
  });

  testWidgets('Classic restores Comic position after the image size changes', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(500, 5000),
      viewportSize: const Size(400, 880),
      constrainPanToContent: false,
    );
    final baseline = _transformation(
      scale: (400 / 880) / 0.1,
      x: -150,
      y: -500,
    );
    controller.value = baseline;
    await tester.pump();
    await _doubleTap(tester, position: const Offset(200, 440));

    await _pumpViewer(
      tester,
      controller: controller,
      contentSize: const Size(1000, 10000),
      viewportSize: const Size(400, 880),
      constrainPanToContent: false,
    );
    await _doubleTap(tester, position: const Offset(200, 440));

    expect(controller.value.entry(0, 0), closeTo(baseline.entry(0, 0), 0.001));
    _expectTranslation(controller, x: -150, y: -500);
  });

  testWidgets('Classic shows a square-ish tall image in Comic landscape', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(1000, 10000),
      viewportSize: const Size(880, 400),
      constrainPanToContent: false,
    );
    final baseline = _transformation(scale: 22, x: -100, y: -1000);
    controller.value = baseline;
    await tester.pump();

    await _doubleTap(tester, position: const Offset(440, 200));
    expect(controller.value.getMaxScaleOnAxis(), closeTo(10, 0.001));
    await _doubleTap(tester, position: const Offset(440, 200));
    expect(controller.value.getMaxScaleOnAxis(), closeTo(22, 0.001));
    _expectTranslation(controller, x: -100, y: -1000);
  });

  testWidgets('Classic falls back safely when content size is missing', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: null,
    );
    await _doubleTap(tester);
    expect(controller.value.getMaxScaleOnAxis(), closeTo(3, 0.001));
    await _doubleTap(tester);
    expect(controller.value.isIdentity(), isTrue);
  });

  for (final image in [const Size(1000, 4000), const Size(1000, 3000)]) {
    testWidgets('Classic still zooms tall media in a narrow viewport: $image', (
      tester,
    ) async {
      final controller = await _pumpViewer(
        tester,
        contentSize: image,
        viewportSize: const Size(320, 1280),
      );
      await _doubleTap(tester, position: const Offset(160, 640));
      expect(controller.value.getMaxScaleOnAxis(), greaterThanOrEqualTo(1.15));
      await _doubleTap(tester, position: const Offset(160, 640));
      expect(controller.value.isIdentity(), isTrue);
    });
  }

  testWidgets('tiny decoded images can be displayed and zoomed', (
    tester,
  ) async {
    final controller = await _pumpViewer(
      tester,
      contentSize: const Size(1, 1),
      viewportSize: const Size(400, 880),
    );

    expect(tester.takeException(), isNull);
    await _doubleTap(tester, position: const Offset(200, 440));
    expect(controller.value.getMaxScaleOnAxis(), closeTo(2.45, 0.001));
    await _doubleTap(tester, position: const Offset(200, 440));
    expect(controller.value.isIdentity(), isTrue);
  });

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

  for (final scale in [5.43, 6.57]) {
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

  for (final scale in [5.39, 6.61]) {
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
    expect(controller.value.entry(2, 2), closeTo(1, 0.001));
  });

  testWidgets('snaps after a pinch continues as a one-finger pan', (
    tester,
  ) async {
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
    await first.up();
    await tester.pump();
    await second.moveBy(const Offset(-30, 0));
    await tester.pump();
    await second.up();
    await tester.pumpAndSettle();

    expect(controller.value.entry(0, 0), closeTo(1, 0.001));
    expect(controller.value.entry(1, 1), closeTo(1, 0.001));
    expect(controller.value.entry(2, 2), closeTo(1, 0.001));
  });
}

Matrix4 _transformation({
  required double scale,
  required double x,
  required double y,
}) => Matrix4.diagonal3Values(scale, scale, scale)..setTranslationRaw(x, y, 0);

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

Future<void> _doubleTap(
  WidgetTester tester, {
  Offset position = const Offset(500, 500),
}) async {
  final detector = tester.widget<GestureDetector>(
    find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onDoubleTap != null,
    ),
  );
  detector.onDoubleTapDown!(TapDownDetails(localPosition: position));
  detector.onDoubleTap!();
  await tester.pumpAndSettle();
}

Future<void> _endInteraction(WidgetTester tester) async {
  _endInteractionCallback(tester);
  await tester.pump(const Duration(milliseconds: 100));
}

void _endInteractionCallback(WidgetTester tester) {
  final viewer = tester.widget<vendor.InteractiveViewer>(
    find.byType(vendor.InteractiveViewer),
  );
  viewer.onInteractionEnd!(ScaleEndDetails());
}

void _startInteraction(WidgetTester tester, {int pointerCount = 2}) {
  final viewer = tester.widget<vendor.InteractiveViewer>(
    find.byType(vendor.InteractiveViewer),
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

class _Media extends StatefulWidget {
  const _Media();
  @override
  State<_Media> createState() => _MediaState();
}

class _MediaState extends State<_Media> {
  Duration position = Duration.zero;
  bool playing = false;
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
