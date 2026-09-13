// Flutter imports:
import 'package:flutter/material.dart';

// Flutter test imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/posts/details/src/types/post_viewer_transformation_controller.dart';

void main() {
  const viewportSize = Size(400, 800);
  const tallContentSize = Size(1000, 4000);

  test('fitting to width preserves the visible vertical center', () {
    final transformationController = _transformationController(
      Matrix4.identity()
        ..translateByDouble(-20, -100, 0, 1)
        ..scaleByDouble(1.5, 1.5, 1.5, 1),
    );
    final controller = PostViewerTransformationController(
      transformationController,
    )..viewportSize = viewportSize;
    final center = viewportSize.center(Offset.zero);
    final visibleCenterBefore = transformationController.toScene(center);

    controller.fitToWidth(tallContentSize);

    final visibleCenterAfter = transformationController.toScene(center);
    expect(
      transformationController.value.getMaxScaleOnAxis(),
      closeTo(2, 0.001),
    );
    expect(visibleCenterAfter.dy, closeTo(visibleCenterBefore.dy, 0.001));
    expect(
      transformationController.value.getTranslation().x,
      closeTo(-200, 0.001),
    );
  });

  test('scrolling to top preserves zoom and horizontal position', () {
    final transformationController = _transformationController(
      Matrix4.identity()
        ..translateByDouble(-350, -500, 0, 1)
        ..scaleByDouble(3, 3, 3, 1),
    );
    final controller = PostViewerTransformationController(
      transformationController,
    )..viewportSize = viewportSize;

    controller.scrollToTop(tallContentSize);

    final matrix = transformationController.value;
    expect(matrix.getMaxScaleOnAxis(), closeTo(3, 0.001));
    expect(matrix.getTranslation().x, closeTo(-350, 0.001));
    expect(matrix.getTranslation().y, closeTo(0, 0.001));
  });

  test('comic-strip start fits the image width and shows its top', () {
    final transformationController = _transformationController(
      Matrix4.identity()
        ..translateByDouble(-50, -300, 0, 1)
        ..scaleByDouble(1.25, 1.25, 1.25, 1),
    );
    final controller = PostViewerTransformationController(
      transformationController,
    )..viewportSize = viewportSize;

    controller.startComicStrip(tallContentSize);

    final matrix = transformationController.value;
    expect(matrix.getMaxScaleOnAxis(), closeTo(2, 0.001));
    expect(matrix.getTranslation().x, closeTo(-200, 0.001));
    expect(matrix.getTranslation().y, closeTo(0, 0.001));
  });

  test(
    'commands leave the transformation unchanged without a valid viewport',
    () {
      final initialMatrix = Matrix4.identity()
        ..translateByDouble(-20, -100, 0, 1)
        ..scaleByDouble(1.5, 1.5, 1.5, 1);
      final transformationController = _transformationController(initialMatrix);
      final controller = PostViewerTransformationController(
        transformationController,
      );

      controller
        ..fitToWidth(tallContentSize)
        ..scrollToTop(tallContentSize)
        ..startComicStrip(tallContentSize);

      expect(transformationController.value, initialMatrix);
    },
  );
}

TransformationController _transformationController([Matrix4? value]) {
  final controller = TransformationController(value);
  addTearDown(controller.dispose);
  return controller;
}
