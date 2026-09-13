// Package imports:
import 'package:kurumi/material.dart';

// Project imports:
import '../types/post_viewer_transformation_controller.dart';

class PostViewerTransformationScope extends InheritedWidget {
  const PostViewerTransformationScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final PostViewerTransformationController controller;

  static PostViewerTransformationController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PostViewerTransformationScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(PostViewerTransformationScope oldWidget) {
    return controller != oldWidget.controller;
  }
}

class PostViewerTransformationViewport extends StatelessWidget {
  const PostViewerTransformationViewport({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = PostViewerTransformationScope.maybeOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        controller?.viewportSize = constraints.biggest;
        return child;
      },
    );
  }
}
