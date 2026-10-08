import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/providers/search_refresh_coordinator.dart';
import 'package:boorusama/core/search/subscriptions/src/services/conservative_refresh_policy.dart';
import 'package:boorusama/core/search/subscriptions/src/services/search_refresh_scheduler.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/pinned_search_info_dialog.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:clock/clock.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'pinned_search_test_utils.dart';
import 'subscription_test_utils.dart';

void main() {
  final created = DateTime.utc(2026, 9, 14, 8);
  SearchSubscription source({
    AdaptiveRefreshState state = const AdaptiveRefreshState(),
    String query = 'cat',
    String profileId = '00000000-0000-4000-8000-00000000000c',
    bool checked = true,
    String? name = 'Cats',
    DateTime? attemptedAt,
    SearchRefreshErrorKind? error,
  }) => SearchSubscription(
    id: 'cats',
    profileId: profileId,
    query: query,
    name: name,
    lastAttemptAt: attemptedAt,
    lastErrorKind: error,
    position: 0,
    createdAt: created,
    lastSuccessfulCheckAt: checked ? created : null,
    highestSeenPostId: checked ? 0 : null,
    adaptiveState: state,
    previews: const [],
    recentPostIdentities: const [],
    unreadCount: 0,
  );
  Future<void> mount(
    WidgetTester tester,
    PinnedSearchHarness harness, {
    String locale = 'en-US',
    bool narrow = false,
  }) async {
    await tester.runAsync(() => ensureI18nInitialized(locale));
    await tester.pumpWidget(
      harness.wrap(
        Builder(
          builder: (context) => MaterialApp(
            builder: themeBuilder,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(narrow ? 2 : 1),
              ),
              child: const Scaffold(
                body: PinnedSearchInfoDialog(subscriptionId: 'cats'),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<T> settleOperation<T>(WidgetTester tester, Future<T> operation) async {
    var completed = false;
    final observed = operation.whenComplete(() => completed = true);
    await drain(tester);
    expect(
      completed,
      isTrue,
      reason: 'Operation settles while widget work is pumped',
    );
    return observed;
  }

  for (final name in <String?>[null, 'Cats', 'cat']) {
    testWidgets('Info labels stored query and explicit name $name', (
      tester,
    ) async {
      final harness = PinnedSearchHarness();
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        await harness.seed([source(name: name, checked: false)]);
        await harness.container.read(searchSubscriptionsProvider.future);
      });
      await mount(tester, harness);
      expect(find.text('Query: cat'), findsOneWidget);
      expect(
        find.textContaining('Name:'),
        name == null ? findsNothing : findsOneWidget,
      );
      if (name != null) expect(find.text('Name: $name'), findsOneWidget);
      expect(find.text('cat'), findsNothing);
      expect(find.textContaining('Last attempt:'), findsNothing);
      expect(find.textContaining('Succeeded'), findsNothing);
      expect(find.textContaining('Failed'), findsNothing);
      expect(find.text('Never checked'), findsOneWidget);
    });
  }

  for (final error in <SearchRefreshErrorKind?>[
    null,
    ...SearchRefreshErrorKind.values,
  ]) {
    testWidgets(
      'Info shows last outcome $error and separate successful history',
      (
        tester,
      ) async {
        final harness = PinnedSearchHarness();
        addTearDown(harness.dispose);
        final attempted = created.add(const Duration(days: 1));
        await tester.runAsync(() async {
          await harness.seed([source(attemptedAt: attempted, error: error)]);
          await harness.container.read(searchSubscriptionsProvider.future);
        });
        await mount(tester, harness);
        final context = tester.element(find.byType(PinnedSearchInfoDialog));
        final strings = context.t.pinned_searches;
        final message = switch (error) {
          SearchRefreshErrorKind.network => strings.error_network,
          SearchRefreshErrorKind.authentication => strings.error_authentication,
          SearchRefreshErrorKind.query => strings.error_query,
          SearchRefreshErrorKind.pagination => strings.error_pagination,
          SearchRefreshErrorKind.parsing => strings.error_parsing,
          SearchRefreshErrorKind.unsupported => strings.error_unsupported,
          SearchRefreshErrorKind.other => strings.error_other,
          SearchRefreshErrorKind.tagLimit => strings.error_tag_limit,
          SearchRefreshErrorKind.rateLimited => strings.error_rate_limited,
          null => null,
        };
        String date(DateTime value) => timeago.format(
          value.toLocal(),
          locale: context.locale.toLanguageTag(),
          clock: clock.now().toLocal(),
        );
        expect(find.text('Last checked: ${date(created)}'), findsOneWidget);
        expect(
          find.text(
            'Last attempt: ${date(attempted)} · ${message == null ? 'Succeeded' : 'Failed · $message'}',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Message:'), findsNothing);
      },
    );
  }

  testWidgets('open Info clears failure after a real successful refresh', (
    tester,
  ) async {
    var now = created.add(const Duration(days: 2));
    var fail = true;
    final harness = PinnedSearchHarness(
      clock: Clock(() => now),
      fetchPosts: (_, _, _, _) async => fail
          ? Either.left(
              UnknownError(error: 'test failure', message: 'test failure'),
            )
          : Either.of(const PostResult(posts: <Post>[], total: 0)),
    );
    addTearDown(harness.dispose);
    await tester.runAsync(() async {
      await harness.seed([source()]);
      await harness.container.read(searchSubscriptionsProvider.future);
    });
    await mount(tester, harness);
    final notifier = harness.container.read(
      searchSubscriptionsProvider.notifier,
    );
    await settleOperation(tester, notifier.refresh('cats'));
    await tester.pump();
    expect(
      find.textContaining('Failed · Could not refresh this search. Try again.'),
      findsOneWidget,
    );
    fail = false;
    now = now.add(const Duration(hours: 1));
    await settleOperation(tester, notifier.refresh('cats'));
    await tester.pump();
    expect(find.textContaining('Succeeded'), findsOneWidget);
    expect(find.textContaining('Failed'), findsNothing);
    expect(find.textContaining('Could not refresh'), findsNothing);
    final saved = (await harness.repository.getAll()).single;
    expect(saved.lastErrorKind, isNull);
    expect(saved.lastSuccessfulCheckAt, now);
    expect(saved.lastAttemptAt, now);
  });

  testWidgets('Info relative history updates with its minute pulse', (
    tester,
  ) async {
    var now = created.add(const Duration(minutes: 30));
    final testClock = Clock(() => now);
    final harness = PinnedSearchHarness(clock: testClock);
    addTearDown(harness.dispose);
    await tester.runAsync(() async {
      await harness.seed([
        source(attemptedAt: created.add(const Duration(minutes: 10))),
      ]);
      await harness.container.read(searchSubscriptionsProvider.future);
    });
    await withClock(testClock, () async {
      await mount(tester, harness);
      expect(find.text('Last checked: 30 minutes ago'), findsOneWidget);
      expect(
        find.text('Last attempt: 20 minutes ago · Succeeded'),
        findsOneWidget,
      );
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Last checked: 31 minutes ago'), findsOneWidget);
      expect(
        find.text('Last attempt: 21 minutes ago · Succeeded'),
        findsOneWidget,
      );
      expect(harness.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });

  for (final unrelatedDue in [false, true]) {
    testWidgets(
      'automatic cooldown survives next-minute ${unrelatedDue ? "unrelated" : "empty"} plans in open Info',
      (tester) async {
        var now = created.add(const Duration(days: 2));
        final retryAt = now.add(const Duration(minutes: 30));
        final testClock = Clock(() => now);
        final harness = PinnedSearchHarness(
          clock: testClock,
          networkAllowed: true,
          scheduler: SearchRefreshScheduler(
            clock: testClock,
            spacing: Duration.zero,
          ),
          fetchPosts: (_, query, _, _) async =>
              query == 'cat' && now.isBefore(retryAt)
              ? Either.left(RateLimitedError(retryAt))
              : Either.of(const PostResult(posts: <Post>[], total: 0)),
        );
        addTearDown(harness.dispose);
        await tester.runAsync(() async {
          await harness.seed([
            source(),
            if (unrelatedDue)
              SearchSubscription(
                id: 'dogs',
                profileId: testProfile.id,
                query: 'dog',
                position: 1,
                createdAt: now.subtract(
                  const Duration(hours: 23, minutes: 59, seconds: 30),
                ),
                previews: const [],
                recentPostIdentities: const [],
                unreadCount: 0,
              ),
          ]);
          await harness.container.read(searchSubscriptionsProvider.future);
        });
        final writes = harness.box.mutationCount;
        final coordinator = harness.container.read(
          searchRefreshCoordinatorProvider.notifier,
        );
        await withClock(testClock, () async {
          coordinator.setForeground(true);
          await drain(tester);
          expect(harness.requests.map((request) => request.query), ['cat']);
          expect(harness.box.mutationCount, writes);
          await mount(tester, harness);
          expect(
            find.text('Next refresh: in 30 minutes'),
            findsOneWidget,
          );
          expect(find.text('Waiting for the site rate limit.'), findsOneWidget);

          for (final remainingMinutes in [29, 28]) {
            now = now.add(const Duration(minutes: 1));
            await tester.pump(const Duration(minutes: 1));
            await drain(tester);
            expect(
              harness.container
                  .read(searchRefreshStatusProvider)
                  .deferredUntilById,
              {'cats': retryAt},
            );
            expect(
              find.text('Next refresh: in $remainingMinutes minutes'),
              findsOneWidget,
            );
            expect(
              find.text('Waiting for the site rate limit.'),
              findsOneWidget,
            );
            expect(find.textContaining('Due now'), findsNothing);
            expect(harness.requests.map((request) => request.query), [
              'cat',
              if (unrelatedDue) 'dog',
            ]);
          }
          final saved = (await harness.repository.getAll()).firstWhere(
            (item) => item.id == 'cats',
          );
          expect(saved.lastAttemptAt, isNull);
          expect(saved.lastSuccessfulCheckAt, created);
          now = retryAt;
          await tester.pump(const Duration(minutes: 1));
          await drain(tester);
          expect(harness.requests.map((request) => request.query), [
            'cat',
            if (unrelatedDue) 'dog',
            'cat',
          ]);
          expect(
            harness.container
                .read(searchRefreshStatusProvider)
                .deferredUntilById,
            isEmpty,
          );
          coordinator.setForeground(false);
          await tester.pumpWidget(const SizedBox());
        });
      },
    );
  }

  for (final example in [
    (
      locale: 'en-US',
      initial: 'Next refresh: in 30 minutes',
      afterMinute: 'Next refresh: in 29 minutes',
      due: 'Next refresh: Due now',
      note:
          'Automatic checks run while the app is open; checks may start later.',
    ),
    (
      locale: 'de-DE',
      initial: 'Nächste Aktualisierung: in 30 Minuten',
      afterMinute: 'Nächste Aktualisierung: in 29 Minuten',
      due: 'Nächste Aktualisierung: Jetzt fällig',
      note:
          'Automatische Prüfungen laufen bei geöffneter App; sie können später beginnen.',
    ),
  ]) {
    testWidgets(
      'Info future timing follows its minute pulse without requests or writes in ${example.locale}',
      (tester) async {
        var now = created.add(const Duration(hours: 23, minutes: 30));
        final harness = PinnedSearchHarness(clock: Clock(() => now));
        addTearDown(harness.dispose);
        addTearDown(() => ensureI18nInitialized('en-US'));
        await tester.runAsync(() async {
          await harness.seed([source(checked: false)]);
          await harness.container.read(searchSubscriptionsProvider.future);
        });
        final writes = [
          harness.box.mutationCount,
          harness.organizationBox.mutationCount,
          harness.settingsBox.mutationCount,
        ];
        await withClock(Clock(() => now), () async {
          await mount(tester, harness, locale: example.locale);
          expect(find.text(example.initial), findsOneWidget);
          expect(find.text(example.note), findsNothing);
          now = now.add(const Duration(minutes: 1));
          await tester.pump(const Duration(minutes: 1));
          expect(find.text(example.afterMinute), findsOneWidget);
          now = now.add(const Duration(minutes: 29));
          await tester.pump(const Duration(minutes: 1));
          expect(find.text(example.due), findsOneWidget);
          expect(harness.requests, isEmpty);
          expect([
            harness.box.mutationCount,
            harness.organizationBox.mutationCount,
            harness.settingsBox.mutationCount,
          ], writes);
          expect(
            harness.container.exists(searchRefreshCoordinatorProvider),
            isFalse,
          );
          await tester.pumpWidget(const SizedBox());
        });
      },
    );
  }
  testWidgets(
    'open Info follows real automatic outcomes and settings instead of a tapped snapshot',
    (tester) async {
      var now = created.add(const Duration(days: 2));
      var id = 0;
      var additions = true;
      final harness = PinnedSearchHarness(
        clock: Clock(() => now),
        fetchPosts: (_, _, _, _) async => Either.of(
          PostResult(
            posts: additions ? [testSearchPost(++id, now)] : <Post>[],
            total: 1,
          ),
        ),
      );
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        await harness.seed([source()]);
        await harness.container.read(searchSubscriptionsProvider.future);
      });
      await withClock(Clock(() => now), () async {
        await mount(tester, harness);
        for (final hours in [12, 6]) {
          await settleOperation(
            tester,
            harness.container
                .read(searchSubscriptionsProvider.notifier)
                .refresh('cats', requestClass: ApiRequestClass.automatic),
          );
          await tester.pump();
          expect(
            find.text('Refresh interval: Adaptive · $hours hours'),
            findsOneWidget,
          );
          now = now.add(const Duration(days: 1));
        }
        await settleOperation(
          tester,
          harness.container
              .read(searchSubscriptionsProvider.notifier)
              .edit(
                'cats',
                profileId: '00000000-0000-4000-8000-00000000000c',
                query: 'new-cat',
                name: 'Cats',
              ),
        );
        await tester.pump();
        expect(find.text('Refresh interval: Adaptive · 1 day'), findsOneWidget);
        expect(find.text('Query: new-cat'), findsOneWidget);
        additions = false;
        for (final label in ['1 day', '2 days']) {
          await settleOperation(
            tester,
            harness.container
                .read(searchSubscriptionsProvider.notifier)
                .refresh('cats', requestClass: ApiRequestClass.automatic),
          );
          await tester.pump();
          expect(
            find.text('Refresh interval: Adaptive · $label'),
            findsOneWidget,
          );
          now = now.add(const Duration(days: 2));
        }
        await settleOperation(
          tester,
          harness.container
              .read(settingsNotifierProvider.notifier)
              .updateWith(
                (settings) => settings.copyWith(
                  searchRefresh: settings.searchRefresh.copyWith(
                    mode: SearchRefreshMode.fixed,
                    fixedIntervalHours: 48,
                  ),
                ),
              ),
        );
        await tester.pump();
        expect(find.text('Refresh interval: Fixed · 2 days'), findsOneWidget);
        await settleOperation(
          tester,
          harness.container
              .read(settingsNotifierProvider.notifier)
              .updateWith(
                (settings) => settings.copyWith(
                  searchRefresh: settings.searchRefresh.copyWith(
                    enabled: false,
                  ),
                ),
              ),
        );
        await tester.pump();
        expect(
          find.text(
            'Next refresh: Not scheduled — automatic checks disabled',
          ),
          findsOneWidget,
        );
        await settleOperation(
          tester,
          harness.container
              .read(searchSubscriptionsProvider.notifier)
              .delete('cats'),
        );
        await tester.pump();
        expect(
          find.text('This pinned search is no longer available.'),
          findsOneWidget,
        );
        expect(harness.requests, hasLength(5));
      });
    },
  );
  for (final example in [
    (hours: 84, label: '3 days 12 hours'),
    (hours: 10.5, label: '10 hours 30 minutes'),
  ]) {
    testWidgets(
      'Info shows the actual ${example.hours}-hour adaptive value rather than a preset',
      (tester) async {
        final harness = PinnedSearchHarness();
        addTearDown(harness.dispose);
        await tester.runAsync(() async {
          await harness.seed([
            source(
              state: AdaptiveRefreshState(
                interval: Duration(minutes: (example.hours * 60).round()),
              ),
            ),
          ]);
          await harness.container.read(searchSubscriptionsProvider.future);
        });
        await mount(tester, harness);
        expect(
          find.text('Refresh interval: Adaptive · ${example.label}'),
          findsOneWidget,
        );
      },
    );
  }
  for (final scenario in ['scope', 'unsupported', 'profile']) {
    testWidgets('Info does not invent a scheduled timestamp for $scenario', (
      tester,
    ) async {
      final harness = PinnedSearchHarness(
        settings: Settings.defaultSettings.copyWith(
          searchRefresh: SearchRefreshSettings(
            pinnedSearchesEnabled: scenario != 'scope',
          ),
        ),
      );
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        await harness.seed([
          source(
            query: scenario == 'unsupported' ? 'order:score' : 'cat',
            profileId: scenario == 'profile'
                ? '00000000-0000-4000-8000-0000000003e7'
                : '00000000-0000-4000-8000-00000000000c',
          ),
        ]);
        await harness.container.read(searchSubscriptionsProvider.future);
      });
      await mount(tester, harness);
      expect(
        find.textContaining('Next refresh: Not scheduled'),
        findsOneWidget,
      );
      expect(find.textContaining('Due now'), findsNothing);
      expect(harness.requests, isEmpty);
    });
  }
  testWidgets(
    'Info uses cached source cooldown and retains an honest temporary pause',
    (tester) async {
      final now = created.add(const Duration(days: 2));
      final harness = PinnedSearchHarness();
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        await harness.seed([source()]);
        await harness.container.read(searchSubscriptionsProvider.future);
      });
      final until = now.add(const Duration(hours: 2));
      final deferred = {'cats': until};
      harness.container
          .read(searchRefreshStatusProvider.notifier)
          .update(
            SearchRefreshStatus(
              paused: RefreshSkipReason.batterySaver,
              deferredUntilById: deferred,
            ),
          );
      deferred.clear();
      await withClock(Clock.fixed(now), () async {
        await mount(tester, harness);
        expect(find.text('Next refresh: in 2 hours'), findsOneWidget);
        expect(find.textContaining('Due now'), findsNothing);
        expect(find.text('Paused: battery saver is active'), findsOneWidget);
        expect(find.text('Waiting for the site rate limit.'), findsOneWidget);
        expect(harness.requests, isEmpty);
      });
    },
  );
  for (final locale in ['en-US', 'de-DE']) {
    testWidgets(
      'Info schedule wraps and keeps OK reachable at 280dp and 2x in $locale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(280, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(() => ensureI18nInitialized('en-US'));
        final harness = PinnedSearchHarness();
        addTearDown(harness.dispose);
        await tester.runAsync(() async {
          await harness.seed([
            source(
              state: const AdaptiveRefreshState(interval: Duration(hours: 84)),
              attemptedAt: created.add(const Duration(days: 1)),
              error: SearchRefreshErrorKind.unsupported,
            ),
          ]);
          await harness.container.read(searchSubscriptionsProvider.future);
        });
        await mount(tester, harness, locale: locale, narrow: true);
        expect(
          find.textContaining(
            locale == 'de-DE'
                ? 'Aktualisierungsintervall:'
                : 'Refresh interval:',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            locale == 'de-DE' ? 'Nächste Aktualisierung:' : 'Next refresh:',
          ),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextButton, 'OK').hitTestable(),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            locale == 'de-DE' ? '3 Tage 12 Stunden' : '3 days 12 hours',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
