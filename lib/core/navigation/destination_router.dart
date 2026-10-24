import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'destination_id.dart';

typedef DestinationNavigatorWrapper = Widget Function(
  BuildContext context,
  DestinationId id,
  bool selected,
  Widget navigator,
);

/// Page factories are lazy. Catalog refreshes do not reconstruct these routes.
final class DestinationRouteDefinition {
  const DestinationRouteDefinition({
    required this.id,
    required this.builder,
    this.children = const [],
  });
  final DestinationId id;
  final GoRouterWidgetBuilder builder;
  final List<RouteBase> children;
}

/// Owns route definitions, never a parallel history or a second router.
final class DestinationRouterBinding {
  DestinationRouterBinding({
    required List<DestinationRouteDefinition> definitions,
    required this.shellBuilder,
    this.navigatorWrapper,
    this.ingressRoutes = const [],
    this.observersFor,
    this.rootObserver,
  }) {
    _append(definitions);
    routingConfig = ValueNotifier(_configuration());
  }

  final StatefulShellRouteBuilder shellBuilder;
  final DestinationNavigatorWrapper? navigatorWrapper;
  final List<RouteBase> ingressRoutes;
  final List<NavigatorObserver> Function(DestinationId)? observersFor;
  final DestinationRouteObserver? rootObserver;
  final shellKey = GlobalKey<StatefulNavigationShellState>();
  final _branches = <DestinationId, StatefulShellBranch>{};
  final _observers = <DestinationId, DestinationRouteObserver>{};
  late final ValueNotifier<RoutingConfig> routingConfig;
  GoRouter? _router;
  var _disposed = false;
  Future<void> _reconciliation = Future.value();

  Future<void> reconcile(
    List<DestinationRouteDefinition> definitions, {
    Set<String> resetProfileIds = const {},
  }) {
    final next = _reconciliation.then(
      (_) => _reconcile(definitions, resetProfileIds),
    );
    _reconciliation = next.catchError((Object _) {});
    return next;
  }

  void attach(GoRouter router) => _router = router;
  int indexOf(DestinationId id) => _branches.keys.toList().indexOf(id);
  DestinationId idAt(int index) => _branches.keys.elementAt(index);
  StatefulShellBranch? branchFor(DestinationId id) => _branches[id];
  DestinationRouteObserver? observerFor(DestinationId id) => _observers[id];
  Route<dynamic>? get currentRoute => _observers[currentDestination]?.top;
  NavigatorState? get currentNavigator =>
      _branches[currentDestination]?.navigatorKey.currentState;
  Iterable<DestinationId> get destinations => _branches.keys;
  DestinationId? get currentDestination {
    final index = shellKey.currentState?.currentIndex;
    return index != null && index < _branches.length ? idAt(index) : null;
  }

  /// Drain only the transient viewer and surfaces stacked above it. The
  /// observer records Flutter's routes; it does not own another page history.
  Future<bool> dismissTransientRoutes() async {
    final origin = currentDestination;
    final observer = _observers[origin];
    if (observer == null) return true;
    final viewer = observer.routes.where(isPostViewerRoute).lastOrNull;
    if (viewer != null) {
      final root = rootObserver;
      while (root?.top != null &&
          root!.top!.settings.name != 'navigation-shell') {
        final route = root.top!;
        // A root editor/import is independent, and must finish through its
        // own guards before a destination can change beneath it.
        if (route is! PopupRoute || !await _popTransient(root, route))
          return false;
        if (currentDestination != origin) return false;
      }
    }
    while (observer.top is PopupRoute ||
        (viewer != null && observer.routes.contains(viewer))) {
      if (!await _popTransient(observer, observer.top!)) return false;
      if (currentDestination != origin) return false;
    }
    return true;
  }

  Future<bool> _popTransient(
    DestinationRouteObserver observer,
    Route<dynamic> route,
  ) async {
    final navigator = observer.navigator;
    if (navigator == null || !await navigator.maybePop()) return false;
    // maybePop also reports handled when a PopScope vetoes the pop.
    if (observer.routes.contains(route)) return false;
    // GoRouter saves the branch location during its next build. Switching
    // before that build resurrects the popped match and completes it twice.
    // Keep the outgoing navigator ticking until its overlays are removed.
    if (route is TransitionRoute) await route.completed;
    await WidgetsBinding.instance.endOfFrame;
    return true;
  }

  bool select(DestinationId id) {
    final index = indexOf(id);
    if (index < 0) {
      _router?.go(
        const DestinationId.app(AppDestination.browseRecovery).location,
      );
      return false;
    }
    if (currentDestination == id) return true;
    final shell = shellKey.currentState;
    if (shell == null) {
      _router?.go(id.location);
    } else {
      shell.goBranch(index);
    }
    return true;
  }

