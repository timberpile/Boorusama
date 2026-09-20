import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/search/subscriptions/src/services/search_refresh_scheduler.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/search_refresh_lifecycle.dart';
import 'pinned_search_test_utils.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';

void main() {
  for (final networkAllowed in [true, false]) {
    testWidgets(
      'foreground scheduling respects network permission $networkAllowed and pause/resume',
      (tester) async {
        var now = checkedAt.add(const Duration(minutes: 6));
        final clock = Clock(() => now);
        final harness = PinnedSearchHarness(
          clock: clock,
          networkAllowed: networkAllowed,
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
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await harness.pump(
          tester,
          const SearchRefreshLifecycle(
            child: Scaffold(body: Text('App open')),
          ),
        );
        await drainRefresh(tester);
        expect(harness.requests.length, networkAllowed ? 1 : 0);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        now = now.add(const Duration(minutes: 6));
        await tester.pump(const Duration(minutes: 6));
        await drainRefresh(tester);
        expect(harness.requests.length, networkAllowed ? 1 : 0);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await drainRefresh(tester);
        expect(harness.requests.length, networkAllowed ? 2 : 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

Future<void> drainRefresh(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}
