import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../foundation/info/device_info.dart';
import '../transfer/route_utils.dart';
import '../transfer/sync_data_page.dart';
import '../utils/backup_file_picker.dart';
import 'export/export_flow_page.dart';
import 'import/import_flow_page.dart';

class ExportImportPage extends ConsumerWidget {
  const ExportImportPage({super.key});

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
                  title: Text(
                    detected ? strings.import_clipboard : strings.paste_base64,
                  ),
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
                          strings.invalid_export.replaceAll(
                            '{error}',
                            error.toString(),
                          ),
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
              onTap: () => goToSyncDataPage(
                context,
                mode: TransferMode.export,
              ),
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
