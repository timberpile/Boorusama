import 'dart:async';

import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'activity follows branch, local cover, root cover and app lifecycle',
    (tester) async {
      const a = DestinationId.browse('a');
      const b = DestinationId.browse('b');
      final activity = <String, bool>{};
      Widget page(String key) => DestinationPageActivity(
        child: Builder(
          builder: (context) {
            activity[key] = NavigationActivity.of(context);
            return Scaffold(body: Text(key));
          },
        ),
      );
      final coverage = NavigationCoverageObserver();
      late final DestinationRouterBinding binding;
      binding = DestinationRouterBinding(
        definitions: [
          for (final id in [a, b])
            DestinationRouteDefinition(
              id: id,
              builder: (_, _) => page(id.profileId!),
              children: [
                GoRoute(
                  path: 'child',
                  builder: (_, _) => page('${id.profileId}-child'),
                ),
              ],
            ),
        ],
        shellBuilder: (_, _, shell) => shell,
        navigatorWrapper: (_, id, selected, child) => DestinationActivityHost(
          selected: selected,
          coverage: coverage,
          child: ProviderScope(
            overrides: [
              currentDestinationRouteObserverProvider.overrideWithValue(
                binding.observerFor(id)!,
              ),
            ],
            child: child,
          ),
        ),
        ingressRoutes: [
          GoRoute(
            path: '/root-task',
            builder: (_, _) => const Scaffold(body: Text('Root task')),
          ),
        ],
      );
      final router = GoRouter.routingConfig(
        routingConfig: binding.routingConfig,
        initialLocation: a.location,
        observers: [coverage],
      );
      binding.attach(router);
      addTearDown(router.dispose);
      addTearDown(binding.dispose);
      addTearDown(coverage.dispose);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      expect(activity['a'], isTrue);
      binding.select(b);
      await tester.pumpAndSettle();
      expect(activity, {'a': false, 'b': true});
      unawaited(router.push('${b.location}/child'));
      await tester.pumpAndSettle();
      expect(activity['b'], isFalse);
      expect(activity['b-child'], isTrue);
      unawaited(router.push('/root-task'));
      await tester.pumpAndSettle();
      expect(activity.values, everyElement(false));
      router.pop();
      await tester.pumpAndSettle();
      expect(activity['b-child'], isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(activity.values, everyElement(false));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(activity['b-child'], isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(activity['b'], isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
