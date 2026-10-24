import 'dart:async';

import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('viewer guards and child results survive a destination request', (
    tester,
  ) async {
    const browse = DestinationId.browse('review');
    const bookmarks = DestinationId.app(AppDestination.bookmarks);
    final allowPop = ValueNotifier(false);
    addTearDown(allowPop.dispose);
    final binding = DestinationRouterBinding(
      definitions: [
        DestinationRouteDefinition(
          id: browse,
          builder: (_, _) => const Scaffold(body: Text('Grid')),
          children: [
            GoRoute(
              path: 'details',
              name: 'review:/details',
              builder: (_, _) => ValueListenableBuilder(
                valueListenable: allowPop,
                builder: (_, allowed, _) => PopScope(
                  canPop: allowed,
                  child: const Scaffold(body: Text('Viewer')),
                ),
              ),
            ),
            GoRoute(
              path: 'child',
              builder: (_, _) => const Scaffold(body: Text('Viewer child')),
            ),
          ],
        ),
        DestinationRouteDefinition(
          id: bookmarks,
          builder: (_, _) => const Scaffold(body: Text('Bookmarks')),
        ),
      ],
      shellBuilder: (_, _, shell) => shell,
    );
    final router = GoRouter.routingConfig(
      routingConfig: binding.routingConfig,
      initialLocation: browse.location,
    );
    binding.attach(router);
    addTearDown(router.dispose);
    addTearDown(binding.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    var viewerCompletions = 0;
    unawaited(
      router
          .push<void>('${browse.location}/details')
          .then((_) => viewerCompletions++),
    );
    await tester.pumpAndSettle();
    expect(await binding.dismissTransientRoutes(), isFalse);
    expect(binding.currentDestination, browse);
    expect(viewerCompletions, 0);
    expect(find.text('Viewer'), findsOneWidget);
    allowPop.value = true;
    await tester.pumpAndSettle();
    var childCompletions = 0;
    unawaited(
      router
          .push<void>('${browse.location}/child')
          .then((_) => childCompletions++),
    );
    await tester.pumpAndSettle();
    var finished = false;
    final dismissed = binding.dismissTransientRoutes().then((value) {
      finished = true;
      return value;
    });
    for (var frame = 0; !finished && frame < 100; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finished, isTrue);
    expect(await dismissed, isTrue);
    binding.select(bookmarks);
    await tester.pumpAndSettle();
    binding.select(browse);
    await tester.pumpAndSettle();
    expect(viewerCompletions, 1);
    expect(childCompletions, 1);
    expect(router.state.uri.path, browse.location);
    expect(find.text('Grid'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
