import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import 'navigation_chrome_controller.dart';

/// The historical Scaffold.drawer preference, including its minimum at zero.
double legacyDrawerEdgeDragWidth(double screenWidth, int areaPercentage) {
  final width = screenWidth * (areaPercentage / 100).clamp(0.05, 1);
  return width < 20 ? 20 : width;
}

/// Keeps the framework's edge region mounted in the bounded overlay, leaving
/// the retained navigators and bottom shortcuts in their original slots.
class NavigationDrawerHost extends ConsumerStatefulWidget {
  const NavigationDrawerHost({
    required this.enabled,
    required this.edgeDragWidth,
    required this.child,
    super.key,
  });

  final bool enabled;
  final double edgeDragWidth;
  final Widget child;

  @override
  ConsumerState<NavigationDrawerHost> createState() =>
      _NavigationDrawerHostState();
}

class _NavigationDrawerHostState extends ConsumerState<NavigationDrawerHost> {
  final _drawer = GlobalKey<DrawerControllerState>();
  var _reportedOpen = false;
  var _active = true;

  @override
  void activate() {
    super.activate();
    _active = true;
  }

  @override
  void deactivate() {
    _active = false;
    super.deactivate();
  }

  @override
  void didUpdateWidget(NavigationDrawerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.enabled) _drawer.currentState?.close();
      });
    }
  }

  void _drawerChanged(bool open) {
    _reportedOpen = open;
    // The framework removes local history while disposing an open drawer.
    if (!_active) return;
    final chrome = ref.read(navigationChromeProvider);
    if (chrome.menuOpen != open) {
      ref.read(navigationChromeProvider.notifier).setMenuOpen(open);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(navigationChromeProvider.select((s) => s.menuOpen), (_, open) {
      if (open == _reportedOpen) return;
      if (open && widget.enabled) {
        _drawer.currentState?.open();
      } else {
        _drawer.currentState?.close();
      }
    });
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: DrawerController(
        key: _drawer,
        alignment: DrawerAlignment.start,
        edgeDragWidth: widget.edgeDragWidth,
        enableOpenDragGesture: widget.enabled,
        drawerCallback: _drawerChanged,
        child: widget.child,
      ),
    );
  }
}
