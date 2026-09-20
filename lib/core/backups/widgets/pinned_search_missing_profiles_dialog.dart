import 'package:flutter/material.dart';
import 'package:i18n/i18n.dart';

Future<bool?> showPinnedSearchMissingProfilesDialog(
  BuildContext context,
  int count,
) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(context.t.pinned_searches.backup_missing_profiles_title),
    content: Text(
      context.t.pinned_searches.backup_missing_profiles_message.replaceAll(
        '{count}',
        '$count',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(context.t.generic.action.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(context.t.pinned_searches.backup_skip_and_import),
      ),
    ],
  ),
);
