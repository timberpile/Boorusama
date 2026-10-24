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
    if (widget.route is! PopupRoute) _lastPageRoute = widget.route;
  }

  @override
  void didUpdateWidget(covariant NavigationChromeRouteSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.route;
    // Popups leave the underlying page (and its scroll position) unchanged.
    if (next == null || next is PopupRoute) return;

    final previous = _lastPageRoute;
    if (identical(previous, next)) return;
    _lastPageRoute = next;

    // Viewer entry/exit deliberately preserves the feed's hidden-bar state.
    if (isPostViewerRoute(next) ||
        (previous != null && isPostViewerRoute(previous))) {
      return;
    }

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
