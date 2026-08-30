// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../sources/bookmark_backup_data.dart';
import '../../bookmarks/src/types/bookmark_group.dart';

Future<BookmarkExportScope?> showBookmarkExportScopeDialog(
  BuildContext context, {
  required List<BookmarkGroup> groups,
}) {
  return showDialog<BookmarkExportScope>(
    context: context,
    builder: (context) => BookmarkExportScopeDialog(groups: groups),
  );
}

class BookmarkExportScopeDialog extends StatefulWidget {
  const BookmarkExportScopeDialog({
    required this.groups,
    super.key,
  });

  final List<BookmarkGroup> groups;

  @override
  State<BookmarkExportScopeDialog> createState() =>
      _BookmarkExportScopeDialogState();
}

class _BookmarkExportScopeDialogState extends State<BookmarkExportScopeDialog> {
  var _exportAll = true;
  final _selectedGroupIds = <int>{};
  var _includeUngrouped = false;

  bool get _canExport =>
      _exportAll || _selectedGroupIds.isNotEmpty || _includeUngrouped;

  @override
  Widget build(BuildContext context) {
    return KurumiDialogContent(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            context.t.settings.backup_and_restore.export_scope.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          RadioGroup<bool>(
            groupValue: _exportAll,
            onChanged: (value) {
              if (value != null) setState(() => _exportAll = value);
            },
            child: Column(
              children: [
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    context.t.settings.backup_and_restore.export_scope.all,
                  ),
                  value: true,
                ),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    context
                        .t
                        .settings
                        .backup_and_restore
                        .export_scope
                        .selected_groups,
                  ),
                  value: false,
                ),
              ],
            ),
          ),
          if (!_exportAll) _buildGroupList(context),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.t.generic.action.cancel),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _canExport ? _submit : null,
                  child: Text(
                    context.t.settings.backup_and_restore.export_scope.export,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildGroupList(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (final group in widget.groups)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(group.name),
                value: _selectedGroupIds.contains(group.id),
                onChanged: (selected) => setState(() {
                  if (selected ?? false) {
                    _selectedGroupIds.add(group.id);
                  } else {
                    _selectedGroupIds.remove(group.id);
                  }
                }),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.t.settings.backup_and_restore.export_scope.no_group,
              ),
              value: _includeUngrouped,
              onChanged: (selected) => setState(
                () => _includeUngrouped = selected ?? false,
              ),
            ),
            if (!_canExport)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context
                      .t
                      .settings
                      .backup_and_restore
                      .export_scope
                      .no_selection,
                  style: TextStyle(
                    color: Kurumi.themeOf(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    Navigator.of(context).pop(
      _exportAll
          ? const BookmarkExportScope.all()
          : BookmarkExportScope.selected(
              groupIds: _selectedGroupIds,
              includeUngrouped: _includeUngrouped,
            ),
    );
  }
}
