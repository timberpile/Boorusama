import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/search/subscriptions/src/services/search_refresh_scheduler.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';

void main() {
  final start = DateTime.utc(2026, 9, 17, 10);
  SearchSubscription search(
    String id, {
    DateTime? checked,
    DateTime? attempted,
    SearchRefreshErrorKind? error,
  }) => SearchSubscription(
    id: id,
    profileId: '00000000-0000-4000-8000-000000000001',
    query: 'cat',
    position: 0,
    createdAt: start,
    previews: const [],
    recentPostIdentities: const [],
    unreadCount: 0,
    lastSuccessfulCheckAt: checked,
    lastAttemptAt: attempted,
    lastErrorKind: error,
  );
  test(
    'finite progress settles skipped work and releases the remaining plan at deadline',
    () async {
      var now = start;
      final scheduler = SearchRefreshScheduler(
        clock: Clock(() => now),
        maxChecks: 2,
      );
      final pending = <Set<String>>[];
      var planned = false;
      await scheduler.run(
        searches: [search('a'), search('b'), search('c')],
        interval: Duration.zero,
        canRun: () => true,
        canRefresh: (item) => !planned || item.id != 'a',
        onPendingChanged: (ids) {
          pending.add(ids.toSet());
          planned = true;
        },
        refresh: (_) async {
          now = now.add(const Duration(seconds: 21));
          return const SearchRefreshDiscarded();
        },
      );
      expect(pending, [
        {'a', 'b'},
        {'b'},
        <String>{},
        <String>{},
      ]);
    },
  );
  Future<void> noWait(Duration _) async {}
  test('partial plans preserve accumulated failure backoff', () async {
    var now = start;
    final scheduler = SearchRefreshScheduler(
      clock: Clock(() => now),
      spacing: Duration.zero,
    );
    var bad = search('bad');
    Future<int> run(List<SearchSubscription> batch) => scheduler.run(
      searches: batch,
      interval: Duration.zero,
      canRun: () => true,
      canRefresh: (_) => true,
      refresh: (_) async =>
          const SearchRefreshFailed(SearchRefreshErrorKind.network),
    );
    expect(await run([bad]), 1);
    now = start.add(const Duration(minutes: 5));
    bad = search(
      'bad',
      attempted: start,
      error: SearchRefreshErrorKind.network,
    );
    expect(await run([bad]), 1);
    bad = search(
      'bad',
      attempted: now,
      error: SearchRefreshErrorKind.network,
    );
    scheduler.retainSources([bad, search('other')]);
    expect(await run([search('other')]), 1);
    expect(await run([]), 0);
    now = start.add(const Duration(minutes: 11));
    expect(await run([bad]), 0);
    now = start.add(const Duration(minutes: 15));
    expect(await run([bad]), 1);
  });

  for (final replacement in ['removed', 'recreated', 'revised']) {
    test(
      'late captured cooldown is cleared for a $replacement source',
      () async {
        final scheduler = SearchRefreshScheduler(
          clock: Clock.fixed(start),
          spacing: Duration.zero,
        );
        final captured = search('limited');
        final live = [
          if (replacement != 'removed')
            SearchSubscription(
              id: captured.id,
              profileId: captured.profileId,
              query: captured.query,
              position: 0,
              createdAt: replacement == 'recreated'
                  ? start.add(const Duration(seconds: 1))
                  : start,
              runtimeRevision: replacement == 'revised' ? 1 : 0,
              previews: const [],
              recentPostIdentities: const [],
              unreadCount: 0,
            ),
        ];
        await scheduler.run(
          searches: [captured],
          interval: Duration.zero,
          canRun: () => true,
          canRefresh: (_) => true,
          refresh: (_) async {
            scheduler.retainSources(live);
            return SearchRefreshDeferred(
              start.add(const Duration(minutes: 30)),
            );
          },
        );
        scheduler.retainSources(live);
        expect(scheduler.deferredUntil('limited'), isNull);
        if (live.isNotEmpty) {
          expect(scheduler.isDue(live.single, Duration.zero), isTrue);
        }
      },
    );
  }
  for (final count in [2, 10000]) {
    test(
      'a queue of $count due searches uses at most ten sequential checks',
      () async {
        final scheduler = SearchRefreshScheduler(clock: Clock.fixed(start));
        final calls = <String>[];
        var active = 0;
        var maximumActive = 0;
        final completed = await scheduler.run(
          searches: [for (var i = 0; i < count; i++) search('$i')],
          interval: const Duration(minutes: 5),
          canRun: () => true,
          canRefresh: (_) => true,
          wait: noWait,
          refresh: (id) async {
            active++;
            if (active > maximumActive) maximumActive = active;
            calls.add(id);
            await Future<void>.value();
            active--;
            return const SearchRefreshDiscarded();
          },
        );
        expect(completed, count < 10 ? count : 10);
        expect(calls.toSet().length, completed);
        expect(maximumActive, 1);
      },
    );
  }
  test(
    'five-minute eligibility is strict and never-checked searches have priority',
    () async {
      final scheduler = SearchRefreshScheduler(clock: Clock.fixed(start));
      final calls = <String>[];
      await scheduler.run(
        searches: [
          search('recent', checked: start.subtract(const Duration(minutes: 4))),
          search('exact', checked: start.subtract(const Duration(minutes: 5))),
          search('old', checked: start.subtract(const Duration(minutes: 6))),
          search('baseline'),
        ],
        interval: const Duration(minutes: 5),
        canRun: () => true,
        canRefresh: (_) => true,
        wait: noWait,
        refresh: (id) async {
          calls.add(id);
          return const SearchRefreshDiscarded();
        },
      );
      expect(calls, ['baseline', 'old']);
    },
  );
  test('the time budget stops starting work after twenty seconds', () async {
    var now = start;
    final scheduler = SearchRefreshScheduler(clock: Clock(() => now));
    final completed = await scheduler.run(
      searches: [for (var i = 0; i < 100; i++) search('$i')],
      interval: const Duration(minutes: 5),
      canRun: () => true,
      canRefresh: (_) => true,
      wait: (duration) async => now = now.add(duration),
      refresh: (_) async {
        now = now.add(const Duration(seconds: 3));
        return const SearchRefreshDiscarded();
      },
    );
    expect(completed, 5);
  });
  test('pausing during a request prevents starting further checks', () async {
    var allowed = true;
    final scheduler = SearchRefreshScheduler(clock: Clock.fixed(start));
    final completed = await scheduler.run(
      searches: [search('a'), search('b')],
      interval: const Duration(minutes: 5),
      canRun: () => allowed,
      canRefresh: (_) => true,
      wait: noWait,
      refresh: (_) async {
        allowed = false;
        return const SearchRefreshDiscarded();
      },
    );
    expect(completed, 1);
  });
  test(
    'failed searches back off while other overdue searches continue',
    () async {
      var now = start;
      final scheduler = SearchRefreshScheduler(clock: Clock(() => now));
      Future<int> run(List<SearchSubscription> items) => scheduler.run(
        searches: items,
        interval: const Duration(minutes: 5),
        canRun: () => true,
        canRefresh: (_) => true,
        wait: noWait,
        refresh: (_) async =>
            const SearchRefreshFailed(SearchRefreshErrorKind.network),
      );
      expect(await run([search('bad')]), 1);
      now = start.add(const Duration(minutes: 4));
      expect(
        await run([
          search(
            'bad',
            attempted: start,
            error: SearchRefreshErrorKind.network,
          ),
          search('other'),
        ]),
        1,
      );
      now = start.add(const Duration(minutes: 5));
      expect(
        await run([
          search(
            'bad',
            attempted: start,
            error: SearchRefreshErrorKind.network,
          ),
        ]),
        1,
      );
      now = start.add(const Duration(minutes: 11));
      expect(
        await run([
          search(
            'bad',
            attempted: start.add(const Duration(minutes: 5)),
            error: SearchRefreshErrorKind.network,
          ),
        ]),
        0,
      );
    },
  );
  test(
    'cooldown deferral prevents repolling until retryAt without a failed attempt',
    () async {
      var now = start;
      final retryAt = start.add(const Duration(seconds: 30));
      final scheduler = SearchRefreshScheduler(clock: Clock(() => now));
      Future<int> run() => scheduler.run(
        searches: [search('limited')],
        interval: const Duration(minutes: 5),
        canRun: () => true,
        canRefresh: (_) => true,
        wait: noWait,
        refresh: (_) async => SearchRefreshDeferred(retryAt),
      );
      expect(await run(), 1);
      now = retryAt.subtract(const Duration(milliseconds: 1));
      expect(await run(), 0);
      now = retryAt;
      expect(await run(), 1);
    },
  );
  test(
    'refresh preferences round trip while old minute settings migrate to a day',
    () {
      expect(
        Settings.fromJson(
          Settings.defaultSettings.toJson(),
        ).searchRefresh.interval,
        const Duration(hours: 24),
      );
      final updated = Settings.defaultSettings.copyWith(
        searchRefresh: const SearchRefreshSettings(
          enabled: false,
          pinnedSearchesEnabled: false,
          mode: SearchRefreshMode.fixed,
          fixedIntervalHours: 48,
          wifiEthernetOnly: false,
        ),
      );
      expect(
        Settings.fromJson(updated.toJson()).searchRefresh,
        updated.searchRefresh,
      );
      for (final value in [
        null,
        {'enabled': 'wrong', 'intervalMinutes': -1},
      ]) {
        expect(
          SearchRefreshSettings.parse(value),
          const SearchRefreshSettings(),
        );
      }
      expect(
        SearchRefreshSettings.parse(const {
          'enabled': false,
          'intervalMinutes': 5,
        }),
        const SearchRefreshSettings(enabled: false),
      );
    },
  );
}
