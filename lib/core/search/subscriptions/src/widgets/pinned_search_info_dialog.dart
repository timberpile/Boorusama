import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../boorus/engine/providers.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../settings/providers.dart';
import '../../../../settings/src/types/search_refresh_settings.dart';
import '../../../../widgets/time_pulse.dart';
import '../providers/search_refresh_coordinator.dart';
import '../providers/search_subscriptions_notifier.dart';
import '../refresh/search_refresh_query_adapter.dart';
import '../services/conservative_refresh_policy.dart';
import 'search_refresh_error_text.dart';

class PinnedSearchInfoDialog extends ConsumerWidget {
  const PinnedSearchInfoDialog({
    required this.subscriptionId,
    this.feedSource = false,
    super.key,
  });
  final String subscriptionId;
  final bool feedSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.t.pinned_searches;
    final source = ref
        .watch(searchSubscriptionsProvider)
        .valueOrNull
        ?.subscriptions
        .firstWhereOrNull((source) => source.id == subscriptionId);
    final settings = ref.watch(settingsProvider).searchRefresh;
    final status = ref.watch(searchRefreshStatusProvider);
    final profile = ref
        .watch(booruConfigProvider)
        .firstWhereOrNull((profile) => profile.id == source?.profileId);
    final adapter = profile == null
        ? null
        : ref
              .watch(booruRepoProvider(profile.auth))
              ?.searchRefreshQueryAdapter(profile.auth);
    final supported =
        source != null && supportsSearchRefreshQuery(adapter, source.query);
    String duration(Duration value) {
      final parts = <String>[];
      final days = value.inDays;
      final hours = value.inHours % 24;
      final minutes = value.inMinutes % 60;
      if (days > 0) parts.add(strings.interval_days(n: days));
      if (hours > 0) parts.add(strings.interval_hours(n: hours));
      if (minutes > 0) parts.add(strings.interval_minutes(n: minutes));
      return parts.join(' ');
    }

    return AlertDialog(
      title: Text(strings.info),
      scrollable: true,
      content: source == null
          ? Text(strings.refresh_search_unavailable)
          : TimePulse(
              initial: clock.now(),
              updateInterval: const Duration(minutes: 1),
              builder: (context, _) {
                final now = clock.now();
                String date(DateTime value) => timeago.format(
                  value.toLocal(),
                  locale: context.locale.toLanguageTag(),
                  clock: now.toLocal(),
                );
                final cooldown = status.deferredUntilById[source.id];
                final timing = conservativeRefreshTiming(
                  source: RefreshSourceCandidate(
                    id: source.id,
                    pinned: !feedSource,
                    feedSource: feedSource,
                    createdAt: source.createdAt,
                    lastMaterialEditAt: source.lastMaterialEditAt,
                    lastAttemptAt: source.lastAttemptAt,
                    lastSuccessfulCheckAt: source.lastSuccessfulCheckAt,
                    adaptiveState: source.adaptiveState,
                    cooldownUntil: cooldown,
                  ),
                  settings: settings,
                  now: now,
                );
                final scheduled =
                    profile != null &&
                    supported &&
                    settings.enabled &&
                    (feedSource
                        ? settings.followingFeedsEnabled
                        : settings.pinnedSearchesEnabled);
                final next = profile == null
                    ? strings.refresh_profile_unavailable
                    : !supported
                    ? strings.refresh_not_scheduled_unsupported
                    : !settings.enabled
                    ? strings.refresh_not_scheduled_disabled
                    : !(feedSource
                          ? settings.followingFeedsEnabled
                          : settings.pinnedSearchesEnabled)
                    ? strings.refresh_not_scheduled_scope
                    : now.isBefore(timing.eligibleAt)
                    ? strings.refresh_in(
                        duration: duration(
                          Duration(
                            minutes:
                                (timing.eligibleAt
                                            .difference(now)
                                            .inMilliseconds /
                                        Duration.millisecondsPerMinute)
                                    .ceil(),
                          ),
                        ),
                      )
                    : strings.refresh_due_now;
                final mode = settings.mode == SearchRefreshMode.adaptive
                    ? strings.interval_adaptive
                    : strings.interval_fixed;
                final pauseStrings =
                    context.t.settings.pinned_searches_and_feeds;
                final pause = switch (status.paused) {
                  RefreshSkipReason.inactive => pauseStrings.pause_foreground,
                  RefreshSkipReason.network => pauseStrings.pause_network,
                  RefreshSkipReason.batterySaver => pauseStrings.pause_battery,
                  RefreshSkipReason.unsupported => pauseStrings.pause_unknown,
                  _ => null,
                };
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (source.name case final name?)
                      Text(strings.name_line(name: name)),
                    Text(strings.query_line(query: source.query)),
                    const SizedBox(height: 16),
                    Text(
                      source.lastSuccessfulCheckAt == null
                          ? strings.never_checked
                          : strings.last_checked.replaceAll(
                              '{date}',
                              date(source.lastSuccessfulCheckAt!),
                            ),
                    ),
                    if (source.lastAttemptAt case final attempted?)
                      Text(
                        switch (source.lastErrorKind) {
                          final kind? => strings.last_attempt_failed(
                            date: date(attempted),
                            message: searchRefreshErrorText(context, kind),
                          ),
                          null => strings.last_attempt_succeeded(
                            date: date(attempted),
                          ),
                        },
                      ),
                    const SizedBox(height: 16),
                    Text(
                      strings.current_refresh_interval.replaceAll(
                        '{value}',
                        mode.replaceAll(
                          '{duration}',
                          duration(timing.interval),
                        ),
                      ),
                    ),
                    Text(
                      strings.next_scheduled_refresh.replaceAll(
                        '{value}',
                        next,
                      ),
                    ),
                    if (scheduled && pause != null)
                      Text(pauseStrings.paused(reason: pause)),
                    if (scheduled && cooldown != null && now.isBefore(cooldown))
                      Text(strings.refresh_waiting_rate_limit),
                  ],
                );
              },
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t.generic.action.ok),
        ),
      ],
    );
  }
}
