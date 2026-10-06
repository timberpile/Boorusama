import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/search/subscriptions/src/services/search_refresh_scheduler.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/search_refresh_lifecycle.dart';
import 'pinned_search_test_utils.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/providers/search_refresh_coordinator.dart';

void main() {
  testWidgets(
    'automatic foreground run refreshes an overdue source with site coordination',
    (tester) async {
      final harness = PinnedSearchHarness(
        clock: Clock.fixed(checkedAt.add(const Duration(days: 2))),
        networkAllowed: true,
      );
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        await harness.seed([pinnedFixture(query: 'cat')]);
        await harness.container.read(searchSubscriptionsProvider.future);
      });
      final coordinator = harness.container.read(
        searchRefreshCoordinatorProvider.notifier,
      );
      coordinator.setForeground(true);
      await drainRefresh(tester);
      expect(harness.requests.map((r) => r.query), ['cat']);
      coordinator.setForeground(false);
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'launch and elapsed foreground time refresh only daily-scale due searches',
    (tester) async {
      var now = checkedAt.add(const Duration(days: 1));
      final clock = Clock(() => now);
      final harness = PinnedSearchHarness(
        clock: clock,
        networkAllowed: true,
        scheduler: SearchRefreshScheduler(
          clock: clock,
          spacing: Duration.zero,
        ),
      );
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        await harness.seed([pinnedFixture(query: 'cat')]);
        await harness.container.read(searchSubscriptionsProvider.future);
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await harness.pump(
        tester,
        const SearchRefreshLifecycle(
          child: Scaffold(body: Text('App open')),
        ),
      );
      await drainRefresh(tester);
      final first = (await harness.repository.getAll()).single;
      expect(first.adaptiveState.consecutiveEmptyAutomatic, 1);
      expect(harness.requests, hasLength(1));
      now = now.add(const Duration(days: 1));
      await tester.pump(const Duration(minutes: 1));
      await drainRefresh(tester);
      expect(
        (await harness.repository.getAll()).single.adaptiveState.interval,
        const Duration(hours: 48),
      );
      expect(harness.requests, hasLength(2));
      await tester.pump(const Duration(minutes: 1));
      await drainRefresh(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await drainRefresh(tester);

      expect(harness.requests.map((r) => r.query), ['cat', 'cat']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('connectivity recovery refreshes overdue searches', (
    tester,
  ) async {
    final clock = Clock.fixed(checkedAt.add(const Duration(days: 1)));
    final harness = PinnedSearchHarness(
      clock: clock,
      scheduler: SearchRefreshScheduler(
        clock: clock,
        spacing: Duration.zero,
      ),
    );
    addTearDown(harness.dispose);
    await tester.runAsync(() async {
      await harness.seed([pinnedFixture(query: 'cat')]);
      await harness.container.read(searchSubscriptionsProvider.future);
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await harness.pump(
      tester,
      const SearchRefreshLifecycle(
        child: Scaffold(body: Text('App open')),
      ),
    );
    await drainRefresh(tester);

    harness.container
        .read(testAutomaticSearchRefreshNetworkAllowedProvider.notifier)
        .setAllowed(true);
    await drainRefresh(tester);

    expect(harness.requests.map((r) => r.query), ['cat']);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> drainRefresh(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}
