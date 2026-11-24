import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../../navigation/destination_activity.dart';
import '../../navigation/destination_profile_scope.dart';
import '../../navigation/destination_router.dart';
import '../../navigation/navigation_controller.dart';

/// Offer NEW survives the entire first visit. Only the first successfully
/// painted snapshot belongs to this visit; later arrivals need another visit.
class SyncOfferVisit extends ConsumerStatefulWidget {
  const SyncOfferVisit({
    required this.ready,
    required this.keys,
    required this.onLeave,
    required this.child,
    super.key,
  });
  final bool ready;
  final Set<String> keys;
  final Future<void> Function(Set<String>) onLeave;
  final Widget child;
  @override
  ConsumerState<SyncOfferVisit> createState() => _SyncOfferVisitState();
}

class _SyncOfferVisitState extends ConsumerState<SyncOfferVisit>
    with RouteAware {
  RouteObserver<ModalRoute<dynamic>>? _observer;
  ModalRoute<dynamic>? _route;
  Set<String>? _captured;
  var _scheduled = false;
  var _left = false;
  var _wasActive = true;
  late Future<void> Function(Set<String>) _onLeave;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route) {
      _observer?.unsubscribe(this);
      _route = route;
      _observer = ref.read(currentDestinationRouteObserverProvider);
      if (route != null) _observer!.subscribe(this, route);
    }
    final active = DestinationScope.maybeOf(context)?.active ?? true;
    if (!active) _leave();
    if (active && !_wasActive) _restart();
    _wasActive = active;
  }

  void _leave() {
    final captured = _captured;
    if (_left || captured == null) return;
    _left = true;
    final acknowledge = _onLeave;
    unawaited(
      Future<void>.microtask(() => acknowledge(captured))
          .catchError((Object _) {
            // A failed durable write retains NEW for the next visit.
          }),
    );
  }

  void _restart() {
    if (!_left) return;
    _left = false;
    _captured = null;
    if (mounted) setState(() {});
  }

  @override
  void didPopNext() => _restart();

  @override
  void didPop() => _leave();

  @override
  void didPushNext() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final observer = _observer;
      final top = observer is DestinationRouteObserver
          ? observer.top
          : ref
                .read(navigationControllerProvider.notifier)
                .binding
                ?.rootObserver
                ?.top;
      if (top is PageRoute && top != _route) _leave();
    });
  }

  @override
  void dispose() {
    _observer?.unsubscribe(this);
    _leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_left &&
        _captured == null &&
        !_scheduled &&
        widget.ready &&
        (_route?.isCurrent ?? true) &&
        NavigationActivity.of(context) &&
        (DestinationScope.maybeOf(context)?.active ?? true)) {
      _scheduled = true;
      final snapshot = Set<String>.unmodifiable(widget.keys);
      final callback = widget.onLeave;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (!mounted ||
            !widget.ready ||
            !(_route?.isCurrent ?? true) ||
            !NavigationActivity.of(context) ||
            WidgetsBinding.instance.lifecycleState != null &&
                WidgetsBinding.instance.lifecycleState !=
                    AppLifecycleState.resumed) {
          return;
        }
        _captured = snapshot;
        _onLeave = callback;
      });
    }
    return widget.child;
  }
}
