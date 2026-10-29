import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/scheduler.dart';
import 'package:selection_mode/selection_mode.dart';
import 'package:kurumi/material.dart';

import '../settings/providers.dart';
import 'destination_activity.dart';
import 'destination_profile_scope.dart';
import 'navigation_chrome_controller.dart';

/// Supplies the actual bar travel, including its system bottom inset.
class NavigationBarScrollScope extends InheritedWidget {
  const NavigationBarScrollScope({
    required this.extent,
    required super.child,
    super.key,
  });

  final double extent;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NavigationBarScrollScope>()
          ?.extent ??
      kNavigationBarHeight;

  @override
  bool updateShouldNotify(NavigationBarScrollScope oldWidget) =>
      extent != oldWidget.extent;
}

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
    final extent = NavigationBarScrollScope.of(context);
    final autoHide = ref.watch(
      settingsProvider.select((s) => s.autoHideMainNavigation),
    );
    return NotificationListener<ScrollNotification>(
      onNotification: (event) {
        if (!active ||
            !autoHide ||
            extent <= 0 ||
            event.depth != 0 ||
            event.metrics.axis != Axis.vertical) {
          if (!active || !autoHide || extent <= 0) _userScroll = false;
          return false;
        }
        if (event is ScrollStartNotification) {
          _userScroll = event.dragDetails != null;
        }
        if (event is ScrollUpdateNotification && event.dragDetails != null) {
          _userScroll = true;
        }
        if (event is ScrollUpdateNotification && _userScroll) {
          ref
              .read(navigationChromeProvider.notifier)
              .userScroll(
                delta: event.scrollDelta ?? 0,
                pixels: event.metrics.pixels,
                outOfRange: event.metrics.outOfRange,
                extent: extent,
              );
        }
        if (event is ScrollEndNotification && _userScroll) {
          ref
              .read(navigationChromeProvider.notifier)
              .endScroll(pixels: event.metrics.pixels);
          _userScroll = false;
        }
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
    this.controller,
    this.bottomObstruction,
    super.key,
  });
  final SelectionModeController? controller;
  final ValueListenable<double>? bottomObstruction;
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
  var _lastObstruction = 0.0;
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_sync);
    widget.bottomObstruction?.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(NavigationSelectionBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_sync);
      widget.controller?.addListener(_sync);
    }
    if (widget.bottomObstruction != oldWidget.bottomObstruction) {
      oldWidget.bottomObstruction?.removeListener(_sync);
      widget.bottomObstruction?.addListener(_sync);
    }
    _sync();
  }

  void _sync() {
    if (DestinationScope.maybeOf(context) == null) return;
    _chrome ??= ref.read(navigationChromeProvider.notifier);
    final selected =
        (widget.controller?.isActive ?? widget.selected) &&
        NavigationActivity.selectionChromeOf(context);
    final obstruction = selected ? widget.bottomObstruction?.value ?? 0 : 0.0;
    if (_last == selected && _lastObstruction == obstruction) return;
    _last = selected;
    _lastObstruction = obstruction;
    void apply() {
      if (mounted) {
        _chrome?.setSelectionFor(
          this,
          _last,
          bottomObstruction: _lastObstruction,
        );
      }
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_sync);
    widget.bottomObstruction?.removeListener(_sync);
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
