import 'dart:async';
import 'package:boorusama/core/search/subscriptions/src/services/search_refresh_request_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'pinned_search_test_utils.dart';

void main() {
  test(
    'an automatic refresh queued behind manual work is discarded after pausing',
    () async {
      final harness = PinnedSearchHarness();
      addTearDown(harness.dispose);
      await harness.seed([
        for (var i = 0; i < 4; i++)
          pinnedFixture(id: 'source_$i', query: 'source_$i'),
      ]);
      await harness.container.read(searchSubscriptionsProvider.future);
      harness.refreshGate = Completer<void>();
      final notifier = harness.container.read(
        searchSubscriptionsProvider.notifier,
      );
      final manual = [
        for (var i = 0; i < 3; i++) notifier.refresh('source_$i'),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(harness.requests.length, 3);
      var foreground = true;
      final automatic = notifier.refresh(
        'source_3',
        canStart: () => foreground,
      );
      foreground = false;
      harness.refreshGate!.complete();
      await Future.wait(manual);
      expect(await automatic, isA<SearchRefreshDiscarded>());
      expect(harness.requests.length, 3);
    },
  );

  for (final fail in [false, true]) {
    test(
      'queued refreshes respect the global concurrency cap after failure $fail',
      () async {
        final gate = SearchRefreshRequestGate();
        final release = Completer<void>();
        var active = 0;
        var maximum = 0;
        final started = <int>[];
        final futures = [
          for (var i = 0; i < 10; i++)
            gate.run(() async {
              active++;
              if (active > maximum) maximum = active;
              started.add(i);
              try {
                await release.future;
                if (fail && i == 0) throw StateError('Network failure');
                return i;
              } finally {
                active--;
              }
            }),
        ];
        expect(started, [0, 1, 2]);
        final result = Future.wait(futures);
        final verification = fail
            ? expectLater(result, throwsStateError)
            : expectLater(result, completion(List.generate(10, (i) => i)));
        release.complete();
        await verification;
        expect(maximum, 3);
        expect(started, List.generate(10, (i) => i));
        expect(active, 0);
      },
    );
  }
}
