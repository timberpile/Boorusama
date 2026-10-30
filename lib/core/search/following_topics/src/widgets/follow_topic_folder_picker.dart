import '../../../../selection/checkbox_range_selection.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../groups/folder_navigation.dart';
import '../providers/following_topics_notifier.dart';
import '../types/topic_organization.dart';
import 'search_folder_dialog.dart';
import 'topic_modification_badge.dart';

sealed class FollowTopicPickerResult {
  const FollowTopicPickerResult();
}

class FollowTopicDestinations extends FollowTopicPickerResult {
  FollowTopicDestinations(Set<String?> folders)
    : folders = Set.unmodifiable(folders);
  final Set<String?> folders;
}

class UpdatedOriginalTopic extends FollowTopicPickerResult {
  const UpdatedOriginalTopic();
}

Future<FollowTopicPickerResult?> showFollowTopicFolderPickerDialog(
  BuildContext context, {
  required String query,
  required Set<String?> selectedFolderIds,
  required Future<TopicFolder?> Function(String? parentId) onCreateFolder,
  Future<bool> Function()? onUpdateOriginal,
}) => showDialog<FollowTopicPickerResult>(
  context: context,
  builder: (_) => _FollowTopicFolderPickerDialog(
    query: query,
    selectedFolderIds: selectedFolderIds,
    onCreateFolder: onCreateFolder,
    onUpdateOriginal: onUpdateOriginal,
  ),
);

class _FollowTopicFolderPickerDialog extends ConsumerStatefulWidget {
  const _FollowTopicFolderPickerDialog({
    required this.query,
    required this.selectedFolderIds,
    required this.onCreateFolder,
    this.onUpdateOriginal,
  });

  final Future<bool> Function()? onUpdateOriginal;
  final String query;
  final Set<String?> selectedFolderIds;
  final Future<TopicFolder?> Function(String? parentId) onCreateFolder;

  @override
  ConsumerState<_FollowTopicFolderPickerDialog> createState() =>
      _FollowTopicFolderPickerDialogState();
}

