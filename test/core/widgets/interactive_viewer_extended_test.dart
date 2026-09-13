// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import 'package:boorusama/core/haptics/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/widgets/interactive_viewer_extended.dart';

void main() {
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
}
