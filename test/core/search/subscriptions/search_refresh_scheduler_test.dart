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
    profileId: 1,
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
  Future<void> noWait(Duration _) async {}
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
    'refresh preferences round trip while old settings get five-minute defaults',
    () {
      expect(
        Settings.fromJson(
          Settings.defaultSettings.toJson(),
        ).searchRefresh.interval,
        const Duration(minutes: 5),
      );
      final updated = Settings.defaultSettings.copyWith(
        searchRefresh: const SearchRefreshSettings(
          enabled: false,
          intervalMinutes: 15,
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
    },
  );
}
