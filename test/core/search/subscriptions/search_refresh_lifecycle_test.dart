import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/search/subscriptions/src/services/search_refresh_scheduler.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/search_refresh_lifecycle.dart';
import 'pinned_search_test_utils.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';

void main() {
  testWidgets(
    'launch, elapsed foreground time, and resume do not refresh searches',
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
      now = now.add(const Duration(days: 1));
      await tester.pump(const Duration(minutes: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await drainRefresh(tester);

      expect(harness.requests, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('connectivity recovery does not refresh searches', (
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

    expect(harness.requests, isEmpty);
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
