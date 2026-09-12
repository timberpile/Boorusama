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
        child: const SizedBox.expand(),
      ),
    ),
  );

  return viewerController;
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
