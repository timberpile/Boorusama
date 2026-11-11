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

/// Retains only a matrix outside the pager's mounted current/adjacent window.
class PostViewerOccurrence extends StatefulWidget {
  const PostViewerOccurrence({
    required this.checkpoints,
    required this.occurrence,
    required this.child,
    super.key,
  });
  final Map<Object, Matrix4> checkpoints;
  final Object occurrence;
  final Widget child;

  @override
  State<PostViewerOccurrence> createState() => _PostViewerOccurrenceState();
}

class _PostViewerOccurrenceState extends State<PostViewerOccurrence> {
  late final _transform = TransformationController(
    widget.checkpoints[widget.occurrence]?.clone() ?? Matrix4.identity(),
  );
  late final _controller = PostViewerTransformationController(
    _transform,
    restoredCheckpoint: widget.checkpoints.containsKey(widget.occurrence),
  );

  @override
  void dispose() {
    widget.checkpoints[widget.occurrence] = _transform.value.clone();
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PostViewerTransformationScope(
    controller: _controller,
    child: widget.child,
  );
}
