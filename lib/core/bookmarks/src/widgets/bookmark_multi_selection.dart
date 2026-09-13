// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';

// Project imports:
import '../providers/bookmark_provider.dart';
import '../types/bookmark.dart';
import 'bookmark_group_name_dialog.dart';

Future<bool> showBookmarkMultiSelectionActions(
  BuildContext context, {
  required WidgetRef ref,
  required List<Bookmark> bookmarks,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(context.t.bookmark.bulk.add),
            onTap: () => Navigator.pop(context, 'add'),
          ),
          ListTile(
            title: Text(context.t.bookmark.bulk.remove),
            onTap: () => Navigator.pop(context, 'remove'),
          ),
          ListTile(
            title: Text(context.t.bookmark.bulk.delete),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return false;
  return switch (action) {
    'add' => _add(context, ref, bookmarks),
    'remove' => _remove(context, ref, bookmarks),
    'delete' => _delete(context, ref, bookmarks),
    _ => false,
  };
}

Future<bool> _add(
  BuildContext context,
  WidgetRef ref,
  List<Bookmark> bookmarks,
) async {
  final groupId = await _selectGroup(context, ref, allowCreate: true);
  if (groupId == null) return false;
  await ref
      .read(bookmarkProvider.notifier)
      .addExistingBookmarksToGroup(bookmarks, groupId);
  return false;
}

Future<bool> _remove(
  BuildContext context,
  WidgetRef ref,
  List<Bookmark> bookmarks,
) async {
  final groupId = await _selectGroup(context, ref);
  if (groupId == null) return false;
  await ref.read(bookmarkProvider.notifier).removeFromGroup(bookmarks, groupId);
  return false;
}

Future<bool> _delete(
  BuildContext context,
  WidgetRef ref,
  List<Bookmark> bookmarks,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.t.bookmark.bulk.delete_title),
      content: Text(
        context.t.bookmark.bulk.delete_message.replaceAll(
          '{count}',
          '${bookmarks.length}',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.t.generic.action.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.t.generic.action.delete),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  await ref.read(bookmarkProvider.notifier).removeBookmarks(bookmarks);
  return true;
}

Future<String?> _selectGroup(
  BuildContext context,
  WidgetRef ref, {
  bool allowCreate = false,
}) {
  final groups = ref.read(bookmarkProvider).valueOrNull?.groups ?? const [];
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(context.t.bookmark.groups.selector),
      children: [
        for (final group in groups)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, group.id),
            child: Text(group.name),
          ),
        if (allowCreate)
          SimpleDialogOption(
            onPressed: () async {
              final name = await showBookmarkGroupNameDialog(
                dialogContext,
                title: context.t.bookmark.groups.create,
              );
              if (name == null || !dialogContext.mounted) return;
              final group = await ref
                  .read(bookmarkProvider.notifier)
                  .createGroup(name, activate: true);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, group.id);
              }
            },
            child: Text(context.t.bookmark.groups.create_new),
          ),
      ],
    ),
  );
}
