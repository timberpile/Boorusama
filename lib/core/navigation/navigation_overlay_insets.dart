import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import 'app_navigation.dart';
import 'navigation_chrome_controller.dart';
import 'navigation_panel_geometry.dart';

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

/// One animation owns rendered panel progress. All bar/footer/overlay consumers
/// use its actual frame geometry rather than animating the same target twice.
class NavigationOverlayInsetsScope extends ConsumerStatefulWidget {
  const NavigationOverlayInsetsScope({
    required this.systemMediaQuery,
    required this.extent,
    required this.child,
    this.footerExtent = 0,
    super.key,
  });
  final MediaQueryData systemMediaQuery;
  final double extent;
  final double footerExtent;
  final Widget child;
  @override
  ConsumerState<NavigationOverlayInsetsScope> createState() =>
      _NavigationOverlayInsetsScopeState();
}

class _NavigationOverlayInsetsScopeState
    extends ConsumerState<NavigationOverlayInsetsScope>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  )..value = 1;
  late final _motion = ValueNotifier(
    NavigationPanelGeometry(
      navigationExtent: widget.extent,
      footerExtent: 0,
      hiddenFraction: 0,
      systemMediaQuery: widget.systemMediaQuery,
    ),
  );
  final _bottomPadding = ValueNotifier<double>(0);
  var _pendingBottomPadding = 0.0;
  var _notificationScheduled = false;
  var _fromHidden = 0.0;
  var _toHidden = 0.0;
  var _fromFooter = 0.0;
  var _toFooter = 0.0;
  var _chrome = const NavigationChromeState();
  ValueNotifier<double>? _viewerProgress;

  @override
  void initState() {
    super.initState();
    _animation.addListener(_tick);
  }

  void _publishBottomPadding(double value) {
    _pendingBottomPadding = value;
    if (_notificationScheduled || _bottomPadding.value == value) return;
    _notificationScheduled = true;
    // Root-overlay toasts are outside this build subtree. Coalesce their
    // notifications after layout, while panel consumers use frame geometry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (mounted) _bottomPadding.value = _pendingBottomPadding;
    });
  }

  void _tick() {
    final media = widget.systemMediaQuery;
    final keyboard = media.viewInsets.bottom > 0;
    final base = _fromHidden + (_toHidden - _fromHidden) * _animation.value;
    final hidden = _chrome.viewerOpen
        ? base +
              (1 - base) *
                  Curves.easeOutCubic.transform(_viewerProgress?.value ?? 0)
        : base;
    final geometry = NavigationPanelGeometry(
      navigationExtent: widget.extent,
      footerExtent: _fromFooter + (_toFooter - _fromFooter) * _animation.value,
      hiddenFraction: hidden,
      systemMediaQuery: media,
    );
    _motion.value = geometry;
    final overlap = _chrome.viewerOpen && !_chrome.viewerClosing
        ? (keyboard ? 0.0 : _chrome.viewerBottomObstruction)
        : _chrome.selectionActive
        ? _chrome.selectionBottomObstruction
        : keyboard
        ? 0.0
        : geometry.visible;
    final bottom = math.max(keyboard ? 0.0 : media.padding.bottom, overlap);
    _publishBottomPadding(math.max(0.0, bottom - media.padding.bottom));
  }

  void _retarget() {
    final transition = navigationBarTransition(
      chrome: _chrome,
      keyboard: widget.systemMediaQuery.viewInsets.bottom > 0,
      disableAnimations: widget.systemMediaQuery.disableAnimations,
    );
    final footer = widget.extent > 0 ? widget.footerExtent : 0.0;
    if (_toHidden != transition.hiddenFraction || _toFooter != footer) {
      final currentHidden =
          _fromHidden + (_toHidden - _fromHidden) * _animation.value;
      final currentFooter =
          _fromFooter + (_toFooter - _fromFooter) * _animation.value;
      _animation.stop();
      _fromHidden = currentHidden;
      _fromFooter = currentFooter;
      _toHidden = transition.hiddenFraction;
      _toFooter = footer;
      _animation.duration = transition.duration;
      if (transition.duration == Duration.zero) {
        _animation.value = 1;
      } else {
        _animation.forward(from: 0);
      }
    } else if (transition.duration == Duration.zero && _animation.isAnimating) {
      _animation.stop();
      _animation.value = 1;
    }
    _tick();
  }

  @override
  void dispose() {
    _viewerProgress?.removeListener(_tick);
    _animation.dispose();
    _motion.dispose();
    _bottomPadding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _chrome = ref.watch(navigationChromeProvider);
    final progress = ref
        .read(navigationChromeProvider.notifier)
        .viewerRouteProgress;
    if (_viewerProgress != progress) {
      _viewerProgress?.removeListener(_tick);
      _viewerProgress = progress..addListener(_tick);
    }
    _retarget();
    final feedbackKey = ref.watch(appNavigationProvider).feedbackKey;
    return NavigationPanelScope(
      motion: _motion,
      footerTarget: widget.footerExtent,
      child: ValueListenableBuilder<NavigationPanelGeometry>(
        valueListenable: _motion,
        child: KeyedSubtree(key: feedbackKey, child: widget.child),
        builder: (context, geometry, child) {
          final media = widget.systemMediaQuery;
          final keyboard = media.viewInsets.bottom > 0;
          final overlap = _chrome.viewerOpen && !_chrome.viewerClosing
              ? (keyboard ? 0.0 : _chrome.viewerBottomObstruction)
              : _chrome.selectionActive
              ? _chrome.selectionBottomObstruction
              : keyboard
              ? 0.0
              : geometry.visible;
          return KurumiOverlayInsetsScope(
            bottomPadding: math.max(
              keyboard ? 0.0 : media.padding.bottom,
              overlap,
            ),
            bottomViewPadding: math.max(media.viewPadding.bottom, overlap),
            bottomPaddingListenable: _bottomPadding,
            keyboardFromView: true,
            child: child!,
          );
        },
      ),
    );
  }
}
