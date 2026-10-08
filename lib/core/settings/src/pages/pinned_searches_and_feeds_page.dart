import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../providers/settings_notifier.dart';
import '../providers/settings_provider.dart';
import '../types/search_refresh_settings.dart';
import '../widgets/settings_page_scaffold.dart';
import '../../../search/subscriptions/src/providers/search_refresh_coordinator.dart';
import '../../../search/subscriptions/src/services/conservative_refresh_policy.dart';

class PinnedSearchesAndFeedsSettingsPage extends ConsumerWidget {
  const PinnedSearchesAndFeedsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refresh = ref.watch(settingsProvider).searchRefresh;
    final strings = context.t.settings.pinned_searches_and_feeds;
    final status = ref.watch(searchRefreshStatusProvider);
    final pause = switch (status.paused) {
      RefreshSkipReason.disabled => strings.pause_disabled,
      RefreshSkipReason.inactive => strings.pause_foreground,
      RefreshSkipReason.batterySaver => strings.pause_battery,
      RefreshSkipReason.unsupported => strings.pause_unknown,
      _ => strings.pause_network,
    };

    Future<void> update(
      SearchRefreshSettings Function(SearchRefreshSettings) change,
    ) async {
      bool saved;
      try {
        saved = await ref
            .read(settingsNotifierProvider.notifier)
            .updateWith(
              (settings) => settings.copyWith(
                searchRefresh: change(settings.searchRefresh),
              ),
            );
      } catch (_) {
        saved = false;
      }
      if (!saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.save_failed)),
        );
      }
    }

    return SettingsPageScaffold(
      title: Text(strings.title),
      children: [
        const SizedBox(height: 12),
        Text(
          strings.automatic_section,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(strings.periodic_description),
        KurumiSwitchListTile(
          title: Text(strings.enabled),
          value: refresh.enabled,
          onChanged: (value) =>
              update((current) => current.copyWith(enabled: value)),
        ),
        KurumiSwitchListTile(
          title: Text(strings.pinned_searches),
          value: refresh.pinnedSearchesEnabled,
          onChanged: refresh.enabled
              ? (value) => update(
                  (current) => current.copyWith(pinnedSearchesEnabled: value),
                )
              : null,
        ),
        KurumiSwitchListTile(
          title: Text(strings.following_feeds),
          value: refresh.followingFeedsEnabled,
          onChanged: refresh.enabled
              ? (value) => update(
                  (current) => current.copyWith(followingFeedsEnabled: value),
                )
              : null,
        ),
        KurumiSettingsTile<SearchRefreshMode>(
          title: Text(strings.interval),
          selectedOption: refresh.mode,
          items: SearchRefreshMode.values,
          onChanged: (mode) =>
              update((current) => current.copyWith(mode: mode)),
          isOptionEnabled: (_) => refresh.enabled,
          optionBuilder: (mode) => Text(
            mode == SearchRefreshMode.adaptive
                ? strings.adaptive
                : strings.fixed,
          ),
        ),
        if (refresh.mode == SearchRefreshMode.fixed)
          KurumiSettingsTile<int>(
            title: Text(strings.fixed_interval),
            selectedOption: refresh.fixedIntervalHours,
            items: const [6, 12, 24, 48, 168],
            onChanged: (hours) => update(
              (current) => current.copyWith(fixedIntervalHours: hours),
            ),
            isOptionEnabled: (_) => refresh.enabled,
            optionBuilder: (hours) => Text(switch (hours) {
              6 => strings.six_hours,
              12 => strings.twelve_hours,
              24 => strings.one_day,
              48 => strings.two_days,
              _ => strings.seven_days,
            }),
          ),
        const SizedBox(height: 20),
        Text(
          strings.network_section,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        KurumiSwitchListTile(
          title: Text(strings.wifi_only),
          value: refresh.wifiEthernetOnly,
          onChanged: refresh.enabled
              ? (value) => update(
                  (current) => current.copyWith(wifiEthernetOnly: value),
                )
              : null,
        ),
        Text(strings.foreground_only),
        const SizedBox(height: 20),
        Text(
          strings.status_section,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          strings.last_run(
            value: status.lastRunAt == null
                ? strings.never
                : MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(status.lastRunAt!.toLocal()),
          ),
        ),
        Text(
          status.running
              ? strings.running
              : status.paused == null
              ? strings.ready
              : strings.paused(reason: pause),
        ),
        Text(strings.eligible(count: status.eligible.toString())),
        const SizedBox(height: 16),
      ],
    );
  }
}
