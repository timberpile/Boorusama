// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../local_media/local_media_enrichment.dart';
import '../../../local_media/local_media_providers.dart';
import '../../../posts/cross_profile_lookup/lookup_preferences.dart';
import '../../../posts/cross_profile_lookup/lookup_selector.dart';
import '../../../tracking/providers.dart';
import '../providers/settings_notifier.dart';
import '../providers/settings_provider.dart';
import '../widgets/settings_page_scaffold.dart';
import 'app_lock_settings_page.dart';

class PrivacyPage extends ConsumerWidget {
  const PrivacyPage({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.watch(settingsNotifierProvider.notifier);
    final tracker = ref.watch(trackerProvider);
    final appLock = context.t.settings.privacy.app_lock;
    final lookup = ref.watch(lookupPreferencesProvider);
    final t = context.t.post.cross_profile;

    return SettingsPageScaffold(
      title: Text(context.t.settings.privacy.privacy),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(appLock.title),
          subtitle: Text(appLockSummary(context, settings)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => SettingsPageNavigationScope.of(
            context,
          ).openDestination('app_lock'),
        ),
        KurumiSwitchListTile(
          title: Text(appLock.hide_app_preview),
          subtitle: Text(appLock.hide_app_preview_description),
          value: settings.hideAppPreviewWhenBackgrounded,
          onChanged: (value) {
            notifier.updateWith(
              (settings) => settings.copyWith(
                hideAppPreviewWhenBackgrounded: value,
              ),
            );
          },
        ),
        if (ref.watch(localMediaAvailableProvider))
          KurumiSwitchListTile(
            title: Text(context.t.local_media.enrich_imports_online),
            subtitle: Text(context.t.local_media.enrich_imports_description),
            value: ref.watch(localMediaOnlineConsentProvider),
            onChanged: (enabled) async {
              try {
                await ref
                    .read(localMediaOnlineConsentProvider.notifier)
                    .setEnabled(enabled);
              } catch (_) {
                if (context.mounted) {
                  Kurumi.showErrorToast(
                    context,
                    context.t.local_media.operation_failed,
                  );
                }
              }
            },
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.matching_profiles),
          subtitle: Text(t.matching_profiles_description),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => selectLookupTargets(
            context,
            ProviderScope.containerOf(context, listen: false),
            available: configuredLookupMethods,
            settings: true,
          ),
        ),
        KurumiSwitchListTile(
          title: Text(t.iqdb_setting),
          subtitle: Text(t.iqdb_setting_description),
          value: lookup.allowIqdb,
          onChanged: (enabled) async {
            try {
              await ref
                  .read(lookupPreferencesProvider.notifier)
                  .setIqdb(enabled);
            } catch (_) {
              if (context.mounted) {
                Kurumi.showErrorToast(
                  context,
                  context.t.local_media.operation_failed,
                );
              }
            }
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.iqdb_threshold),
          subtitle: Text(t.iqdb_threshold_description),
          trailing: Text(
            t.similarity_score(score: lookup.threshold.toString()),
          ),
          onTap: () => _editThreshold(context, ref, lookup.threshold),
        ),
        tracker.maybeWhen(
          data: (_) => KurumiSwitchListTile(
            title: Text(context.t.settings.privacy.enable_incognito_keyboard),
            subtitle: Text(
              context.t.settings.privacy.enable_incognito_keyboard_notice,
            ),
            value: settings.enableIncognitoModeForKeyboard,
            onChanged: (value) {
              notifier.updateWith(
                (settings) => settings.copyWith(
                  enableIncognitoModeForKeyboard: value,
                ),
              );
            },
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

Future<void> _editThreshold(
  BuildContext context,
  WidgetRef ref,
  int threshold,
) async {
  var draft = threshold;
  final selected = await showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final t = context.t.post.cross_profile;
        final score = t.similarity_score(score: draft.toString());
        return AlertDialog(
          title: Text(t.iqdb_threshold),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.iqdb_threshold_description),
              Text(score),
              Slider(
                value: draft.toDouble(),
                label: score,
                min: minimumIqdbThreshold.toDouble(),
                max: maximumIqdbThreshold.toDouble(),
                divisions: maximumIqdbThreshold - minimumIqdbThreshold,
                onChanged: (value) => setState(() => draft = value.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.t.generic.action.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, draft),
              child: Text(context.t.generic.action.save),
            ),
          ],
        );
      },
    ),
  );
  if (selected == null || !context.mounted) return;
  try {
    await ref.read(lookupPreferencesProvider.notifier).setThreshold(selected);
  } catch (_) {
    if (context.mounted) {
      Kurumi.showErrorToast(context, context.t.local_media.operation_failed);
    }
  }
}
