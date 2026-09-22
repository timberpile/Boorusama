// Package imports:
import 'package:kurumi/material.dart';

// Project imports:
import '../../../post/types.dart';
import 'post_presentation_context.dart';

class InheritedPost extends InheritedWidget {
  const InheritedPost({
    required this.presentationContext,
    required super.child,
    super.key,
  });

  final PostPresentationContext presentationContext;

  Post get post => presentationContext.post;

  static T of<T extends Post>(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<InheritedPost>();
    final post = widget?.post;
    return switch (post) {
      final T post => post,
      null => throw Exception('No InheritedPost found in context'),
      _ => throw StateError('Current post is not a $T'),
    };
  }

  static T? maybeOf<T extends Post>(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<InheritedPost>();

    return switch (widget?.post) {
      final T post => post,
      _ => null,
    };
  }

  static PostPresentationContext presentationOf(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<InheritedPost>();
    return widget?.presentationContext ??
        (throw Exception('No InheritedPost found in context'));
  }

  @override
  bool updateShouldNotify(InheritedPost oldWidget) {
    return presentationContext != oldWidget.presentationContext;
  }
}
