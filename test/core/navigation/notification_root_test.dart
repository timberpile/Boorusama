import 'dart:async';

import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'notification ingress unwinds a retained Bookmark Group and Viewer, respecting route guards',
    (tester) async {
      const browse = DestinationId.browse('fixture');
      const bookmarks = DestinationId.app(AppDestination.bookmarks);
      final blocked = ValueNotifier(false);
      final allow = ValueNotifier(false);
      addTearDown(blocked.dispose);
      addTearDown(allow.dispose);
      final binding = DestinationRouterBinding(
        definitions: [
          DestinationRouteDefinition(
            id: browse,
            builder: (_, _) => const Text('Browse'),
          ),
          DestinationRouteDefinition(
            id: bookmarks,
            builder: (_, _) => const Text('Bookmarks Home'),
            children: [
              GoRoute(
                path: 'group',
                builder: (_, _) => const Text('Group'),
                routes: [
                  GoRoute(
                    path: 'details',
                    name: 'fixture:/bookmarks/details',
                    builder: (_, _) => ValueListenableBuilder(
                      valueListenable: allow,
                      builder: (context, allowed, _) => PopScope(
                        canPop: allowed,
                        child: Builder(
                          builder: (context) => Text(
                            'Viewer active: ${NavigationActivity.of(context)}',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
        shellBuilder: (_, _, shell) => shell,
      );
      final router = GoRouter.routingConfig(
        routingConfig: binding.routingConfig,
        initialLocation: bookmarks.location,
      );
      binding.attach(router);
      addTearDown(router.dispose);
      addTearDown(binding.dispose);
      await tester.pumpWidget(
        NavigationIntentScope(
          blocked: blocked,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(router.push('${bookmarks.location}/group/details'));
      await tester.pumpAndSettle();
      expect(find.text('Viewer active: true'), findsOneWidget);
      blocked.value = true;
      final viewerContext = tester.element(find.text('Viewer active: true'));
      expect(
        NavigationActivity.of(viewerContext),
        isFalse,
        reason:
            'A callback queued before the next frame is immediately suppressed',
      );
      expect(await binding.openRoot(bookmarks), isFalse);
      expect(router.state.uri.path, '${bookmarks.location}/group/details');
      allow.value = true;
      await tester.pumpAndSettle();
      var completed = false;
      final opened = binding
          .openRoot(bookmarks)
          .whenComplete(() => completed = true);
      for (var i = 0; i < 100 && !completed; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(completed, isTrue);
      expect(await opened, isTrue);
      expect(router.state.uri.path, bookmarks.location);
      expect(binding.observerFor(bookmarks)!.routes, hasLength(1));
      binding.select(browse);
      await tester.pumpAndSettle();
      completed = false;
      final reopened = binding
          .openRoot(bookmarks)
          .whenComplete(() => completed = true);
      for (var i = 0; i < 100 && !completed; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(await reopened, isTrue);
      expect(find.text('Bookmarks Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
