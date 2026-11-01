// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

final class AppNavigation {
  AppNavigation()
    : navigatorKey = GlobalKey<NavigatorState>(),
      routeObserver = RouteObserver<ModalRoute<dynamic>>();

  final GlobalKey<NavigatorState> navigatorKey;
  final RouteObserver<ModalRoute<dynamic>> routeObserver;

  // A stable shell context below the live inset scope, unlike the root
  // Navigator context used by asynchronous removal callbacks.
  final feedbackKey = GlobalKey();
}

final appNavigationProvider = Provider<AppNavigation>(
  (_) => AppNavigation(),
  name: 'appNavigationProvider',
);
