import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../settings/providers.dart';
import 'destination_activity.dart';
import 'destination_profile_scope.dart';
import 'navigation_chrome_controller.dart';

/// Only direct, vertical post-list gestures control chrome. Programmatic
/// jumps, nested horizontal scrolling and overscroll cannot hide the bar.
class NavigationScrollBoundary extends ConsumerStatefulWidget {
  const NavigationScrollBoundary({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<NavigationScrollBoundary> createState() =>
      _NavigationScrollBoundaryState();
}

class _NavigationScrollBoundaryState
    extends ConsumerState<NavigationScrollBoundary> {
  var _userScroll = false;
  @override
  Widget build(BuildContext context) {
    if (DestinationScope.maybeOf(context) == null) return widget.child;
    final active = NavigationActivity.of(context);
    final autoHide = ref.watch(
      settingsProvider.select((s) => s.autoHideMainNavigation),
    );
    return NotificationListener<ScrollNotification>(
      onNotification: (event) {
        if (!active ||
            !autoHide ||
            event.depth != 0 ||
            event.metrics.axis != Axis.vertical) {
          return false;
        }
        if (event is ScrollStartNotification) {
          _userScroll = event.dragDetails != null;
        }
        if (event is ScrollUpdateNotification && _userScroll) {
          ref
              .read(navigationChromeProvider.notifier)
              .userScroll(
                delta: event.scrollDelta ?? 0,
                pixels: event.metrics.pixels,
                outOfRange: event.metrics.outOfRange,
              );
        }
        if (event is ScrollEndNotification) _userScroll = false;
        return false;
      },
      child: widget.child,
    );
  }
}

class NavigationSelectionBridge extends ConsumerStatefulWidget {
  const NavigationSelectionBridge({
    required this.selected,
    required this.child,
    super.key,
  });
  final bool selected;
  final Widget child;
  @override
  ConsumerState<NavigationSelectionBridge> createState() =>
      _NavigationSelectionBridgeState();
}

class _NavigationSelectionBridgeState
    extends ConsumerState<NavigationSelectionBridge> {
  NavigationChromeController? _chrome;
  var _last = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(NavigationSelectionBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (DestinationScope.maybeOf(context) == null) return;
    _chrome ??= ref.read(navigationChromeProvider.notifier);
    final selected = widget.selected && NavigationActivity.of(context);
    if (_last == selected) return;
    _last = selected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _chrome?.setSelectionFor(this, _last);
    });
  }

  @override
  void dispose() {
    final chrome = _chrome;
    if (_last) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => chrome?.setSelectionFor(this, false),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
