import 'package:flutter/material.dart';
import 'package:i18n/i18n.dart';
import 'folder_tree.dart';

class FolderBreadcrumbs extends StatelessWidget {
  const FolderBreadcrumbs({
    required this.tree,
    required this.currentId,
    required this.onOpen,
    super.key,
  });
  final FolderTree tree;
  final String? currentId;
  final ValueChanged<String?> onOpen;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        TextButton(
          onPressed: () => onOpen(null),
          child: Text(context.t.folders.home),
        ),
        for (final f in tree.ancestors(currentId)) ...[
          const Icon(Icons.chevron_right, size: 18),
          TextButton(
            onPressed: () => onOpen(f.id),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ],
    ),
  );
}

/// A hierarchical picker returns a record so cancellation differs from Home.
Future<({String? folderId})?> showFolderDestinationPicker(
  BuildContext context, {
  required List<CollectionFolder> folders,
  String? initialFolderId,
  bool sortByName = false,
  String? confirmationLabel,
  String? title,
  bool Function(String?)? canCreateAt,
  bool Function(String?)? canMoveTo,
  Set<String> movingFolderIds = const {},
  Future<String?> Function(BuildContext, String?)? onCreate,
}) => showDialog<({String? folderId})>(
  context: context,
  builder: (_) => _FolderDestinationPicker(
    folders: folders,
    initialFolderId: initialFolderId,
    sortByName: sortByName,
    confirmationLabel: confirmationLabel,
    title: title,
    canCreateAt: canCreateAt,
    canMoveTo: canMoveTo,
    movingFolderIds: movingFolderIds,
    onCreate: onCreate,
  ),
);

class _FolderDestinationPicker extends StatefulWidget {
  const _FolderDestinationPicker({
    required this.folders,
    required this.movingFolderIds,
    this.initialFolderId,
    this.sortByName = false,
    this.confirmationLabel,
    this.title,
    this.canCreateAt,
    this.canMoveTo,
    this.onCreate,
  });
  final List<CollectionFolder> folders;
  final String? initialFolderId;
  final bool sortByName;
  final String? confirmationLabel;
  final String? title;
  final bool Function(String?)? canCreateAt;
  final bool Function(String?)? canMoveTo;
  final Set<String> movingFolderIds;
  final Future<String?> Function(BuildContext, String?)? onCreate;
  @override
  State<_FolderDestinationPicker> createState() =>
      _FolderDestinationPickerState();
}

class _FolderDestinationPickerState extends State<_FolderDestinationPicker> {
  String? currentId;
  @override
  void initState() {
    super.initState();
    final id = widget.initialFolderId;
    final tree = FolderTree(widget.folders);
    final excluded = {
      for (final movingId in widget.movingFolderIds) ...tree.subtree(movingId),
    };
    if (widget.folders.any((folder) => folder.id == id) &&
        !excluded.contains(id)) {
      currentId = id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tree = FolderTree(widget.folders);
    final excluded = {
      for (final id in widget.movingFolderIds) ...tree.subtree(id),
    };
    final children = tree.children(currentId);
    if (widget.sortByName) {
      children.sort((a, b) {
        final order = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    }
    return AlertDialog(
      title: Text(widget.title ?? context.t.folders.move),
      content: SizedBox(
        width: 360,
        height: 320,
        child: Column(
          children: [
            FolderBreadcrumbs(
              tree: tree,
              currentId: currentId,
              onOpen: (id) => setState(() => currentId = id),
            ),
            if (currentId != null)
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: Text(context.t.generic.action.back),
                onTap: () =>
                    setState(() => currentId = tree.byId[currentId]?.parentId),
              ),
            Expanded(
              child: ListView(
                children: [
                  for (final f in children)
                    if (!excluded.contains(f.id))
                      ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(f.name),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => setState(() => currentId = f.id),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.onCreate != null &&
            (widget.canCreateAt?.call(currentId) ?? true))
          TextButton(
            onPressed: () async {
              final id = await widget.onCreate!(context, currentId);
              if (id != null && context.mounted) {
                Navigator.pop(context, (folderId: id));
              }
            },
            child: Text(context.t.folders.create),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t.generic.action.cancel),
        ),
        FilledButton(
          onPressed:
              excluded.contains(currentId) ||
                  !(widget.canMoveTo?.call(currentId) ?? true)
              ? null
              : () => Navigator.pop(context, (folderId: currentId)),
          child: Text(widget.confirmationLabel ?? context.t.folders.move),
        ),
      ],
    );
  }
}
