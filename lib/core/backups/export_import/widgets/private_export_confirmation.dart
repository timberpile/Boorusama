import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

Future<bool> confirmPrivateExport(
  BuildContext context, {
  String? confirmLabel,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context
              .t
              .settings
              .backup_and_restore
              .export_import
              .private_confirmation_title,
        ),
        content: Text(
          context
              .t
              .settings
              .backup_and_restore
              .export_import
              .private_confirmation_body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              context.t.settings.backup_and_restore.export_import.cancel,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel ??
                  context.t.settings.backup_and_restore.export_import.kContinue,
            ),
          ),
        ],
      ),
    ) ??
    false;
