import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final navigationChromeProvider =
    NotifierProvider<NavigationChromeController, NavigationChromeState>(
      NavigationChromeController.new,
    );

const kNavigationBarHeight = 64.0;

class NavigationChromeState {
  const NavigationChromeState({
    this.menuOpen = false,
    this.barHiddenFraction = 0,
    this.barScrollActive = false,
    this.selectionActive = false,
    this.selectionBottomObstruction = 0,
    this.viewerImmersive = false,
    this.viewerOpen = false,
    this.viewerClosing = false,
    this.viewerBottomObstruction = 0,
  });
  final bool menuOpen;
  final double barHiddenFraction;
  final bool barScrollActive;
  bool get barVisible => barHiddenFraction < 1;
  final bool selectionActive;
  final double selectionBottomObstruction;
  final bool viewerImmersive;
  final bool viewerOpen;
  // Closing reveals chrome while the viewer still owns layout and input.
  final bool viewerClosing;
  final double viewerBottomObstruction;

  NavigationChromeState copyWith({
    bool? menuOpen,
    double? barHiddenFraction,
    bool? barScrollActive,
    bool? selectionActive,
    double? selectionBottomObstruction,
    bool? viewerImmersive,
    bool? viewerOpen,
    bool? viewerClosing,
    double? viewerBottomObstruction,
  }) => NavigationChromeState(
    menuOpen: menuOpen ?? this.menuOpen,
    barHiddenFraction: barHiddenFraction ?? this.barHiddenFraction,
    barScrollActive: barScrollActive ?? this.barScrollActive,
    selectionActive: selectionActive ?? this.selectionActive,
    selectionBottomObstruction:
        selectionBottomObstruction ?? this.selectionBottomObstruction,
    viewerImmersive: viewerImmersive ?? this.viewerImmersive,
    viewerOpen: viewerOpen ?? this.viewerOpen,
    viewerClosing: viewerClosing ?? this.viewerClosing,
    viewerBottomObstruction:
        viewerBottomObstruction ?? this.viewerBottomObstruction,
  );
}

class NavigationChromeController extends Notifier<NavigationChromeState> {
  // Expose route ticks without rebuilding the complete navigation shell.
  final viewerRouteProgress = ValueNotifier<double>(0);
  var _disposed = false;

  @override
  NavigationChromeState build() {
    ref.onDispose(() {
      _disposed = true;
      _viewers.clear();
      viewerRouteProgress.dispose();
    });
    return const NavigationChromeState();
  }

  void setMenuOpen(bool value) => state = state.copyWith(
    menuOpen: value,
    barHiddenFraction: 0,
    barScrollActive: false,
  );
  void show() {
    state = state.copyWith(
      barHiddenFraction: 0,
      barScrollActive: false,
    );
  }

  Object? _selectionOwner;
  void setSelectionFor(
    Object owner,
    bool selected, {
    double bottomObstruction = 0,
  }) {
    if (selected) {
      _selectionOwner = owner;
      setSelection(true, bottomObstruction: bottomObstruction);
    } else if (identical(_selectionOwner, owner)) {
      _selectionOwner = null;
      setSelection(false);
    }
  }

  void setSelection(bool selected, {double bottomObstruction = 0}) =>
      state = state.copyWith(
        menuOpen: false,
        barHiddenFraction: 0,
        barScrollActive: false,
        selectionActive: selected,
        selectionBottomObstruction: selected ? bottomObstruction : 0,
      );
  // Updating a covered route must not promote it above a nested Viewer.
  final _viewers = LinkedHashMap<Object, _ViewerChrome>.identity();

  void setViewerProgressFor(Object owner, double progress) {
    if (_disposed) return;
    final viewer = _viewers[owner];
    if (viewer == null) return;
    viewer.progress = progress.clamp(0.0, 1.0);
    _publishViewerProgress();
  }

  void setViewerFor(
    Object owner, {
    required bool active,
    required bool immersive,
    bool closing = false,
    double bottomObstruction = 0,
    double? routeProgress,
  }) {
    // Route teardown may release its owner after the provider's final frame.
    if (_disposed) return;
    if (active) {
      _viewers[owner] = _ViewerChrome(
        immersive: immersive,
        closing: closing,
        bottomObstruction: bottomObstruction,
        progress: (routeProgress ?? _viewers[owner]?.progress ?? 1.0).clamp(
          0.0,
          1.0,
        ),
      );
    } else if (_viewers.remove(owner) == null) {
      return;
    }
    _publishViewerState();
  }

  void setViewerImmersive(bool immersive) {
    if (_disposed) return;
    final viewer = _viewers.values.lastOrNull;
    if (viewer == null) {
      _setViewer(open: false, immersive: immersive);
    } else {
      viewer.immersive = immersive;
      _publishViewerState();
    }
  }

  void _publishViewerState() {
    final top = _viewers.values.lastOrNull;
    _setViewer(
      open: top != null,
      immersive: top?.immersive ?? false,
      closing: top != null && _viewers.values.every((viewer) => viewer.closing),
      bottomObstruction: top?.bottomObstruction ?? 0,
    );
    _publishViewerProgress();
  }

  void _publishViewerProgress() {
    // A closing child still covers another Viewer. Only the final Viewer's
    // reverse transition may reveal the destination's navigation bar.
    viewerRouteProgress.value = _viewers.values.fold(
      0,
      (progress, viewer) => math.max(progress, viewer.progress),
    );
  }

  void _setViewer({
    required bool open,
    required bool immersive,
    bool closing = false,
    double? bottomObstruction,
  }) => state = state.copyWith(
    barHiddenFraction: open && state.barScrollActive
        ? (state.barHiddenFraction > 0.5 ? 1 : 0)
        : state.barHiddenFraction,
    barScrollActive: open ? false : state.barScrollActive,
    viewerImmersive: immersive,
    viewerOpen: open,
    viewerClosing: closing,
    viewerBottomObstruction: open
        ? bottomObstruction ?? state.viewerBottomObstruction
        : 0,
  );
  void userScroll({
    required double delta,
    required double pixels,
    required bool outOfRange,
    double extent = kNavigationBarHeight,
  }) {
    if (state.menuOpen ||
        state.selectionActive ||
        state.viewerOpen ||
        outOfRange ||
        extent <= 0 ||
        delta == 0) {
      return;
    }
    state = state.copyWith(
      barHiddenFraction: pixels <= 8
          ? 0
          : (state.barHiddenFraction + delta / extent).clamp(0, 1),
      barScrollActive: true,
    );
  }

  void endScroll({required double pixels}) {
    if (!state.barScrollActive) return;
    state = state.copyWith(
      barHiddenFraction: pixels <= 8 || state.barHiddenFraction <= 0.5 ? 0 : 1,
      barScrollActive: false,
    );
  }
}

class _ViewerChrome {
  _ViewerChrome({
    required this.immersive,
    required this.closing,
    required this.bottomObstruction,
    required this.progress,
  });

  bool immersive;
  final bool closing;
  final double bottomObstruction;
  double progress;
}
