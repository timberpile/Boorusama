import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import '../../../../settings/providers.dart';
import '../../../../settings/src/types/search_refresh_settings.dart';

Future<void> showSearchRefreshSettingsDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (_) => const _SearchRefreshSettingsDialog(),
    );

class _SearchRefreshSettingsDialog extends ConsumerWidget {
  const _SearchRefreshSettingsDialog();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final refresh = settings.searchRefresh;
    Future<void> update(SearchRefreshSettings value) async {
      try {
        final saved = await ref
            .read(settingsNotifierProvider.notifier)
            .updateSettings(
              ref.read(settingsProvider).copyWith(searchRefresh: value),
            );
        if (!saved) throw StateError('Settings write failed');
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t.pinned_searches.operation_failed)),
          );
        }
      }
    }

    return AlertDialog(
      title: Text(context.t.pinned_searches.refresh_settings),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: Text(context.t.pinned_searches.automatic_refresh),
            value: refresh.enabled,
            onChanged: (enabled) => update(refresh.copyWith(enabled: enabled)),
          ),
          DropdownButton<int>(
            value: refresh.intervalMinutes,
            isExpanded: true,
            items: [
              for (final minutes in {
                ...[5, 15, 30, 60],
                refresh.intervalMinutes,
              }.toList()..sort())
                DropdownMenuItem(
                  value: minutes,
                  child: Text(
                    context.t.pinned_searches.refresh_interval.replaceAll(
                      '{minutes}',
                      '$minutes',
                    ),
                  ),
                ),
            ],
            onChanged: refresh.enabled
                ? (minutes) {
                    if (minutes != null) {
                      update(refresh.copyWith(intervalMinutes: minutes));
                    }
                  }
                : null,
          ),
          Text(context.t.pinned_searches.foreground_refresh_description),
        ],
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
