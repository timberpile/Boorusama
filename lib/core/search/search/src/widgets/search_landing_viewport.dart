import 'package:kurumi/material.dart';

/// The editor's remaining space, measured before the landing view scrolls.
class SearchLandingViewport extends InheritedWidget {
  const SearchLandingViewport({
    required this.height,
    required super.child,
    super.key,
  });

  final double height;

  static double heightOf(BuildContext context) {
    final viewport = context
        .dependOnInheritedWidgetOfExactType<SearchLandingViewport>();
    if (viewport != null && viewport.height.isFinite) return viewport.height;
    final media = MediaQuery.of(context);
    return (media.size.height -
            media.viewInsets.vertical -
            media.padding.vertical)
        .clamp(0.0, double.infinity);
  }

  @override
  bool updateShouldNotify(SearchLandingViewport oldWidget) =>
      height != oldWidget.height;
}
