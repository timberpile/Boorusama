import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import 'app_navigation.dart';
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
class NavigationOverlayInsetsScope extends ConsumerStatefulWidget {
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
  ConsumerState<NavigationOverlayInsetsScope> createState() =>
      _NavigationOverlayInsetsScopeState();
}

class _NavigationOverlayInsetsScopeState
    extends ConsumerState<NavigationOverlayInsetsScope> {
  final _bottomPadding = ValueNotifier<double>(0);
  var _pendingBottomPadding = 0.0;
  var _notificationScheduled = false;

  void _publishBottomPadding(double value) {
    _pendingBottomPadding = value;
    if (_notificationScheduled || _bottomPadding.value == value) return;
    _notificationScheduled = true;
    // A toast may live in OKToast's root overlay, outside this build subtree.
    // Notify after layout rather than marking that unrelated overlay dirty
    // during a navigation animation build. Coalesce to the latest frame value.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (mounted) _bottomPadding.value = _pendingBottomPadding;
    });
  }

  @override
  void dispose() {
    _bottomPadding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = ref.watch(navigationChromeProvider);
    final feedbackKey = ref.watch(appNavigationProvider).feedbackKey;
    final media = widget.systemMediaQuery;
    final keyboard = media.viewInsets.bottom > 0;
    final transition = navigationBarTransition(
      chrome: chrome,
      keyboard: keyboard,
      disableAnimations: media.disableAnimations,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: transition.hiddenFraction),
      duration: transition.duration,
      child: widget.child,
      builder: (context, hiddenFraction, child) {
        final overlap = keyboard
            ? 0.0
            : chrome.viewerOpen && !chrome.viewerClosing
            ? chrome.viewerBottomObstruction
            : widget.extent * (1 - hiddenFraction).clamp(0.0, 1.0);
        final bottom = math.max(media.padding.bottom, overlap);
        _publishBottomPadding(bottom);
        return KurumiOverlayInsetsScope(
          bottomPadding: bottom,
          bottomViewPadding: math.max(media.viewPadding.bottom, overlap),
          bottomPaddingListenable: _bottomPadding,
          child: KeyedSubtree(key: feedbackKey, child: child!),
        );
      },
    );
  }
}