class _FollowTopicFolderPickerDialogState
    extends ConsumerState<_FollowTopicFolderPickerDialog> {
  late final _selected = {...widget.selectedFolderIds};
  String? _currentFolderId;
  var _creatingFolder = false;
  var _updatingOriginal = false;

  Future<void> _updateOriginal() async {
    if (_updatingOriginal || _creatingFolder) return;
    setState(() => _updatingOriginal = true);
    try {
      final updated = await widget.onUpdateOriginal!();
      if (updated && mounted) {
        Navigator.pop(context, const UpdatedOriginalTopic());
      }
    } finally {
      if (mounted) setState(() => _updatingOriginal = false);
    }
  }

  void _toggle(String? folderId, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(folderId);
      } else {
        _selected.remove(folderId);
      }
    });
  }

  Future<void> _createFolder() async {
    setState(() => _creatingFolder = true);
    try {
      final folder = await widget.onCreateFolder(_currentFolderId);
      if (folder != null && mounted) {
        setState(() => _selected.add(folder.id));
      }
    } finally {
      if (mounted) setState(() => _creatingFolder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final organization = ref
        .watch(followingTopicsProvider)
        .valueOrNull
        ?.organization;
    final tree = organization?.tree;
    final children = tree?.children(_currentFolderId) ?? <TopicFolder>[];
    final strings = context.t.following_topics;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(strings.follow)),
          if (_selected.isNotEmpty) Badge(label: Text('${_selected.length}')),
        ],
      ),
      content: SizedBox(
        width: 420,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.query,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_currentFolderId != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  IconButton(
                    tooltip: context.t.generic.action.back,
                    onPressed: () => setState(
                      () => _currentFolderId =
                          tree?.byId[_currentFolderId]?.parentId,
                    ),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      tree?.path(_currentFolderId) ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Expanded(
              child: CheckboxRangeSelection<(String?,)>(
                entries: [
                  if (_currentFolderId == null) (null,),
                  for (final folder in children) (folder.id,),
                ],
                selected: {for (final id in _selected) (id,)},
                onChanged: (selected) => setState(() {
                  _selected
                    ..clear()
                    ..addAll(selected.map((key) => key.$1));
                }),
                child: ListView(
                  children: [
                    if (_currentFolderId == null)
                      CheckboxRangeItem(
                        key: const ValueKey<(String?,)>((null,)),
                        value: (null,),
                        child: _FollowDestinationRow(
                          name: context.t.folders.home,
                          selected: _selected.contains(null),
                          onChanged: (value) => _toggle(null, value),
                        ),
                      ),
                    for (final folder in children)
                      CheckboxRangeItem(
                        key: ValueKey<(String?,)>((folder.id,)),
                        value: (folder.id,),
                        child: _FollowDestinationRow(
                          name: folder.name,
                          selected: _selected.contains(folder.id),
                          onChanged: (value) => _toggle(folder.id, value),
                          onOpen: tree!.children(folder.id).isEmpty
                              ? null
                              : () => setState(
                                  () => _currentFolderId = folder.id,
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: widget.onUpdateOriginal != null
          ? [
              Row(
                children: [
                  TopicModificationBadge(
                    modified: true,
                    child: IconButton(
                      tooltip: strings.original_update,
                      onPressed: _creatingFolder || _updatingOriginal
                          ? null
                          : _updateOriginal,
                      icon: const Icon(Icons.save_outlined),
                    ),
                  ),
                  IconButton(
                    tooltip: strings.new_folder,
                    onPressed: _creatingFolder || _updatingOriginal
                        ? null
                        : _createFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(64, 48),
                      ),
                      onPressed: _creatingFolder || _updatingOriginal
                          ? null
                          : () => Navigator.pop(
                              context,
                              FollowTopicDestinations(_selected),
                            ),
                      child: Text(context.t.generic.done, maxLines: 1),
                    ),
                  ),
                ],
              ),
            ]
          : [
              FilledButton.tonalIcon(
                onPressed: _creatingFolder ? null : _createFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(strings.new_folder),
              ),
              FilledButton(
                onPressed: _creatingFolder
                    ? null
                    : () => Navigator.pop(
                        context,
                        FollowTopicDestinations(_selected),
                      ),
                child: Text(context.t.generic.done),
              ),
            ],
    );
  }
}

class _FollowDestinationRow extends StatelessWidget {
  const _FollowDestinationRow({
    required this.name,
    required this.selected,
    required this.onChanged,
    this.onOpen,
  });

  final String name;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    visualDensity: const VisualDensity(vertical: -2),
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: Checkbox(
      value: selected,
      onChanged: (value) => onChanged(value ?? false),
    ),
    title: Text(name),
    onTap: () => onChanged(!selected),
    trailing: onOpen == null
        ? null
        : IconButton(
            tooltip: context.t.generic.action.view,
            onPressed: onOpen,
            icon: const Icon(Icons.chevron_right),
          ),
  );
}

class FollowTopicFolderPicker extends ConsumerStatefulWidget {
  const FollowTopicFolderPicker({
    required this.onSelected,
    this.initialFolderId,
    super.key,
  });
  final String? initialFolderId;
  final void Function(String? folderId, SearchFolderSettings? newFolder)
  onSelected;
  @override
  ConsumerState<FollowTopicFolderPicker> createState() =>
      _FollowTopicFolderPickerState();
}

class _FollowTopicFolderPickerState
    extends ConsumerState<FollowTopicFolderPicker> {
  static const _newFolderValue = '__new_topic_folder__';
  late String? _selected = widget.initialFolderId;
  SearchFolderSettings? _newFolder;

  Future<void> _choose() async {
    FocusScope.of(context).unfocus();
    final folders =
        ref.read(followingTopicsProvider).valueOrNull?.organization.folders ??
        [];
    final choice = await showFolderDestinationPicker(
      context,
      folders: folders,
      initialFolderId: _selected,
      title: context.t.following_topics.folder,
      confirmationLabel: context.t.generic.action.select,
      onCreate: (_, parentId) async {
        _newFolder = SearchFolderSettings(
          name: '',
          parentId: parentId,
          feedEnabled: false,
          maxPosts: 1000,
        );
        return _newFolderValue;
      },
    );
    if (choice == null || !mounted) return;
    setState(() {
      final created = choice.folderId == _newFolderValue;
      if (!created) _newFolder = null;
      _selected = created ? null : choice.folderId;
    });
    widget.onSelected(_selected, _newFolder);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(followingTopicsProvider).valueOrNull;
    final folders = state?.organization.folders ?? [];
    final selected = folders
        .where((folder) => folder.id == _selected)
        .firstOrNull;
    final tree = state?.organization.tree;
    final label = switch (_newFolder) {
      final folder? when folder.name.isEmpty =>
        context.t.following_topics.new_folder,
      final folder? =>
        tree == null || folder.parentId == null
            ? folder.name
            : '${tree.path(folder.parentId)} / ${folder.name}',
      null =>
        selected == null
            ? context.t.following_topics.no_folder
            : tree?.path(selected.id) ?? selected.name,
    };
    return Semantics(
      button: true,
      child: InkWell(
        onTap: _choose,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: context.t.following_topics.folder,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}
