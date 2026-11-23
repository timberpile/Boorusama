import 'package:flutter/widgets.dart';

/// A displayed projection can supply its own explicit raw-to-display mapping.
class ViewerNavigationScope extends InheritedWidget {
  const ViewerNavigationScope({
    required this.open,
    required super.child,
    super.key,
  });
  final void Function(int rawIndex, String? thumbnailUrl) open;

  static ViewerNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ViewerNavigationScope>();

  @override
  bool updateShouldNotify(ViewerNavigationScope oldWidget) =>
      open != oldWidget.open;
}
