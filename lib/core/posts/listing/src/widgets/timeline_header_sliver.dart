import 'package:kurumi/material.dart';

/// Uses the child's measured extent, including enlarged text and custom headers.
class TimelineHeaderSliver extends StatelessWidget {
  const TimelineHeaderSliver({
    required this.child,
    this.keepVisible = false,
    this.reduceMotion = false,
    super.key,
  });

  final Widget child;
  final bool keepVisible;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    // Keep a stable measured render child across empty/error header changes.
    final surface = ColoredBox(color: Colors.transparent, child: child);
    return keepVisible
        ? PinnedHeaderSliver(child: surface)
        : SliverFloatingHeader(
            animationStyle: reduceMotion ? AnimationStyle.noAnimation : null,
            child: surface,
          );
  }
}
