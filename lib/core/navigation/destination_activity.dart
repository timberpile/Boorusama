import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_navigation.dart';
import 'destination_router.dart';

final currentDestinationRouteObserverProvider =
    Provider<RouteObserver<ModalRoute<dynamic>>>(
      (ref) => ref.watch(appNavigationProvider).routeObserver,
      dependencies: const [],
    );

/// One observer belongs to exactly one Navigator. Root coverage is separate
/// from branch-local route visibility, including raw dialog routes.
class NavigationCoverageObserver extends DestinationRouteObserver {
  final uncovered = ValueNotifier(true);
  Route<dynamic>? _top;
  void _update(Route<dynamic>? route) {
    _top = route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        uncovered.value = _top?.settings.name == 'navigation-shell';
      }
    });
  }

  var _disposed = false;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _update(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _update(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (route == _top) _update(top);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute == _top) _update(top);
  }

  @override
  void dispose() {
    _disposed = true;
    uncovered.dispose();
    super.dispose();
  }
}

class DestinationActivityHost extends StatefulWidget {
  const DestinationActivityHost({
    required this.selected,
    required this.coverage,
    required this.child,
    this.onActivityChanged,
    super.key,
  });
  final ValueChanged<bool>? onActivityChanged;
  final bool selected;
  final NavigationCoverageObserver coverage;
  final Widget child;
  @override
  State<DestinationActivityHost> createState() =>
      _DestinationActivityHostState();
}

class _DestinationActivityHostState extends State<DestinationActivityHost>
    with WidgetsBindingObserver {
  late bool _foreground;
  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      setState(() => _foreground = state == AppLifecycleState.resumed);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.coverage.uncovered,
      widget.coverage.topRoute,
    ]),
    builder: (_, child) {
      final active =
          widget.selected && _foreground && widget.coverage.uncovered.value;
      final shell = widget.coverage.routes
          .where((r) => r.settings.name == 'navigation-shell')
          .firstOrNull;
      final ownsChrome =
          widget.selected &&
          _foreground &&
          shell != null &&
          widget.coverage.hasOnlyPopupsAbove(shell);
      widget.onActivityChanged?.call(active);
      return _BranchActivity(
        active: active,
        selectionChromeActive: ownsChrome,
        child: child!,
      );
    },
    child: widget.child,
  );
}

class _BranchActivity extends InheritedWidget {
  const _BranchActivity({
    required this.active,
    required this.selectionChromeActive,
    required super.child,
  });
  final bool active;
  final bool selectionChromeActive;
  @override
  bool updateShouldNotify(_BranchActivity oldWidget) =>
      active != oldWidget.active ||
      selectionChromeActive != oldWidget.selectionChromeActive;
}

/// Route-local signal: selected destination AND foreground AND no covering
/// root task/menu AND this page is the current route of its branch.
class NavigationActivity extends InheritedWidget {
  const NavigationActivity({
    required this.active,
    this.selectionChromeActive,
    required super.child,
    super.key,
  });
  final bool active;
  final bool? selectionChromeActive;
  static bool selectionChromeOf(BuildContext context) {
    final activity = context
        .dependOnInheritedWidgetOfExactType<NavigationActivity>();
    return activity?.selectionChromeActive ?? activity?.active ?? true;
  }

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NavigationActivity>()
          ?.active ??
      true;
  @override
  bool updateShouldNotify(NavigationActivity oldWidget) =>
      active != oldWidget.active ||
      selectionChromeActive != oldWidget.selectionChromeActive;
}

class DestinationPageActivity extends ConsumerStatefulWidget {
  const DestinationPageActivity({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<DestinationPageActivity> createState() =>
      _DestinationPageActivityState();
}

class _DestinationPageActivityState
    extends ConsumerState<DestinationPageActivity>
    with RouteAware {
  RouteObserver<ModalRoute<dynamic>>? _observer;
  ModalRoute<dynamic>? _route;
  var _current = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      _observer?.unsubscribe(this);
      _route = route;
      _observer = ref.read(currentDestinationRouteObserverProvider);
      if (route != null) _observer!.subscribe(this, route);
      _current = route?.isCurrent ?? true;
    }
  }

  void _change(bool current) {
    if (_current == current) return;
    _current = current;
    // Navigator observer callbacks can arrive while the router is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didPush() => _change(true);
  @override
  void didPopNext() => _change(true);
  @override
  void didPushNext() => _change(false);
  @override
  void didPop() => _change(false);
  @override
  void dispose() {
    _observer?.unsubscribe(this);
    super.dispose();
  }

  Widget _activity(Widget child) {
    final branch = context
        .dependOnInheritedWidgetOfExactType<_BranchActivity>();
    final observer = _observer;
    return NavigationActivity(
      active: _current && (branch?.active ?? true),
      // Dialogs suspend input, but retain the underlying page's selection chrome.
      selectionChromeActive:
          (_route == null ||
              (observer is DestinationRouteObserver
                  ? observer.hasOnlyPopupsAbove(_route!)
                  : _current)) &&
          (branch?.selectionChromeActive ?? true),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final observer = _observer;
    return observer is DestinationRouteObserver
        ? ListenableBuilder(
            listenable: observer.topRoute,
            builder: (_, child) => _activity(child!),
            child: widget.child,
          )
        : _activity(widget.child);
  }
}
