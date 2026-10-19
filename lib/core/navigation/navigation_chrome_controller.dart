import 'package:flutter_riverpod/flutter_riverpod.dart';

final navigationChromeProvider =
    NotifierProvider<NavigationChromeController, NavigationChromeState>(
      NavigationChromeController.new,
    );

class NavigationChromeState {
  const NavigationChromeState({
    this.menuOpen = false,
    this.barVisible = true,
    this.selectionActive = false,
    this.viewerImmersive = false,
    this.viewerOpen = false,
  });
  final bool menuOpen;
  final bool barVisible;
  final bool selectionActive;
  final bool viewerImmersive;
  final bool viewerOpen;
}

class NavigationChromeController extends Notifier<NavigationChromeState> {
  double _distance = 0;
  var _direction = 0;
  @override
  NavigationChromeState build() => const NavigationChromeState();
  void setMenuOpen(bool value) => state = NavigationChromeState(
    menuOpen: value,
    selectionActive: state.selectionActive,
    viewerImmersive: state.viewerImmersive,
    viewerOpen: state.viewerOpen,
  );
  void show() {
    _distance = 0;
    _direction = 0;
    state = NavigationChromeState(
      menuOpen: state.menuOpen,
      selectionActive: state.selectionActive,
      viewerImmersive: state.viewerImmersive,
      viewerOpen: state.viewerOpen,
    );
  }

  Object? _selectionOwner;
  void setSelectionFor(Object owner, bool selected) {
    if (selected) {
      _selectionOwner = owner;
      setSelection(true);
    } else if (identical(_selectionOwner, owner)) {
      _selectionOwner = null;
      setSelection(false);
    }
  }

  void setSelection(bool selected) => state = NavigationChromeState(
    selectionActive: selected,
    viewerImmersive: state.viewerImmersive,
    viewerOpen: state.viewerOpen,
  );
  Object? _viewerOwner;
  void setViewerFor(
    Object owner, {
    required bool active,
    required bool immersive,
  }) {
    if (active) {
      _viewerOwner = owner;
      _setViewer(open: true, immersive: immersive);
    } else if (identical(_viewerOwner, owner)) {
      _viewerOwner = null;
      _setViewer(open: false, immersive: false);
    }
  }

  void setViewerImmersive(bool immersive) =>
      _setViewer(open: state.viewerOpen, immersive: immersive);

  void _setViewer({required bool open, required bool immersive}) =>
      state = NavigationChromeState(
        menuOpen: state.menuOpen,
        barVisible: state.barVisible,
        selectionActive: state.selectionActive,
        viewerImmersive: immersive,
        viewerOpen: open,
      );
  void userScroll({
    required double delta,
    required double pixels,
    required bool outOfRange,
  }) {
    if (state.menuOpen ||
        state.selectionActive ||
        outOfRange ||
        delta.abs() < 1) {
      return;
    }
    if (pixels <= 8) {
      show();
      return;
    }
    final direction = delta.sign.toInt();
    if (direction != _direction) {
      _distance = 0;
      _direction = direction;
    }
    _distance += delta.abs();
    if (_distance >= (direction > 0 ? 24 : 12)) {
      state = NavigationChromeState(
        barVisible: direction < 0,
        viewerImmersive: state.viewerImmersive,
        viewerOpen: state.viewerOpen,
      );
      _distance = 0;
    }
  }
}
