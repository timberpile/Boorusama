import 'package:flutter/material.dart';
import 'package:i18n/i18n.dart';

import '../preparation/preparation_pipeline.dart';

Future<void> confirmSearchBackupProfiles({
  required Set<String> unmatchedRecordIds,
  required int pinnedCount,
  required int feedCount,
  required BuildContext? context,
}) async {
  if (unmatchedRecordIds.isEmpty) return;
  if (context == null || !context.mounted) {
    throw const ImportCancelledException();
  }
  final strings = context.t.search_backup_import;
  final counts = [
    if (pinnedCount > 0) strings.pinned_count(n: pinnedCount),
    if (feedCount > 0) strings.feed_count(n: feedCount),
  ].join(strings.joiner);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.t.search_backup_import.title),
      content: Text(
        context.t.search_backup_import.message.replaceAll('{counts}', counts),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.t.generic.action.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.t.search_backup_import.skip_and_import),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) {
    throw const ImportCancelledException();
  }
}
