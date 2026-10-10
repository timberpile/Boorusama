import 'package:flutter/widgets.dart';
import 'package:foundation/performance.dart';

/// Registration uses enum labels, not RouteSettings.name or route arguments.
/// Unknown/nested navigators remain explicitly 'other' rather than leaking a URL.
class PerformanceNavigationObserver extends NavigatorObserver {
  PerformanceNavigationObserver({PerformanceRecorder? recorder})
      : recorder = recorder ?? performanceRecorder;
  final PerformanceRecorder recorder;
  final _screens = <Route<dynamic>, Map<Object, (PerfScreen, int)>>{};
  final _routes = <Route<dynamic>>[];

  void register(Route<dynamic> route, Object owner, PerfScreen screen, int priority) {
    _screens.putIfAbsent(route, () => {})[owner] = (screen, priority);
    _publish();
  }

  void unregister(Route<dynamic> route, Object owner) {
    final entries = _screens[route];
    entries?.remove(owner);
    if (entries?.isEmpty ?? false) _screens.remove(route);
    _publish();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _routes.add(route);
    _publish();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _screens.remove(route);
    _publish();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _screens.remove(route);
    _publish();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    _routes.remove(oldRoute);
    _screens.remove(oldRoute);
    if (newRoute != null) {
      if (index < 0) { _routes.add(newRoute); }
      else { _routes.insert(index, newRoute); }
    }
    _publish();
  }

  void _publish() {
    final top = _routes.isEmpty ? null : _routes.last;
    var label = top is PopupRoute ? PerfScreen.dialog : PerfScreen.other;
    var priority = -1;
    for (final entry in _screens[top]?.values ?? <(PerfScreen, int)>[]) {
      if (entry.$2 > priority) {
        priority = entry.$2;
        label = entry.$1;
      }
    }
    recorder.setContext(screen: label);
  }
}

class PerformanceScreenScope extends StatefulWidget {
  const PerformanceScreenScope({
    required this.screen, required this.child, this.priority = 1, super.key,
  });
  final PerfScreen screen;
  final Widget child;
  final int priority;
  @override
  State<PerformanceScreenScope> createState() => _PerformanceScreenScopeState();
}

class _PerformanceScreenScopeState extends State<PerformanceScreenScope> {
  PerformanceNavigationObserver? _observer;
  Route<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(PerformanceScreenScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _register();
  }

  void _register() {
    final route = ModalRoute.of(context);
    final observers = Navigator.maybeOf(context)?.widget.observers;
    PerformanceNavigationObserver? observer;
    for (final candidate in observers ?? <NavigatorObserver>[]) {
      if (candidate is PerformanceNavigationObserver) observer = candidate;
    }
    if (route != _route || observer != _observer) {
      if (_route != null) _observer?.unregister(_route!, this);
    }
    _route = route;
    _observer = observer;
    if (route != null) observer?.register(route, this, widget.screen, widget.priority);
  }

  @override
  void dispose() {
    if (_route != null) _observer?.unregister(_route!, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
