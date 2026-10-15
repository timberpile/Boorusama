// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../foundation/app_update/src/providers.dart';
import '../../../../foundation/app_update/src/types/update_status.dart';
import '../../../../foundation/app_update/src/widgets/app_update_dialog.dart';
import '../providers/settings_notifier.dart';
import '../providers/settings_provider.dart';
import '../widgets/settings_page_scaffold.dart';

class UpdatesSettingsPage extends ConsumerStatefulWidget {
  const UpdatesSettingsPage({super.key});

  @override
  ConsumerState<UpdatesSettingsPage> createState() =>
      _UpdatesSettingsPageState();
}

class _UpdatesSettingsPageState extends ConsumerState<UpdatesSettingsPage> {
  bool _checking = false;
  UpdateStatus? _manualResult;

  Future<void> _checkNow() async {
    if (_checking) return;
    setState(() => _checking = true);
    final result = await ref.read(appUpdateCoordinatorProvider).check(force: true);
    if (!mounted) return;
    ref.invalidate(appUpdateStatusProvider);
    setState(() {
      _manualResult = result;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final coordinator = ref.watch(appUpdateCoordinatorProvider);
    final checkResult = ref.watch(appUpdateStatusProvider);
    final status = _manualResult ?? checkResult.valueOrNull;
    final checkedAt = coordinator.lastCheckedAt;

    return SettingsPageScaffold(
      title: Text(context.t.app_update.updates),
      children: [
        const SizedBox(height: 8),
        KurumiSwitchListTile(
          title: Text(context.t.app_update.automatic_checks),
          value: settings.automaticUpdateChecks,
          onChanged: (value) async {
            await ref
                .read(settingsNotifierProvider.notifier)
                .updateWith((settings) =>
                    settings.copyWith(automaticUpdateChecks: value));
          },
        ),
        const SizedBox(height: 8),
        ListTile(
          title: Text(
            switch (status) {
              UpdateAvailable() => context.t.app_update.update_available,
              UpdateError() => context.t.app_update.check_failed,
              UpdateNotAvailable() when checkedAt != null =>
                context.t.app_update.up_to_date,
              _ => context.t.app_update.never_checked,
            },
          ),
          subtitle: switch (status) {
            UpdateAvailable(:final storeVersion) => Text(storeVersion),
            _ when checkedAt != null => Text(
              '${context.t.app_update.last_checked}: '
              '${MaterialLocalizations.of(context).formatMediumDate(checkedAt.toLocal())}',
            ),
            _ => null,
          },
          trailing: status is UpdateAvailable
              ? IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  tooltip: context.t.app_update.update,
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => AppUpdateDialog(status: status),
                  ),
                )
              : null,
          onTap: status is UpdateAvailable
              ? () => showDialog(
                  context: context,
                  builder: (_) => AppUpdateDialog(status: status),
                )
              : null,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            onPressed: _checking ? null : _checkNow,
            child: Text(context.t.app_update.check_now),
          ),
        ),
        if (_checking) const LinearProgressIndicator(),
      ],
    );
  }
}
