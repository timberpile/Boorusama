// Flutter imports:
import 'package:flutter/material.dart';

// Flutter test imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/posts/details/src/types/post_viewer_transformation_controller.dart';

void main() {
  const viewportSize = Size(400, 800);

  test('automatically starts only above the comic-strip aspect threshold', () {
    final transformationController = _transformationController();
    final controller = PostViewerTransformationController(
      transformationController,
    )..viewportSize = viewportSize;

    final boundaryStarted = controller.tryAutoStartComicStrip(
      postId: 1,
      contentSize: const Size(1000, 4000),
      enabled: true,
    );
    final tallerStarted = controller.tryAutoStartComicStrip(
      postId: 2,
      contentSize: const Size(1000, 4001),
      enabled: true,
    );

    expect(boundaryStarted, isFalse);
    expect(tallerStarted, isTrue);
  });

  test('automatically starts a detected comic strip once per page visit', () {
    final transformationController = _transformationController();
    final controller = PostViewerTransformationController(
      transformationController,
    )..viewportSize = viewportSize;

    controller.onPageSettled(0);

    final firstStarted = controller.tryAutoStartComicStrip(
      postId: 1,
      contentSize: const Size(1000, 4001),
      enabled: true,
    );
    transformationController.value = Matrix4.identity();
    controller.onPageSettled(0);
    final secondStarted = controller.tryAutoStartComicStrip(
      postId: 1,
      contentSize: const Size(1000, 4001),
      enabled: true,
    );

    expect(firstStarted, isTrue);
    expect(secondStarted, isFalse);
    expect(transformationController.value, Matrix4.identity());
  });

  test('reapplies comic fit when returning to a settled post', () {
    final transformationController = _transformationController();
    final controller = PostViewerTransformationController(
      transformationController,
    )..viewportSize = viewportSize;

    controller.onPageSettled(0);
    expect(
      controller.tryAutoStartComicStrip(
        postId: 1,
        contentSize: const Size(1000, 4001),
        enabled: true,
      ),
      isTrue,
    );

    controller.onPageSettled(1);
    expect(transformationController.value, Matrix4.identity());

    controller.onPageSettled(0);
    expect(
      controller.tryAutoStartComicStrip(
        postId: 1,
        contentSize: const Size(1000, 4001),
        enabled: true,
      ),
      isTrue,
    );
    expect(
      transformationController.value.getMaxScaleOnAxis(),
      closeTo(2.0005, 0.001),
    );
  });

  test('fits different settled posts with the same numeric ID', () {
    final transformationController = _transformationController();
    final controller = PostViewerTransformationController(
      transformationController,
    )..viewportSize = viewportSize;

    controller.onPageSettled(0);
    expect(
      controller.tryAutoStartComicStrip(
        postId: 42,
        contentSize: const Size(1000, 4001),
        enabled: true,
      ),
      isTrue,
    );

    controller.onPageSettled(1);
    expect(transformationController.value, Matrix4.identity());
    expect(
      controller.tryAutoStartComicStrip(
        postId: 42,
        contentSize: const Size(1000, 5000),
        enabled: true,
      ),
      isTrue,
    );
    expect(
      transformationController.value.getMaxScaleOnAxis(),
      closeTo(2.5, 0.001),
    );
  });

  test(
    'disabled automatic mode consumes the post load without repositioning',
    () {
      final transformationController = _transformationController();
      final controller = PostViewerTransformationController(
        transformationController,
      )..viewportSize = viewportSize;

      final disabledStarted = controller.tryAutoStartComicStrip(
        postId: 1,
        contentSize: const Size(1000, 4001),
        enabled: false,
      );
      final laterStarted = controller.tryAutoStartComicStrip(
        postId: 1,
        contentSize: const Size(1000, 4001),
        enabled: true,
      );

      expect(disabledStarted, isFalse);
      expect(laterStarted, isFalse);
      expect(transformationController.value, Matrix4.identity());
    },
  );

  test(
    'automatic mode waits for valid viewer geometry before handling a post',
    () {
      final initialMatrix = Matrix4.identity()
        ..translateByDouble(-20, -100, 0, 1)
        ..scaleByDouble(1.5, 1.5, 1.5, 1);
      final transformationController = _transformationController(initialMatrix);
      final controller = PostViewerTransformationController(
        transformationController,
      );

      final started = controller.tryAutoStartComicStrip(
        postId: 1,
        contentSize: const Size(1000, 4001),
        enabled: true,
      );

      expect(started, isFalse);
      expect(transformationController.value, initialMatrix);
    },
  );
}

TransformationController _transformationController([Matrix4? value]) {
  final controller = TransformationController(value);
  addTearDown(controller.dispose);
  return controller;
}
