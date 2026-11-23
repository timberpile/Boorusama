import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../types/bookmark_group.dart';
import '../types/bookmark_group_tree.dart';
import 'bookmark_folder_picker_contents.dart';

/// A selected destination wraps [parentGroupId] so Home (`null`) is distinct
/// from dismissing the picker (`null` result).
typedef BookmarkGroupDestination = ({String? parentGroupId});

Future<BookmarkGroupDestination?> showBookmarkGroupDestinationPicker(
  BuildContext context, {
  required List<BookmarkGroup> groups,
  required Set<String> movingGroupIds,
  String? initialParentGroupId,
}) => showDialog<BookmarkGroupDestination>(
  context: context,
  builder: (_) => _BookmarkGroupDestinationPicker(
    groups: groups,
    movingGroupIds: movingGroupIds,
    initialParentGroupId: initialParentGroupId,
  ),
);

class _BookmarkGroupDestinationPicker extends StatefulWidget {
  const _BookmarkGroupDestinationPicker({
    required this.groups,
    required this.movingGroupIds,
    this.initialParentGroupId,
  });

  final List<BookmarkGroup> groups;
  final Set<String> movingGroupIds;
  final String? initialParentGroupId;

  @override
  State<_BookmarkGroupDestinationPicker> createState() =>
      _BookmarkGroupDestinationPickerState();
}

class _BookmarkGroupDestinationPickerState
    extends State<_BookmarkGroupDestinationPicker> {
  late final BookmarkGroupTree _tree = BookmarkGroupTree(widget.groups);
  late final List<BookmarkGroup> _roots = _tree.selectionRoots(
    widget.movingGroupIds,
  );
  late final Set<String> _excluded = {
    for (final root in _roots) ..._tree.subtreeIds(root.id),
  };
  String? _currentParent;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialParentGroupId;
    if (_tree.groupsById.containsKey(initial) && !_excluded.contains(initial)) {
      _currentParent = initial;
    }
  }

  bool get _changesParent => _roots.any(
    (group) => group.parentGroupId != _currentParent,
  );

  @override
  Widget build(BuildContext context) {
    final children = _tree.childrenOf(_currentParent);
    final ancestors = _currentParent == null
        ? const <BookmarkGroup>[]
        : _tree
              .ancestors(_currentParent!)
              .followedBy([_tree.groupsById[_currentParent]!])
              .toList(growable: false);

    return KurumiDialog(
      width: 420,
      screenInset: 12,
      height: 560,
      semanticLabel: context.t.bookmark.groups.move_here,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (_currentParent != null)
                IconButton(
                  tooltip: context.t.generic.action.back,
                  onPressed: () => setState(() {
                    _currentParent =
                        _tree.groupsById[_currentParent]?.parentGroupId;
                  }),
                  icon: const Icon(Icons.arrow_back),
                )
              else
                const SizedBox(width: 48),
              Expanded(
                child: Text(
                  context.t.bookmark.groups.move_here,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: context.t.generic.action.cancel,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _currentParent = null),
                  child: Text(context.t.sideMenu.home),
                ),
                for (final ancestor in ancestors) ...[
                  const Icon(Icons.chevron_right, size: 18),
                  TextButton(
                    key: ValueKey('destination-path-${ancestor.id}'),
                    onPressed: () =>
                        setState(() => _currentParent = ancestor.id),
                    child: Text(ancestor.name),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final group in children)
                  if (!_excluded.contains(group.id))
                    BookmarkPickerMenuItem(
                      key: ValueKey('destination-${group.id}'),
                      icon: const Icon(Icons.folder_outlined),
                      title: group.name,
                      trailing: const Icon(Icons.chevron_right),
                      hideOnTap: false,
                      onTap: () => setState(() => _currentParent = group.id),
                    ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.t.generic.action.cancel),
                ),
                FilledButton(
                  onPressed: _changesParent
                      ? () => Navigator.pop(
                          context,
                          (parentGroupId: _currentParent),
                        )
                      : null,
                  child: Text(context.t.bookmark.groups.move_here),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
