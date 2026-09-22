// Package imports:
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../settings/types.dart';
import '../../../post/types.dart';
import '../../../slideshow/types.dart';
import '../widgets/post_details_controller.dart';

class PostDetailsData<T extends Post> {
  const PostDetailsData({
    required this.posts,
    required this.controller,
  });

  final List<T> posts;
  final PostDetailsController<T> controller;
}

class PostDetails extends InheritedWidget {
  const PostDetails({
    required this.data,
    required super.child,
    super.key,
  });

  final Object data;

  static PostDetailsData<T> of<T extends Post>(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<PostDetails>();
    final data = widget?.data;
    return data is PostDetailsData<T>
        ? data
        : (throw StateError('No compatible post details found in context'));
  }

  static PostDetailsData<T>? maybeOf<T extends Post>(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<PostDetails>();

    return switch (widget?.data) {
      final PostDetailsData<T> data => data,
      _ => null,
    };
  }

  @override
  bool updateShouldNotify(PostDetails oldWidget) {
    return data != oldWidget.data;
  }
}

SlideshowOptions toSlideShowOptions(ImageViewerSettings viewerSettings) {
  final interval = viewerSettings.slideshowInterval;
  final duration = interval < 1
      ? Duration(
          milliseconds: (interval * 1000).toInt(),
        )
      : Duration(seconds: interval.toInt());

  return SlideshowOptions(
    duration: duration,
    direction: viewerSettings.slideshowDirection,
    skipTransition: viewerSettings.slideshowTransitionType.isSkip,
  );
}
