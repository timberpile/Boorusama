import 'package:flutter/material.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

import '../../../groups/folder_navigation.dart';
import '../../../groups/folder_tree.dart';
import '../types/bookmark_group.dart';
import 'bookmark_collection_order.dart';

/// Shared navigation for dialog, anchored, context-menu, and bulk pickers.
class BookmarkFolderPickerContents extends StatefulWidget {
  const BookmarkFolderPickerContents({
    required this.folders,
    required this.groups,
    required this.groupBuilder,
    this.homeChildren = const [],
    this.footerBuilder,
    this.membershipGroupIds,
    this.onRootBack,
    this.compact = false,
    super.key,
  });

  final List<CollectionFolder> folders;
  final List<BookmarkGroup> groups;
  final Widget Function(BuildContext, BookmarkGroup) groupBuilder;
  final List<Widget> homeChildren;
  final Widget Function(BuildContext, String?)? footerBuilder;
  // Null means bulk mode: a single-bookmark badge would be ambiguous.
  final Set<String>? membershipGroupIds;
  final VoidCallback? onRootBack;
  final bool compact;

  @override
  State<BookmarkFolderPickerContents> createState() =>
      _BookmarkFolderPickerContentsState();
}

class _BookmarkFolderPickerContentsState
    extends State<BookmarkFolderPickerContents> {
  String? _requestedFolderId;
  final _scrollController = ScrollController();
  late FolderTree _tree;
  late List<BookmarkGroup> _groups;
  late Map<String, int> _membershipCounts;

  String? get _folderId =>
      widget.folders.any((folder) => folder.id == _requestedFolderId)
      ? _requestedFolderId
      : null;

  @override
  void initState() {
    super.initState();
    _updateSnapshot();
  }

  @override
  void didUpdateWidget(BookmarkFolderPickerContents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.folders, widget.folders) ||
        !identical(oldWidget.groups, widget.groups) ||
        !identical(oldWidget.membershipGroupIds, widget.membershipGroupIds)) {
      _updateSnapshot();
    }
  }

  void _updateSnapshot() {
    _tree = FolderTree(widget.folders);
    _groups = bookmarkGroupsByName(widget.groups);
    _membershipCounts = bookmarkFolderMembershipCounts(
      folders: widget.folders,
      groups: widget.groups,
      membershipGroupIds: widget.membershipGroupIds ?? const {},
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openFolder(String? id) {
    setState(() => _requestedFolderId = id);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final currentId = _folderId;
    final current = widget.folders.where((f) => f.id == currentId).firstOrNull;
    return Material(
      type: MaterialType.transparency,
      child: ListView(
        controller: _scrollController,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          FolderBreadcrumbs(
            tree: _tree,
            currentId: currentId,
            onOpen: _openFolder,
          ),
          if (current != null || widget.onRootBack != null) ...[
            if (widget.compact)
              BookmarkPickerMenuItem(
                icon: const Icon(Icons.arrow_back),
                title: context.t.generic.action.back,
                hideOnTap: false,
                onTap: current == null
                    ? widget.onRootBack!
                    : () => _openFolder(current.parentId),
              )
            else
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: Text(context.t.generic.action.back),
                onTap: current == null
                    ? widget.onRootBack
                    : () => _openFolder(current.parentId),
              ),
            if (widget.compact) const KurumiContextMenuDivider(),
          ],
          for (final folder in bookmarkFoldersByName(_tree.children(currentId)))
            MergeSemantics(
              child: widget.compact
                  ? BookmarkPickerMenuItem(
                      icon: BookmarkFolderMembershipIcon(
                        count: _membershipCounts[folder.id] ?? 0,
                      ),
                      title: folder.name,
                      trailing: const ExcludeSemantics(
                        child: Icon(Icons.chevron_right),
                      ),
                      hideOnTap: false,
                      onTap: () => _openFolder(folder.id),
                    )
                  : ListTile(
                      leading: BookmarkFolderMembershipIcon(
                        count: _membershipCounts[folder.id] ?? 0,
                      ),
                      title: Text(
                        folder.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const ExcludeSemantics(
                        child: Icon(Icons.chevron_right),
                      ),
                      onTap: () => _openFolder(folder.id),
                    ),
            ),
          if (currentId == null) ...widget.homeChildren,
          for (final group in _groups.where((g) => g.folderId == currentId))
            widget.groupBuilder(context, group),
          if (widget.footerBuilder case final footer?) ...[
            if (widget.compact) const KurumiContextMenuDivider(),
            footer(context, currentId),
          ],
        ],
      ),
    );
  }
}

/// Aggregate direct memberships from leaves to parents once per snapshot.
/// Rendering each folder then reads a cached count in constant time.
Map<String, int> bookmarkFolderMembershipCounts({
  required List<CollectionFolder> folders,
  required List<BookmarkGroup> groups,
  required Set<String> membershipGroupIds,
}) {
  final parents = {for (final folder in folders) folder.id: folder.parentId};
  final pendingChildren = {for (final folder in folders) folder.id: 0};
  final counts = <String, int>{};
  final countedGroups = <String>{};
  for (final group in groups) {
    final id = group.folderId;
    if (id != null &&
        parents.containsKey(id) &&
        membershipGroupIds.contains(group.id) &&
        countedGroups.add(group.id)) {
      counts.update(id, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  for (final parent in parents.values) {
    if (parent != null && pendingChildren.containsKey(parent)) {
      pendingChildren[parent] = pendingChildren[parent]! + 1;
    }
  }
  final ready = [
    for (final entry in pendingChildren.entries)
      if (entry.value == 0) entry.key,
  ];
  while (ready.isNotEmpty) {
    final id = ready.removeLast();
    final parent = parents[id];
    if (parent == null || !pendingChildren.containsKey(parent)) continue;
    final count = counts[id] ?? 0;
    if (count > 0) {
      counts.update(parent, (sum) => sum + count, ifAbsent: () => count);
    }
    pendingChildren[parent] = pendingChildren[parent]! - 1;
    if (pendingChildren[parent] == 0) ready.add(parent);
  }
  return counts;
}

class BookmarkFolderMembershipIcon extends StatelessWidget {
  const BookmarkFolderMembershipIcon({required this.count, super.key});
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: count > 0
        ? context.t.bookmark.groups.folder_memberships(n: count)
        : null,
    child: ExcludeSemantics(
      child: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.folder_outlined),
      ),
    ),
  );
}

/// Compact rows shared by bookmark context and anchored popups.
class BookmarkPickerMenuItem extends StatelessWidget {
  const BookmarkPickerMenuItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.trailing,
    this.hideOnTap = true,
    super.key,
  });

  final String title;
  final Widget icon;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool hideOnTap;

  @override
  Widget build(BuildContext context) => KurumiPopupMenuItem(
    icon: IconTheme.merge(
      data: const IconThemeData(size: 20),
      child: icon,
    ),
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
    ),
    trailing: trailing == null
        ? null
        : IconTheme.merge(
            data: const IconThemeData(size: 20),
            child: trailing!,
          ),
    hideOnTap: hideOnTap,
    onTap: onTap,
  );
}