  /// Callers revoke source activity before reconciliation. A mounted active
  /// branch must first yield to recovery; its resources are disposed by Flutter
  /// when the supplied branch navigator is unmounted, not by this registry.
  Future<void> _reconcile(
    List<DestinationRouteDefinition> definitions,
    Set<String> resetProfileIds,
  ) async {
    if (_disposed) return;
    final ids = definitions.map((e) => e.id).toSet();
    final active = currentDestination;
    if (active != null &&
        (!ids.contains(active) || resetProfileIds.contains(active.profileId))) {
      final recovery = DestinationId.app(
        active.kind == DestinationKind.favorites
            ? AppDestination.favoritesRecovery
            : AppDestination.browseRecovery,
      );
      if (!ids.contains(recovery) || !_branches.containsKey(recovery)) {
        throw StateError('A recovery branch must survive source removal');
      }
      select(recovery);
      await WidgetsBinding.instance.endOfFrame;
      if (_disposed) return;
    }
    final removed = _branches.keys
        .where(
          (id) => !ids.contains(id) || resetProfileIds.contains(id.profileId),
        )
        .toList();
    final added = definitions
        .where(
          (definition) =>
              !_branches.containsKey(definition.id) ||
              removed.contains(definition.id),
        )
        .toList();
    if (removed.isEmpty && added.isEmpty) return;
    for (final id in removed) {
      _branches.remove(id);
      _observers.remove(id)?.dispose();
    }
    _append(added);
    routingConfig.value = _configuration();
  }

  void _append(List<DestinationRouteDefinition> definitions) {
    for (final definition in definitions) {
      if (_branches.containsKey(definition.id)) continue;
      final observer = DestinationRouteObserver();
      _observers[definition.id] = observer;
      _branches[definition.id] = StatefulShellBranch(
        navigatorKey: GlobalKey<NavigatorState>(
          debugLabel: definition.id.toStorageKey(),
        ),
        observers: [observer, ...?observersFor?.call(definition.id)],
        routes: [
          GoRoute(
            path: definition.id.location,
            name: definition.id.toStorageKey(),
            builder: definition.builder,
            routes: definition.children,
          ),
        ],
      );
    }
  }

  RoutingConfig _configuration() => RoutingConfig(
    routes: [
      StatefulShellRoute(
        key: shellKey,
        branches: _branches.values.toList(),
        notifyRootObserver: false,
        pageBuilder: (context, state, shell) => NoTransitionPage<void>(
          key: const ValueKey('destination-shell'),
          name: 'navigation-shell',
          child: shellBuilder(context, state, shell),
        ),
        navigatorContainerBuilder: (context, shell, children) => Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < children.length; i++)
              // Key the outer policy as well as GoRouter's supplied proxy so
              // removing an earlier branch cannot remount later navigators.
              Offstage(
                key: ObjectKey(shell.route.branches[i]),
                offstage: i != shell.currentIndex,
                child: TickerMode(
                  enabled: i == shell.currentIndex,
                  child: ExcludeFocus(
                    excluding: i != shell.currentIndex,
                    child:
                        navigatorWrapper?.call(
                          context,
                          _branches.entries
                              .firstWhere(
                                (entry) => identical(
                                  entry.value,
                                  shell.route.branches[i],
                                ),
                              )
                              .key,
                          i == shell.currentIndex,
                          children[i],
                        ) ??
                        children[i],
                  ),
                ),
              ),
          ],
        ),
      ),
      ...ingressRoutes,
    ],
  );

  void dispose() {
    _disposed = true;
    routingConfig.dispose();
    for (final observer in _observers.values) {
      observer.dispose();
    }
    _router = null;
  }
}

class DestinationRouteObserver extends RouteObserver<ModalRoute<dynamic>> {
  final _routes = <Route<dynamic>>[];
  final topRoute = ValueNotifier<Route<dynamic>?>(null);
  var _disposed = false;

  void _notifyTopRoute() {
    // Navigator callbacks may run during a router build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) topRoute.value = top;
    });
  }

  void dispose() {
    _disposed = true;
    topRoute.dispose();
  }

  List<Route<dynamic>> get routes => List.unmodifiable(_routes);
  Route<dynamic>? get top => _routes.lastOrNull;
  bool hasOnlyPopupsAbove(Route<dynamic> route) {
    final index = _routes.indexOf(route);
    return index >= 0 && _routes.skip(index + 1).every((r) => r is PopupRoute);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _notifyTopRoute();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _notifyTopRoute();
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _notifyTopRoute();
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
    _notifyTopRoute();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

/// All current viewer factories preserve their names in the branch catalog.
bool isPostViewerRoute(Route<dynamic> route) {
  final name = route.settings.name ?? '';
  return const [
    '/details',
    '/post-list-details',
    '/posts',
    '/bookmarks/details',
  ].any((viewer) => name == viewer || name.endsWith(':$viewer'));
}
