// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../auto/widgets.dart';
import '../export_import/export_import_page.dart';
import 'data_transfer_card.dart';

class BackupSettingsSection extends ConsumerWidget {
  const BackupSettingsSection({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _Title(
          title: context.t.settings.backup_and_restore.export_import.title,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 12,
          ),
          child: DataTransferCard(
            icon: const FaIcon(FontAwesomeIcons.fileExport),
            title: context.t.settings.backup_and_restore.export_import.title,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExportImportPage()),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _Title(
          title: context.t.settings.backup_and_restore.auto_backup,
          extra: Tooltip(
            message: context.t.settings.backup_and_restore.auto_backup_tooltip,
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 5),
            child: const Icon(
              Icons.info,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const AutoBackupSection(),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({
    required this.title,
    this.extra,
  });

  final String title;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 8,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          if (extra != null) ...[
            const SizedBox(width: 8),
            extra!,
          ],
        ],
      ),
    );
  }
}
