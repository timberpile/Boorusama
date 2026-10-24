import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import 'navigation_chrome_controller.dart';

/// Shared transition policy keeps the bar and its overlay obstruction in sync.
({double hiddenFraction, Duration duration}) navigationBarTransition({
  required NavigationChromeState chrome,
  required bool keyboard,
  required bool disableAnimations,
}) => (
  hiddenFraction: keyboard || chrome.selectionActive
      ? 1.0
      : chrome.menuOpen
      ? 0.0
      : chrome.barHiddenFraction,
  duration:
      chrome.selectionActive ||
          chrome.viewerOpen ||
          chrome.barScrollActive ||
          disableAnimations
      ? Duration.zero
      : const Duration(milliseconds: 160),
);

/// Supplies live popup insets without changing the destination's stable layout.
/// Place above the destination Navigator and its synthetic page MediaQuery.
class NavigationOverlayInsetsScope extends ConsumerWidget {
  const NavigationOverlayInsetsScope({
    required this.systemMediaQuery,
    required this.extent,
    required this.child,
    super.key,
  });

  final MediaQueryData systemMediaQuery;
  final double extent;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chrome = ref.watch(navigationChromeProvider);
    final keyboard = systemMediaQuery.viewInsets.bottom > 0;
    final transition = navigationBarTransition(
      chrome: chrome,
      keyboard: keyboard,
      disableAnimations: systemMediaQuery.disableAnimations,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: transition.hiddenFraction),
      duration: transition.duration,
      child: child,
      builder: (context, hiddenFraction, child) {
        final covered =
            keyboard || (chrome.viewerOpen && !chrome.viewerClosing);
        final overlap = covered
            ? 0.0
            : extent * (1 - hiddenFraction).clamp(0.0, 1.0);
        return KurumiOverlayInsetsScope(
          bottomPadding: math.max(systemMediaQuery.padding.bottom, overlap),
          bottomViewPadding: math.max(
            systemMediaQuery.viewPadding.bottom,
            overlap,
          ),
          child: child!,
        );
      },
    );
  }
}
