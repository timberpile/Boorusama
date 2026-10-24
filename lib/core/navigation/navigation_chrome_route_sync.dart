import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'destination_router.dart';
import 'navigation_chrome_controller.dart';

/// Restores the bar on page navigation without changing the scrolled position
/// or disturbing the viewer's pre-existing chrome state.
class NavigationChromeRouteSync extends ConsumerStatefulWidget {
  const NavigationChromeRouteSync({
    required this.route,
    required this.child,
    super.key,
  });

  final Route<dynamic>? route;
  final Widget child;

  @override
  ConsumerState<NavigationChromeRouteSync> createState() =>
      _NavigationChromeRouteSyncState();
}

class _NavigationChromeRouteSyncState
    extends ConsumerState<NavigationChromeRouteSync> {
  Route<dynamic>? _lastPageRoute;

  @override
  void initState() {
    super.initState();
    final initial = widget.route;
    if (initial != null && initial is! PopupRoute && !isPostViewerRoute(initial)) {
      _lastPageRoute = initial;
    }
  }

  @override
  void didUpdateWidget(covariant NavigationChromeRouteSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.route;
    // Remember the page beneath transient routes, not the viewer itself.
    // Only returning to that same page preserves its scroll-driven chrome.
    if (next == null || next is PopupRoute || isPostViewerRoute(next)) return;

    if (identical(_lastPageRoute, next)) return;
    _lastPageRoute = next;

    // Route observers can notify during a Navigator build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_lastPageRoute, next)) {
        ref.read(navigationChromeProvider.notifier).show();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
