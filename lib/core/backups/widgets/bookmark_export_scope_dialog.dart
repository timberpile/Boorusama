// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:i18n/i18n.dart';

// Project imports:
import '../../bookmarks/types.dart';
import '../../groups/folder_tree.dart';
import '../../bookmarks/src/widgets/bookmark_group_label.dart';
import '../sources/bookmark_backup_data.dart';

Future<BookmarkExportScope?> showBookmarkExportScopeDialog(
  BuildContext context, {
  required List<BookmarkGroup> groups,
  List<CollectionFolder> folders = const [],
}) => showDialog<BookmarkExportScope>(
  context: context,
  builder: (_) => BookmarkExportScopeDialog(groups: groups, folders: folders),
);

class BookmarkExportScopeDialog extends StatefulWidget {
  const BookmarkExportScopeDialog({
    required this.groups,
    this.folders = const [],
    super.key,
  });

  final List<BookmarkGroup> groups;
  final List<CollectionFolder> folders;

  @override
  State<BookmarkExportScopeDialog> createState() =>
      _BookmarkExportScopeDialogState();
}

class _BookmarkExportScopeDialogState extends State<BookmarkExportScopeDialog> {
  var _all = true;
  var _ungrouped = false;
  final _groupIds = <String>{};
  final _folderIds = <String>{};

  bool get _valid =>
      _all || _ungrouped || (_groupIds.isNotEmpty || _folderIds.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final labels = bookmarkGroupLabels(widget.groups, folders: widget.folders);
    return AlertDialog(
      title: Text(context.t.settings.backup_and_restore.export_scope.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<bool>(
              groupValue: _all,
              onChanged: (value) {
                if (value != null) setState(() => _all = value);
              },
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: true,
                    title: Text(
                      context.t.settings.backup_and_restore.export_scope.all,
                    ),
                  ),
                  RadioListTile<bool>(
                    value: false,
                    title: Text(
                      context
                          .t
                          .settings
                          .backup_and_restore
                          .export_scope
                          .selected_groups,
                    ),
                  ),
                ],
              ),
            ),
            if (!_all) ...[
              for (final f in widget.folders)
                CheckboxListTile(
                  value: _folderIds.contains(f.id),
                  title: Text(FolderTree(widget.folders).path(f.id)),
                  secondary: const Icon(Icons.folder_outlined),
                  onChanged: (selected) => setState(() {
                    if (selected ?? false)
                      _folderIds.add(f.id);
                    else
                      _folderIds.remove(f.id);
                  }),
                ),
              for (final group in widget.groups)
                CheckboxListTile(
                  value: _groupIds.contains(group.id),
                  title: Text(labels[group.id]!),
                  onChanged: (selected) => setState(() {
                    if (selected ?? false) {
                      _groupIds.add(group.id);
                    } else {
                      _groupIds.remove(group.id);
                    }
                  }),
                ),
              CheckboxListTile(
                value: _ungrouped,
                title: Text(
                  context.t.settings.backup_and_restore.export_scope.no_group,
                ),
                onChanged: (selected) =>
                    setState(() => _ungrouped = selected ?? false),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t.generic.action.cancel),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.pop(
                  context,
                  _all
                      ? const BookmarkExportScope.all()
                      : BookmarkExportScope.selected(
                          groupIds: _groupIds,
                          folderIds: _folderIds,
                          includeUngrouped: _ungrouped,
                        ),
                )
              : null,
          child: Text(context.t.settings.backup_and_restore.export),
        ),
      ],
    );
  }
}
