import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../foundation/info/package_info.dart';
import '../posts/links/open_link_file.dart';
import '../settings/src/pages/bookmark_maintenance_page.dart';
import '../settings/src/pages/performance_diagnostics_page.dart';
import '../settings/src/widgets/settings_page_scaffold.dart';
import 'l10n.dart';
import 'providers.dart';

class DeveloperOptionsPage extends ConsumerWidget {
  const DeveloperOptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isDevEnvironmentProvider)) return const SizedBox.shrink();

    final automaticMediaLoadingEnabled = ref.watch(
      automaticMediaLoadingEnabledProvider,
    );
    final l10n = context.t.developerOptions;

    return SettingsPageScaffold(
      title: Text(l10n.title),
      children: [
        ListTile(
          title: Text(context.t.performance_diagnostics.title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PerformanceDiagnosticsPage(),
            ),
          ),
        ),
        ListTile(
          title: Text(context.t.bookmark.maintenance.hydrate),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const BookmarkMaintenancePage(),
            ),
          ),
        ),
        const OpenLinkFileTile(),
        KurumiSwitchListTile(
          title: Text(l10n.blockAutomaticMedia),
          subtitle: Text(l10n.blockAutomaticMediaDescription),
          value: !automaticMediaLoadingEnabled,
          onChanged: (blocked) => ref
              .read(developerOptionsNotifierProvider.notifier)
              .setAutomaticMediaLoadingEnabled(!blocked),
        ),
      ],
    );
  }
}
