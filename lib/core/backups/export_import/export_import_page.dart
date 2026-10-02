import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../foundation/info/device_info.dart';
import '../auto/widgets.dart';
import '../transfer/route_utils.dart';
import '../transfer/sync_data_page.dart';
import '../utils/backup_file_picker.dart';
import 'export/export_flow_page.dart';
import 'import/import_flow_page.dart';
import 'widgets/private_export_confirmation.dart';

class ExportImportPage extends ConsumerWidget {
  const ExportImportPage({super.key, this.includeAutomaticExports = false});

  final bool includeAutomaticExports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.t.settings.backup_and_restore.export_import;
    final clipboard = ref.watch(exportClipboardServiceProvider);
    return Scaffold(
      appBar: AppBar(title: Text(strings.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(strings.description),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: Text(strings.create_export),
              subtitle: Text(strings.full_export_description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExportFlowPage()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: Text(strings.import_file),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => BackupFilePicker.pickFile(
                context: context,
                androidDeviceInfo: ref
                    .read(deviceInfoProvider)
                    .androidDeviceInfo,
                allowedExtensions: const ['bsexport', 'zip', 'json'],
                onPick: (path) => _openImport(context, path),
              ),
            ),
          ),
          FutureBuilder<bool>(
            future: clipboard.detect(),
            builder: (context, snapshot) {
              final detected = snapshot.data ?? false;
              return Card(
                child: ListTile(
                  leading: Icon(
                    detected ? Icons.content_paste_go : Icons.content_paste,
                  ),
                  title: Text(strings.import_clipboard),
                  subtitle: detected ? Text(strings.clipboard_detected) : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    try {
                      final package = await clipboard.importToTemporaryFile();
                      if (context.mounted) {
                        _openImport(
                          context,
                          package.path,
                          disposeInput: package.dispose,
                        );
                      } else {
                        await package.dispose();
                      }
                    } catch (error) {
                      if (context.mounted) {
                        Kurumi.showErrorToast(
                          context,
                          strings.invalid_export_friendly,
                        );
                      }
                    }
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.wifi_tethering_outlined),
              title: Text(context.t.settings.backup_and_restore.send),
              subtitle: Text(strings.nearby_send_description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final confirmed = await confirmPrivateExport(
                  context,
                  confirmLabel: strings.start_sending,
                );
                if (confirmed && context.mounted) {
                  goToSyncDataPage(context, mode: TransferMode.export);
                }
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.wifi_find_outlined),
              title: Text(context.t.settings.backup_and_restore.receive),
              subtitle: Text(strings.nearby_receive_description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => goToSyncDataPage(
                context,
                mode: TransferMode.import,
              ),
            ),
          ),
          if (includeAutomaticExports) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  context.t.settings.backup_and_restore.auto_backup,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message:
                      context.t.settings.backup_and_restore.auto_backup_tooltip,
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 5),
                  child: const Icon(Icons.info_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const AutoBackupSection(),
          ],
        ],
      ),
    );
  }

  void _openImport(
    BuildContext context,
    String path, {
    Future<void> Function()? disposeInput,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImportFlowPage(
          packagePath: path,
          disposeInput: disposeInput,
        ),
      ),
    );
  }
}
