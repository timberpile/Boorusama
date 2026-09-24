// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';

// Project imports:
import 'package:boorusama/core/haptics/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/widgets/interactive_viewer_extended.dart';

void main() {
  for (final testCase in [
    (mode: DoubleTapZoomMode.classic, expectedScale: 1.0),
    (mode: DoubleTapZoomMode.fitCycle, expectedScale: 18.0),
  ]) {
    testWidgets(
      'uses the selected ${testCase.mode.name} double-tap zoom behavior',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1000, 1000);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final controller = TransformationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hapticFeedbackLevelProvider.overrideWithValue(
                HapticFeedbackLevel.none,
              ),
            ],
            child: MaterialApp(
              home: InteractiveViewerExtended(
                controller: controller,
                contentSize: const Size(1000, 6000),
                doubleTapZoomMode: testCase.mode,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );

        await _doubleTap(tester);
        await _doubleTap(tester);

        expect(
          controller.value.getMaxScaleOnAxis(),
          closeTo(testCase.expectedScale, 0.001),
        );
      },
    );
  }

  testWidgets('forwards content-aware panning to Kurumi', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = TransformationController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hapticFeedbackLevelProvider.overrideWithValue(
            HapticFeedbackLevel.none,
          ),
        ],
        child: MaterialApp(
          home: InteractiveViewerExtended(
            controller: controller,
            contentSize: const Size(500, 3000),
            constrainPanToContent: true,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    controller.value = Matrix4.diagonal3Values(2, 2, 1)
      ..setTranslationRaw(100, -200, 0);
    await tester.pump();

    final translation = controller.value.getTranslation();
    expect(translation.x, closeTo(-500, 0.001));
    expect(translation.y, closeTo(-200, 0.001));
  });

  for (final testCase in [
    (enabled: false, expectedScale: 5.8),
    (enabled: true, expectedScale: 6.0),
  ]) {
    testWidgets(
      'uses snap zoom ${testCase.enabled ? 'when enabled' : 'only when opted in'}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1000, 1000);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final controller = TransformationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hapticFeedbackLevelProvider.overrideWithValue(
                HapticFeedbackLevel.none,
              ),
            ],
            child: MaterialApp(
              home: InteractiveViewerExtended(
                controller: controller,
                contentSize: const Size(500, 3000),
                snapZoomToFit: testCase.enabled,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );

        final viewer = tester.widget<InteractiveViewer>(
          find.byType(InteractiveViewer),
        );
        viewer.onInteractionStart!(ScaleStartDetails());
        viewer.onInteractionUpdate!(ScaleUpdateDetails(pointerCount: 2));
        controller.value = Matrix4.diagonal3Values(5.8, 5.8, 1);
        await tester.pump();
        viewer.onInteractionEnd!(ScaleEndDetails());
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          controller.value.getMaxScaleOnAxis(),
          closeTo(testCase.expectedScale, 0.001),
        );
      },
    );
  }
}

Future<void> _doubleTap(WidgetTester tester) async {
  final detector = tester.widget<GestureDetector>(
    find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onDoubleTap != null,
    ),
  );
  detector.onDoubleTapDown!(
    TapDownDetails(localPosition: const Offset(500, 500)),
  );
  detector.onDoubleTap!();
  await tester.pumpAndSettle();
}
