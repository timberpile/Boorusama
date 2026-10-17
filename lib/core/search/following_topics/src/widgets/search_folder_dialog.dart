import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../types/topic_organization.dart';

Future<String?> showSearchFolderNameDialog(
  BuildContext context, {
  String? name,
}) => showDialog<String>(
  context: context,
  builder: (_) => _SearchFolderNameDialog(name: name),
);

class _SearchFolderNameDialog extends StatefulWidget {
  const _SearchFolderNameDialog({this.name});
  final String? name;
  @override
  State<_SearchFolderNameDialog> createState() =>
      _SearchFolderNameDialogState();
}

class _SearchFolderNameDialogState extends State<_SearchFolderNameDialog> {
  late final _controller = TextEditingController(text: widget.name);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.name == null
          ? context.t.following_topics.create_folder
          : context.t.following_topics.rename,
    ),
    content: TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: context.t.following_topics.folder_name,
      ),
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.t.generic.action.cancel),
      ),
      FilledButton(
        onPressed: _controller.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _controller.text.trim()),
        child: Text(context.t.following_topics.save),
      ),
    ],
  );
}

final class SearchFolderSettings {
  const SearchFolderSettings({
    required this.name,
    required this.parentId,
    required this.feedEnabled,
    required this.maxPosts,
  });

  final String name;
  final String? parentId;
  final bool feedEnabled;
  final int maxPosts;
}

Future<SearchFolderSettings?> showSearchFolderSettingsDialog(
  BuildContext context, {
  String? name,
  List<TopicFolder> folders = const [],
  String? parentId,
  String? editingFolderId,
  bool feedEnabled = false,
  int maxPosts = 1000,
}) => showDialog<SearchFolderSettings>(
  context: context,
  builder: (_) => _SearchFolderSettingsDialog(
    name: name,
    folders: folders,
    parentId: parentId,
    editingFolderId: editingFolderId,
    feedEnabled: feedEnabled,
    maxPosts: maxPosts,
  ),
);

class _SearchFolderSettingsDialog extends StatefulWidget {
  const _SearchFolderSettingsDialog({
    this.name,
    required this.folders,
    this.parentId,
    this.editingFolderId,
    required this.feedEnabled,
    required this.maxPosts,
  });

  final String? name;
  final List<TopicFolder> folders;
  final String? parentId;
  final String? editingFolderId;
  final bool feedEnabled;
  final int maxPosts;

  @override
  State<_SearchFolderSettingsDialog> createState() =>
      _SearchFolderSettingsDialogState();
}

class _SearchFolderSettingsDialogState
    extends State<_SearchFolderSettingsDialog> {
  late final _name = TextEditingController(
    text: widget.name,
  );
  late bool _feedEnabled = widget.feedEnabled;
  late int _maxPosts = widget.maxPosts;
  late final String? _parentId = widget.parentId;

  bool get _duplicateName {
    final value = _name.text.trim().toLowerCase();
    return value.isNotEmpty &&
        widget.folders.any(
          (folder) =>
              folder.id != widget.editingFolderId &&
              folder.parentId == _parentId &&
              folder.name.toLowerCase() == value,
        );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.following_topics;
    final limits = {
      ...[250, 500, 1000, 2000, 5000],
      _maxPosts,
    }.toList()..sort();
    return AlertDialog(
      title: Text(
        widget.name == null ? strings.create_folder : strings.edit_folder,
      ),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: strings.folder_name),
            onChanged: (_) => setState(() {}),
          ),
          if (_duplicateName) ...[
            const SizedBox(height: 8),
            Text(
              strings.folder_name_duplicate,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          CheckboxListTile(
            title: Text(strings.enable_feed),
            value: _feedEnabled,
            contentPadding: EdgeInsets.zero,
            onChanged: (enabled) =>
                setState(() => _feedEnabled = enabled ?? false),
          ),
          if (_feedEnabled) ...[
            DropdownButtonFormField<int>(
              initialValue: _maxPosts,
              decoration: InputDecoration(
                labelText: strings.feed_max_posts,
              ),
              items: [
                for (final limit in limits)
                  DropdownMenuItem(value: limit, child: Text('$limit')),
              ],
              onChanged: (limit) =>
                  setState(() => _maxPosts = limit ?? _maxPosts),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t.generic.action.cancel),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty || _duplicateName
              ? null
              : () => Navigator.pop(
                  context,
                  SearchFolderSettings(
                    name: _name.text.trim(),
                    parentId: _parentId,
                    feedEnabled: _feedEnabled,
                    maxPosts: _maxPosts,
                  ),
                ),
          child: Text(strings.save),
        ),
      ],
    );
  }
}
