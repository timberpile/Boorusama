// Flutter imports:
import 'package:flutter/material.dart';

// Flutter test imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/posts/details/src/types/post_viewer_transformation_controller.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_viewer_transformation_scope.dart';

void main() {
  testWidgets('reports the laid-out post viewport to transformation commands', (
    tester,
  ) async {
    final transformationController = TransformationController();
    addTearDown(transformationController.dispose);
    final controller = PostViewerTransformationController(
      transformationController,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 500,
            child: Column(
              children: [
                const SizedBox(height: 200),
                Expanded(
                  child: PostViewerTransformationScope(
                    controller: controller,
                    child: const PostViewerTransformationViewport(
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(controller.viewportSize, const Size(400, 300));
  });
}
