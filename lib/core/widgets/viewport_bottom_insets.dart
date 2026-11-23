import 'package:flutter/foundation.dart';
import 'package:kurumi/material.dart';

/// Bottom controls may cover a full-height viewport without resizing its grid.
class ViewportBottomInsets {
  const ViewportBottomInsets({
    required this.visible,
    required this.endClearance,
  });
  final double visible;
  final double endClearance;
}

class ViewportBottomInsetsScope extends InheritedWidget {
  const ViewportBottomInsetsScope({
    required this.insets,
    required super.child,
    super.key,
  });
  final ValueListenable<ViewportBottomInsets> insets;

  static ValueListenable<ViewportBottomInsets>? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ViewportBottomInsetsScope>()
          ?.insets;

  @override
  bool updateShouldNotify(ViewportBottomInsetsScope oldWidget) =>
      insets != oldWidget.insets;
}
