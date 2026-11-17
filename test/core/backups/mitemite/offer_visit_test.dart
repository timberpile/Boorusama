import 'dart:async';

import 'package:boorusama/core/backups/mitemite/offer_visit.dart';
import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/navigation/destination_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final keys = StateProvider<Set<String>>((ref) => {'first'});
final ready = StateProvider((ref) => false);

void main() {
  testWidgets(
    'NEW survives viewing, dialogs and background; exit acknowledges only the loaded snapshot',
    (tester) async {
      final observer = DestinationRouteObserver();
      final navigator = GlobalKey<NavigatorState>();
      final receipts = <Set<String>>[];
      final container = ProviderContainer(
        overrides: [
          currentDestinationRouteObserverProvider.overrideWithValue(observer),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(observer.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [observer],
            home: const Text('Home'),
          ),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => Consumer(
              builder: (context, ref, _) => SyncOfferVisit(
                ready: ref.watch(ready),
                keys: ref.watch(keys),
                onLeave: (snapshot) async {
                  receipts.add(snapshot);
                },
                child: const Text('Subscriptions NEW'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(receipts, isEmpty);
      container.read(ready.notifier).state = true;
      await tester.pumpAndSettle();
      expect(receipts, isEmpty);
      container.read(keys.notifier).state = {'first', 'late'};
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Subscriptions NEW'));
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => const Text('Confirmation'),
        ),
      );
      await tester.pumpAndSettle();
      expect(receipts, isEmpty);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(receipts, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Text('Other Page')),
        ),
      );
      await tester.pumpAndSettle();
      expect(receipts, [
        {'first'},
      ]);
      container.read(keys.notifier).state = {'late'};
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(receipts, hasLength(1));
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(receipts, [
        {'first'},
        {'late'},
      ]);
    },
  );

  testWidgets('unsuccessfully loaded Subscriptions never acknowledges offers', (
    tester,
  ) async {
    final observer = DestinationRouteObserver();
    final navigator = GlobalKey<NavigatorState>();
    final receipts = <Set<String>>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDestinationRouteObserverProvider.overrideWithValue(observer),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: const Text('Home'),
        ),
      ),
    );
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => SyncOfferVisit(
            ready: false,
            keys: const {'not-loaded'},
            onLeave: (snapshot) async {
              receipts.add(snapshot);
            },
            child: const Text('Loading'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(receipts, isEmpty);
    await tester.pumpWidget(const SizedBox());
    observer.dispose();
  });
}
