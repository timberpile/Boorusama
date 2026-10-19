// Flutter imports:
import 'package:flutter/widgets.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import 'providers.dart';

class AnalyticsObserver implements NavigatorObserver {
  AnalyticsObserver(this.ref, {this.isActive});

  final bool Function()? isActive;

  final Ref Function() ref;

  Future<NavigatorObserver?> withObserver() async {
    if (!(isActive?.call() ?? true)) return null;
    final analytics = await ref().read(analyticsProvider.future);
    if (!(isActive?.call() ?? true)) return null;
    return analytics?.getAnalyticsObserver();
  }

  @override
  void didChangeTop(Route topRoute, Route? previousTopRoute) {
    withObserver().then((observer) {
      observer?.didChangeTop(topRoute, previousTopRoute);
    });
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    withObserver().then((observer) {
      observer?.didPop(route, previousRoute);
    });
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    withObserver().then((observer) {
      observer?.didPush(route, previousRoute);
    });
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    withObserver().then((observer) {
      observer?.didRemove(route, previousRoute);
    });
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    withObserver().then((observer) {
      observer?.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    });
  }

  @override
  void didStartUserGesture(Route route, Route? previousRoute) {
    withObserver().then((observer) {
      observer?.didStartUserGesture(route, previousRoute);
    });
  }

  @override
  void didStopUserGesture() {
    withObserver().then((observer) {
      observer?.didStopUserGesture();
    });
  }

  @override
  NavigatorState? get navigator => null;
}
