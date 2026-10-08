import 'package:boorusama/core/search/subscriptions/src/services/conservative_refresh_policy.dart';
import 'package:boorusama/core/settings/src/types/search_refresh_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 3, 12);

  test(
    'info timing uses the same latest activity, effective interval and cooldown as admission',
    () {
      final state = const AdaptiveRefreshState().after(
        AdaptiveRefreshResult.newPostsAutomatic,
      );
      final source = RefreshSourceCandidate(
        id: 'a',
        pinned: true,
        createdAt: now.subtract(const Duration(days: 3)),
        lastMaterialEditAt: now.subtract(const Duration(days: 2)),
        lastSuccessfulCheckAt: now.subtract(const Duration(hours: 13)),
        lastAttemptAt: now.subtract(const Duration(hours: 2)),
        adaptiveState: state,
        cooldownUntil: now.add(const Duration(hours: 20)),
      );
      final timing = conservativeRefreshTiming(
        source: source,
        settings: const SearchRefreshSettings(),
        now: now,
      );
      expect(timing.interval, const Duration(hours: 12));
      expect(timing.dueAt, now.add(const Duration(hours: 10)));
      expect(timing.eligibleAt, now.add(const Duration(hours: 20)));
      final fixed = conservativeRefreshTiming(
        source: source,
        settings: const SearchRefreshSettings(
          mode: SearchRefreshMode.fixed,
          fixedIntervalHours: 48,
        ),
        now: now,
      );
      expect(fixed.interval, const Duration(days: 2));
      expect(fixed.dueAt, now.add(const Duration(hours: 46)));
    },
  );

  test(
    'new and legacy preferences start at 24 hours without a five-minute run',
    () {
      expect(const SearchRefreshSettings().interval, const Duration(hours: 24));
      expect(
        SearchRefreshSettings.parse(const {
          'enabled': false,
          'intervalMinutes': 5,
        }).enabled,
        false,
      );
      expect(
        SearchRefreshSettings.parse(const {
          'enabled': false,
          'intervalMinutes': 5,
        }).interval,
        const Duration(hours: 24),
      );
      expect(
        SearchRefreshSettings.parse(const {
          'enabled': true,
          'intervalMinutes': 15,
        }).toJson()['schemaVersion'],
        2,
      );
    },
  );

  test('invalid persisted fixed intervals fall back to a selectable day', () {
    final settings = SearchRefreshSettings.parse(const {
      'schemaVersion': 2,
      'mode': 'fixed',
      'fixedIntervalHours': 7,
    });
    expect(settings.fixedIntervalHours, 24);
  });

  test('switching back to Adaptive uses its own 24-hour starting interval', () {
    const fixed = SearchRefreshSettings(
      mode: SearchRefreshMode.fixed,
      fixedIntervalHours: 48,
    );
    expect(
      fixed.copyWith(mode: SearchRefreshMode.adaptive).interval,
      const Duration(hours: 24),
    );
  });

  test(
    'new posts halve adaptive intervals once per check within six hours',
    () {
      var state = const AdaptiveRefreshState();
      for (final expected in [12, 6, 6]) {
        state = state.after(AdaptiveRefreshResult.newPostsAutomatic);
        expect(state.interval, Duration(hours: expected));
      }
    },
  );

  test('two empty automatic checks double once and stop at seven days', () {
    var state = const AdaptiveRefreshState();
    for (final expected in [24, 48, 48, 96, 96, 168, 168]) {
      state = state.after(AdaptiveRefreshResult.emptyAutomatic);
      expect(state.interval, Duration(hours: expected));
    }
  });

  test(
    'manual empties and unsuccessful checks do not slow adaptive checks',
    () {
      var state = const AdaptiveRefreshState().after(
        AdaptiveRefreshResult.emptyAutomatic,
      );
      for (final result in [
        AdaptiveRefreshResult.emptyManual,
        AdaptiveRefreshResult.failed,
        AdaptiveRefreshResult.cancelled,
        AdaptiveRefreshResult.baseline,
        AdaptiveRefreshResult.rateLimited,
      ]) {
        state = state.after(result);
        expect(state.interval, const Duration(hours: 24));
        expect(state.consecutiveEmptyAutomatic, 1);
      }
      expect(
        state.after(AdaptiveRefreshResult.emptyAutomatic).interval,
        const Duration(hours: 48),
      );
    },
  );

  test(
    'manual new posts leave an adaptive interval and empty streak unchanged',
    () {
      final before = const AdaptiveRefreshState().after(
        AdaptiveRefreshResult.emptyAutomatic,
      );
      final after = before.after(AdaptiveRefreshResult.newPostsManual);

      expect(after.interval, const Duration(hours: 24));
      expect(after.consecutiveEmptyAutomatic, 1);
      expect(
        after.after(AdaptiveRefreshResult.emptyAutomatic).interval,
        const Duration(hours: 48),
      );
    },
  );

  test(
    'a bounded run deduplicates shared feed sources and fairly selects oldest due checks',
    () {
      final plan = planConservativeRefresh(
        now: now,
        settings: const SearchRefreshSettings(),
        foreground: true,
        network: RefreshNetwork.wifi,
        batterySaver: false,
        sources: [
          for (var i = 0; i < 8; i++)
            RefreshSourceCandidate(
              id: '$i',
              pinned: i.isEven,
              feedSource: true,
              lastSuccessfulCheckAt: now.subtract(Duration(days: i + 2)),
            ),
          const RefreshSourceCandidate(id: '7', feedSource: true),
        ],
      );
      expect(plan.selectedIds, ['7', '6', '5', '4', '3', '2']);
    },
  );

  test(
    'a capped plan eventually selects a never-successful source after failed attempts',
    () {
      final createdAt = now.subtract(const Duration(days: 9));
      final first = planConservativeRefresh(
        now: now,
        settings: const SearchRefreshSettings(),
        foreground: true,
        network: RefreshNetwork.wifi,
        batterySaver: false,
        sources: [
          for (var i = 0; i < 7; i++)
            RefreshSourceCandidate(
              id: '$i',
              pinned: true,
              createdAt: createdAt,
            ),
        ],
      );
      expect(first.selectedIds, ['0', '1', '2', '3', '4', '5']);

      final second = planConservativeRefresh(
        now: now.add(const Duration(days: 1)),
        settings: const SearchRefreshSettings(),
        foreground: true,
        network: RefreshNetwork.wifi,
        batterySaver: false,
        sources: [
          for (var i = 0; i < 7; i++)
            RefreshSourceCandidate(
              id: '$i',
              pinned: true,
              createdAt: createdAt,
              lastAttemptAt: i < 6 ? now : null,
            ),
        ],
      );
      expect(second.selectedIds, ['6', '0', '1', '2', '3', '4']);
    },
  );

  test('failed checks do not starve a previously successful due source', () {
    final createdAt = now.subtract(const Duration(days: 4));
    ConservativeRefreshPlan plan({
      required DateTime at,
      required DateTime failedAttemptAt,
    }) => planConservativeRefresh(
      now: at,
      settings: const SearchRefreshSettings(),
      foreground: true,
      network: RefreshNetwork.wifi,
      batterySaver: false,
      sources: [
        for (var i = 0; i < 6; i++)
          RefreshSourceCandidate(
            id: '$i',
            pinned: true,
            createdAt: createdAt,
            lastAttemptAt: failedAttemptAt,
          ),
        RefreshSourceCandidate(
          id: '6',
          pinned: true,
          createdAt: createdAt,
          lastSuccessfulCheckAt: now.subtract(const Duration(days: 2)),
        ),
      ],
    );
    expect(
      plan(
        at: now,
        failedAttemptAt: now.subtract(const Duration(days: 3)),
      ).selectedIds,
      ['0', '1', '2', '3', '4', '5'],
    );
    expect(
      plan(
        at: now.add(const Duration(days: 1)),
        failedAttemptAt: now,
      ).selectedIds.first,
      '6',
    );
  });

  test(
    'a source shared by a feed and pin remains eligible through the enabled pin scope',
    () {
      final plan = planConservativeRefresh(
        now: now,
        settings: const SearchRefreshSettings(followingFeedsEnabled: false),
        foreground: true,
        network: RefreshNetwork.wifi,
        batterySaver: false,
        sources: [
          RefreshSourceCandidate(
            id: 'shared',
            feedSource: true,
            createdAt: now.subtract(const Duration(days: 2)),
          ),
          RefreshSourceCandidate(
            id: 'shared',
            pinned: true,
            createdAt: now.subtract(const Duration(days: 2)),
          ),
        ],
      );
      expect(plan.selectedIds, ['shared']);
    },
  );

  test(
    'foreground, network, cooldown, unsupported, and due time gate sources',
    () {
      final sources = [
        RefreshSourceCandidate(
          id: 'due',
          pinned: true,
          lastSuccessfulCheckAt: now.subtract(const Duration(days: 2)),
        ),
        RefreshSourceCandidate(
          id: 'recent',
          pinned: true,
          lastSuccessfulCheckAt: now.subtract(const Duration(hours: 23)),
        ),
        RefreshSourceCandidate(
          id: 'cooldown',
          pinned: true,
          cooldownUntil: now.add(const Duration(hours: 1)),
        ),
        const RefreshSourceCandidate(
          id: 'unsupported',
          feedSource: true,
          supported: false,
        ),
      ];
      final plan = planConservativeRefresh(
        now: now,
        settings: const SearchRefreshSettings(),
        foreground: true,
        network: RefreshNetwork.wifi,
        batterySaver: false,
        sources: sources,
      );
      expect(plan.selectedIds, ['due']);
      expect(plan.skipped['cooldown'], RefreshSkipReason.cooldown);
      expect(plan.skipped['unsupported'], RefreshSkipReason.unsupported);
      expect(plan.skipped['recent'], RefreshSkipReason.notDue);
      for (final circumstance in [
        (foreground: false, network: RefreshNetwork.wifi, batterySaver: false),
        (
          foreground: true,
          network: RefreshNetwork.metered,
          batterySaver: false,
        ),
        (foreground: true, network: RefreshNetwork.wifi, batterySaver: true),
      ]) {
        expect(
          planConservativeRefresh(
            now: now,
            settings: const SearchRefreshSettings(),
            foreground: circumstance.foreground,
            network: circumstance.network,
            batterySaver: circumstance.batterySaver,
            sources: sources,
          ).selectedIds,
          isEmpty,
        );
      }
    },
  );

  test(
    'metered connections pause automatic work even with the broader network preference',
    () {
      final plan = planConservativeRefresh(
        now: now,
        settings: const SearchRefreshSettings(wifiEthernetOnly: false),
        foreground: true,
        network: RefreshNetwork.metered,
        batterySaver: false,
        sources: const [RefreshSourceCandidate(id: 'due', pinned: true)],
      );
      expect(plan.selectedIds, isEmpty);
      expect(plan.skipped['due'], RefreshSkipReason.network);
    },
  );

  test(
    'a newly created source waits 24 hours and becomes due exactly at the boundary',
    () {
      final createdAt = now.subtract(const Duration(hours: 24));
      ConservativeRefreshPlan planAt(DateTime time) => planConservativeRefresh(
        now: time,
        settings: const SearchRefreshSettings(),
        foreground: true,
        network: RefreshNetwork.wifi,
        batterySaver: false,
        sources: [
          RefreshSourceCandidate(id: 'new', pinned: true, createdAt: createdAt),
        ],
      );
      expect(
        planAt(now.subtract(const Duration(microseconds: 1))).selectedIds,
        isEmpty,
      );
      expect(planAt(now).selectedIds, ['new']);
      expect(
        conservativeRefreshTiming(
          source: RefreshSourceCandidate(
            id: 'new',
            pinned: true,
            createdAt: createdAt,
          ),
          settings: const SearchRefreshSettings(),
          now: now,
        ).dueAt,
        now,
      );
    },
  );

  test(
    'a failed first attempt and a material edit restart the source interval',
    () {
      final sources = [
        RefreshSourceCandidate(
          id: 'failed',
          pinned: true,
          createdAt: now.subtract(const Duration(days: 3)),
          lastAttemptAt: now.subtract(const Duration(hours: 1)),
        ),
        RefreshSourceCandidate(
          id: 'edited',
          pinned: true,
          createdAt: now.subtract(const Duration(days: 3)),
          lastMaterialEditAt: now.subtract(const Duration(hours: 2)),
        ),
      ];
      final plan = planConservativeRefresh(
        now: now,
        settings: const SearchRefreshSettings(),
        foreground: true,
        network: RefreshNetwork.wifi,
        batterySaver: false,
        sources: sources,
      );
      expect(plan.selectedIds, isEmpty);
      expect(plan.skipped['failed'], RefreshSkipReason.notDue);
      expect(plan.skipped['edited'], RefreshSkipReason.notDue);
      expect(
        conservativeRefreshTiming(
          source: sources.first,
          settings: const SearchRefreshSettings(),
          now: now,
        ).dueAt,
        now.add(const Duration(hours: 23)),
      );
      expect(
        conservativeRefreshTiming(
          source: sources.last,
          settings: const SearchRefreshSettings(),
          now: now,
        ).dueAt,
        now.add(const Duration(hours: 22)),
      );
    },
  );

  test(
    'duplicate source timestamps use the latest cooldown and success in either order',
    () {
      final older = RefreshSourceCandidate(
        id: 'shared',
        pinned: true,
        createdAt: now.subtract(const Duration(days: 4)),
        lastSuccessfulCheckAt: now.subtract(const Duration(days: 3)),
        cooldownUntil: now.subtract(const Duration(hours: 1)),
      );
      final newer = RefreshSourceCandidate(
        id: 'shared',
        feedSource: true,
        createdAt: now.subtract(const Duration(days: 4)),
        lastSuccessfulCheckAt: now.subtract(const Duration(hours: 2)),
        cooldownUntil: now.add(const Duration(hours: 2)),
      );
      for (final sources in [
        [older, newer],
        [newer, older],
      ]) {
        final plan = planConservativeRefresh(
          now: now,
          settings: const SearchRefreshSettings(),
          foreground: true,
          network: RefreshNetwork.wifi,
          batterySaver: false,
          sources: sources,
        );
        expect(plan.selectedIds, isEmpty);
        expect(plan.skipped['shared'], RefreshSkipReason.cooldown);
      }
    },
  );
}
