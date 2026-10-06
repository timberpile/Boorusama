import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/providers/search_refresh_coordinator.dart';
import 'package:boorusama/core/search/subscriptions/src/services/search_refresh_scheduler.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/search_refresh_lifecycle.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'pinned_search_test_utils.dart';
import 'search_refresh_lifecycle_test.dart' show drainRefresh;

void main() {
  Future<void> settleMutation(
    WidgetTester tester,
    Future<void> mutation,
  ) async {
    var completed = false;
    final observed = mutation.whenComplete(() => completed = true);
    await drainRefresh(tester);
    expect(
      completed,
      isTrue,
      reason: 'Mutation settles while Riverpod is pumped',
    );
    await observed;
  }

  for (final change in ['removal', 'creation', 'revision']) {
    testWidgets(
      'inactive authoritative $change clears cooldown while rename retains it',
      (tester) async {
        final now = checkedAt.add(const Duration(days: 2));
        final clock = Clock.fixed(now);
        final retryAt = now.add(const Duration(minutes: 30));
        final scheduler = SearchRefreshScheduler(
          clock: clock,
          spacing: Duration.zero,
        );
        final harness = PinnedSearchHarness(
          clock: clock,
          networkAllowed: true,
          scheduler: scheduler,
          fetchPosts: (_, _, _, _) async =>
              Either.left(RateLimitedError(retryAt)),
        );
        addTearDown(harness.dispose);
        await tester.runAsync(() async {
          await harness.seed([pinnedFixture(query: 'cat')]);
          await harness.container.read(searchSubscriptionsProvider.future);
        });
        await harness.pump(tester, const SizedBox());
        final coordinator = harness.container.read(
          searchRefreshCoordinatorProvider.notifier,
        );
        coordinator.setForeground(true);
        await drainRefresh(tester);
        expect(scheduler.deferredUntil('cats'), retryAt);
        coordinator.setForeground(false);
        final notifier = harness.container.read(
          searchSubscriptionsProvider.notifier,
        );
        await settleMutation(tester, notifier.rename('cats', 'Renamed'));
        expect(
          harness.container.read(searchRefreshStatusProvider).deferredUntilById,
          {'cats': retryAt},
        );
        if (change == 'removal') {
          await settleMutation(tester, notifier.delete('cats'));
        } else {
          await settleMutation(
            tester,
            notifier.runSerializedMutation(
              (repository) => repository.restoreForProfile(testProfile.id, [
                SearchSubscription(
                  id: 'cats',
                  profileId: testProfile.id,
                  query: 'cat',
                  position: 0,
                  createdAt: change == 'creation'
                      ? checkedAt.add(const Duration(hours: 1))
                      : checkedAt,
                  runtimeRevision: change == 'revision' ? 1 : 0,
                  previews: const [],
                  recentPostIdentities: const [],
                  unreadCount: 0,
                ),
              ]),
            ),
          );
        }
        expect(scheduler.deferredUntil('cats'), isNull);
        expect(
          harness.container.read(searchRefreshStatusProvider).deferredUntilById,
          isEmpty,
        );
        expect(harness.requests, hasLength(1));
        if (change == 'removal') {
          await settleMutation(
            tester,
            notifier.runSerializedMutation(
              (repository) => repository.restoreForProfile(testProfile.id, [
                pinnedFixture(query: 'cat'),
              ]),
            ),
          );
        }
        coordinator.setForeground(true);
        await drainRefresh(tester);
        expect(harness.requests, hasLength(2));
        expect(scheduler.deferredUntil('cats'), retryAt);
        coordinator.setForeground(false);
      },
    );
  }
  for (final feedScope in [false, true]) {
    for (final manualJoin in [false, true]) {
      testWidgets(
        'disabling ${feedScope ? "feed" : "pin"} scope revokes queued automatic owner; manual join $manualJoin',
        (tester) async {
          final clock = Clock.fixed(checkedAt.add(const Duration(days: 2)));
          final api = ApiRequestCoordinator(
            policy: (_) => ApiQuotaPolicy.buffered(
              sourceWindows: const [
                ApiStartWindow(capacity: 100, duration: Duration(seconds: 1)),
              ],
            ),
          );
          final key = ApiQuotaKey.fromUri(Uri.parse('https://scope.test'));
          final active = await tester.runAsync(
            () async => [for (var i = 0; i < 4; i++) await api.acquire(key)],
          );
          final harness = PinnedSearchHarness(
            clock: clock,
            networkAllowed: true,
            scheduler: SearchRefreshScheduler(
              clock: clock,
              spacing: Duration.zero,
            ),
            beforeDispatch: () async {
              final permit = await api.acquire(
                key,
                context: ApiRequestContext.current(),
              );
              permit.release();
            },
          );
          addTearDown(harness.dispose);
          addTearDown(api.dispose);
          await tester.runAsync(() async {
            await harness.seed([pinnedFixture(id: 'a', query: 'cat')]);
            if (feedScope) {
              await harness.organizationBox.put(
                'feed:feed',
                SearchFollowingFeed(
                  id: 'feed',
                  profileId: '00000000-0000-4000-8000-00000000000c',
                  name: 'Feed',
                  sourceIds: const ['a'],
                ).toJson(),
              );
            }
            await harness.container.read(searchSubscriptionsProvider.future);
          });
          await harness.pump(
            tester,
            const SearchRefreshLifecycle(child: SizedBox()),
          );
          await drainRefresh(tester);
          expect(api.snapshot(key).queued, 1);
          expect(
            harness.container
                .read(searchSubscriptionsProvider)
                .requireValue
                .pendingRefreshIds,
            {'a'},
          );
          final manual = manualJoin
              ? harness.container
                    .read(searchSubscriptionsProvider.notifier)
                    .refresh('a')
              : null;
          await drainRefresh(tester);
          final update = harness.container
              .read(settingsNotifierProvider.notifier)
              .updateWith(
                (settings) => settings.copyWith(
                  searchRefresh: settings.searchRefresh.copyWith(
                    pinnedSearchesEnabled: feedScope ? null : false,
                    followingFeedsEnabled: feedScope ? false : null,
                  ),
                ),
              );
          await drainRefresh(tester);
          await update;
          expect(api.snapshot(key).queued, manualJoin ? 1 : 0);
          expect(
            harness.container
                .read(searchSubscriptionsProvider)
                .requireValue
                .pendingRefreshIds,
            manualJoin ? {'a'} : isEmpty,
          );
          for (final permit in active!) {
            permit.release();
          }
          await tester.pump(const Duration(seconds: 1));
          await drainRefresh(tester);
          if (manual != null) await manual;
          expect(harness.requests.length, manualJoin ? 1 : 0);
          final saved = (await harness.repository.getAll()).single;
          expect(saved.lastAttemptAt, manualJoin ? clock.now() : null);
          expect(saved.adaptiveState.interval, const Duration(hours: 24));
          await harness.pump(tester, const SizedBox());
        },
      );
    }
  }
  testWidgets(
    'six-source runs resume oldest untouched sources after persisted state reload',
    (tester) async {
      final clock = Clock.fixed(checkedAt.add(const Duration(days: 2)));
      final first = PinnedSearchHarness(
        clock: clock,
        networkAllowed: true,
        scheduler: SearchRefreshScheduler(clock: clock, spacing: Duration.zero),
      );
      await tester.runAsync(() async {
        await first.seed([
          for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'])
            pinnedFixture(id: id, query: id),
        ]);
        await first.container.read(searchSubscriptionsProvider.future);
      });
      await first.pump(tester, const SearchRefreshLifecycle(child: SizedBox()));
      await drainRefresh(tester);
      expect(first.requests.map((r) => r.query), [
        'a',
        'b',
        'c',
        'd',
        'e',
        'f',
      ]);
      final persisted = await first.repository.getAll();
      await first.pump(tester, const SizedBox());
      first.dispose();
      final restarted = PinnedSearchHarness(
        clock: clock,
        networkAllowed: true,
        scheduler: SearchRefreshScheduler(clock: clock, spacing: Duration.zero),
      );
      await tester.runAsync(() async {
        await restarted.seed(persisted);
        await restarted.container.read(searchSubscriptionsProvider.future);
      });
      await restarted.pump(
        tester,
        const SearchRefreshLifecycle(child: SizedBox()),
      );
      await drainRefresh(tester);
      expect(restarted.requests.map((r) => r.query), ['g', 'h', 'i', 'j']);
      await restarted.pump(tester, const SizedBox());
      restarted.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'admission budget rejects expired queued work when physical dispatch becomes available',
    (tester) async {
      var now = checkedAt.add(const Duration(days: 2));
      final clock = Clock(() => now);
      final api = ApiRequestCoordinator();
      final key = ApiQuotaKey.fromUri(Uri.parse('https://queued.test'));
      final active = await tester.runAsync(
        () async => [for (var i = 0; i < 4; i++) await api.acquire(key)],
      );
      final harness = PinnedSearchHarness(
        clock: clock,
        networkAllowed: true,
        scheduler: SearchRefreshScheduler(clock: clock, spacing: Duration.zero),
        beforeDispatch: () async {
          final context = ApiRequestContext.current();
          final permit = await api.acquire(key, context: context);
          permit.release();
        },
      );
      await tester.runAsync(() async {
        await harness.seed([pinnedFixture(query: 'cat')]);
        await harness.container.read(searchSubscriptionsProvider.future);
      });
      final coordinator = harness.container.read(
        searchRefreshCoordinatorProvider.notifier,
      );
      coordinator.setForeground(true);
      await drainRefresh(tester);
      expect(api.snapshot(key).queued, 1);
      expect(
        harness.container
            .read(searchSubscriptionsProvider)
            .requireValue
            .pendingRefreshIds,
        {'cats'},
      );
      now = now.add(const Duration(seconds: 21));
      await tester.pump(const Duration(seconds: 21));
      await drainRefresh(tester);
      expect(harness.requests, isEmpty);
      for (final permit in active!) {
        permit.release();
      }
      await drainRefresh(tester);
      expect(api.snapshot(key).queued, 0);
      expect(
        harness.container
            .read(searchSubscriptionsProvider)
            .requireValue
            .pendingRefreshIds,
        isEmpty,
      );
      expect(harness.requests, isEmpty);
      coordinator.setForeground(false);
      harness.dispose();
      api.dispose();
    },
  );

  testWidgets(
    'lifecycle unmount cancels spacing and future periodic admissions',
    (tester) async {
      final clock = Clock.fixed(checkedAt.add(const Duration(days: 2)));
      final harness = PinnedSearchHarness(
        clock: clock,
        networkAllowed: true,
        scheduler: SearchRefreshScheduler(
          clock: clock,
        ),
      );
      await tester.runAsync(() async {
        await harness.seed([
          pinnedFixture(id: 'a', query: 'cat'),
          pinnedFixture(id: 'b', query: 'dog'),
        ]);
        await harness.container.read(searchSubscriptionsProvider.future);
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await harness.pump(
        tester,
        const SearchRefreshLifecycle(child: Scaffold(body: Text('App'))),
      );
      await drainRefresh(tester);
      expect(harness.requests, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await drainRefresh(tester);
      await tester.pump(const Duration(minutes: 3));
      expect(harness.requests, hasLength(1));
      harness.dispose();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
