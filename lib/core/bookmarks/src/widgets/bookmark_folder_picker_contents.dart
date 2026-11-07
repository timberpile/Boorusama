import 'package:kurumi/material.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

import '../../../groups/folder_tree.dart';
import '../services/bookmark_hierarchy_conversion.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_group_tree.dart';
import 'bookmark_group_label.dart';

/// Presenter-owned navigation lets an anchored overlay consume its own Back.
class BookmarkPickerNavigation extends ChangeNotifier {
  String? _currentId;
  List<String> _path = const [];
  BookmarkGroupTree _tree = BookmarkGroupTree(const []);
  String? get currentId => _currentId;
  void update(BookmarkGroupTree tree) {
    _tree = tree;
    if (_currentId != null && !tree.groupsById.containsKey(_currentId)) {
      _currentId = _path.reversed
          .where(tree.groupsById.containsKey)
          .firstOrNull;
    }
    _path = _currentId == null
        ? const []
        : [
            for (final ancestor in tree.ancestors(_currentId!)) ancestor.id,
          ];
  }

  void open(String? id) {
    if (id == _currentId || (id != null && !_tree.groupsById.containsKey(id)))
      return;
    _currentId = id;
    _path = id == null
        ? const []
        : [for (final group in _tree.ancestors(id)) group.id];
    notifyListeners();
  }

  bool back() {
    if (_currentId == null) return false;
    open(_tree.groupsById[_currentId]?.parentGroupId);
    return true;
  }
}

/// Shared direct-membership targets and hierarchy for every presenter.
class BookmarkFolderPickerContents extends StatefulWidget {
  const BookmarkFolderPickerContents({
    required this.folders,
    required this.groups,
    required this.groupBuilder,
    this.homeChildren = const [],
    this.footerBuilder,
    this.onCreateGroup,
    this.createGroupEnabled = true,
    this.pinnedFooter,
    this.membershipGroupIds,
    this.onRootBack,
    this.navigation,
    this.ownsBack = true,
    this.selectableGroupIds,
    this.currentGroupBuilder,
    super.key,
  });
  final List<CollectionFolder> folders;
  final List<BookmarkGroup> groups;
  final Widget Function(BuildContext, BookmarkGroup) groupBuilder;
  final List<Widget> homeChildren;
  final Widget Function(BuildContext, String?)? footerBuilder;
  final ValueChanged<String?>? onCreateGroup;
  final bool createGroupEnabled;
  final Widget? pinnedFooter;
  final Set<String>? membershipGroupIds;
  final VoidCallback? onRootBack;
  final BookmarkPickerNavigation? navigation;
  final bool ownsBack;
  // Ancestor rows remain navigable even when not applicable direct targets.
  final Set<String>? selectableGroupIds;
  final Widget Function(BuildContext, BookmarkGroup)? currentGroupBuilder;
  @override
  State<BookmarkFolderPickerContents> createState() =>
      _BookmarkFolderPickerContentsState();
}

class _BookmarkFolderPickerContentsState
    extends State<BookmarkFolderPickerContents> {
  late final _localNavigation = BookmarkPickerNavigation();
  BookmarkPickerNavigation get _navigation =>
      widget.navigation ?? _localNavigation;
  final _scrollController = ScrollController();
  late BookmarkGroupTree _tree;
  @override
  void initState() {
    super.initState();
    _updateSnapshot();
    _navigation.addListener(_navigated);
  }

  @override
  void didUpdateWidget(BookmarkFolderPickerContents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigation != widget.navigation) {
      (oldWidget.navigation ?? _localNavigation).removeListener(_navigated);
      _navigation.addListener(_navigated);
    }
    if (!identical(oldWidget.folders, widget.folders) ||
        !identical(oldWidget.groups, widget.groups))
      _updateSnapshot();
  }

  void _updateSnapshot() {
    _tree = BookmarkGroupTree(
      widget.folders.isEmpty
          ? widget.groups
          : BookmarkHierarchyConversion.convert(
              groups: widget.groups,
              folders: widget.folders,
            ).groups,
    );
    _navigation.update(_tree);
  }

  void _navigated() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _navigation.removeListener(_navigated);
    _localNavigation.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = _navigation.currentId;
    final current = _tree.groupsById[id];
    final path = id == null
        ? context.t.sideMenu.home
        : [
            for (final group in _tree.ancestors(id)) group.displayName(context),
            current!.displayName(context),
          ].join(' / ');
    void back() {
      if (!_navigation.back()) widget.onRootBack?.call();
    }

    Widget target(BookmarkGroup group, {bool here = false}) {
      final enabled = widget.selectableGroupIds?.contains(group.id) ?? true;
      final body = enabled
          ? (here
                ? widget.currentGroupBuilder ?? widget.groupBuilder
                : widget.groupBuilder)(context, group)
          : BookmarkPickerMenuItem(
              title: group.displayName(context),
              icon: const Icon(Icons.bookmarks_outlined),
              onTap: null,
            );
      return here
          ? ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: body,
            )
          : BookmarkPickerSplitRow(
              key: ValueKey(('bookmark-picker-group', group.id)),
              onOpen: () => _navigation.open(group.id),
              navigationLabel:
                  '${context.t.bookmark.groups.open_group}: ${group.displayName(context)}',
              child: body,
            );
    }

    final navigation = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            key: const ValueKey('bookmark-picker-navigation'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: KurumiPopupMenuItem(
                  key: const ValueKey('bookmark-picker-back'),
                  hideOnTap: false,
                  icon: const Icon(Icons.arrow_back, size: 20),
                  title: Tooltip(
                    message: path,
                    child: Text(
                      path,
                      key: const ValueKey('bookmark-picker-path'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onTap: current == null && widget.onRootBack == null
                      ? null
                      : back,
                ),
              ),
              if (widget.onCreateGroup case final create?)
                Tooltip(
                  message: context.t.bookmark.groups.create_new,
                  child: SizedBox(
                    width: 64,
                    child: BookmarkPickerMenuItem(
                      key: const ValueKey('bookmark-picker-create-group'),
                      title: '',
                      icon: const Icon(Icons.add),
                      hideOnTap: false,
                      onTap: widget.createGroupEnabled
                          ? () => create(id)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const KurumiContextMenuDivider(),
      ],
    );
    final entries = <Widget>[
      if (current != null) ...[
        target(current, here: true),
        const KurumiContextMenuDivider(),
      ],
      if (id == null) ...widget.homeChildren,
      for (final group in _tree.childrenOf(id)) target(group),
      if (widget.footerBuilder case final footer?) ...[
        const KurumiContextMenuDivider(),
        footer(context, id),
      ],
    ];
    final contents = Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight.isFinite
                    ? constraints.maxHeight * .4
                    : double.infinity,
              ),
              child: SingleChildScrollView(child: navigation),
            ),
            Flexible(
              flex: 3,
              child: ListView(
                key: const ValueKey('bookmark-picker-hierarchy'),
                controller: _scrollController,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: entries,
              ),
            ),
            if (widget.pinnedFooter case final footer?)
              Flexible(
                flex: 2,
                child: SingleChildScrollView(
                  key: const ValueKey('bookmark-picker-recent'),
                  child: footer,
                ),
              ),
          ],
        ),
      ),
    );
    return KurumiBackHandler(
      enabled:
          widget.ownsBack &&
          current != null &&
          (ModalRoute.of(context)?.isCurrent ?? true),
      onBack: back,
      child: Focus(autofocus: true, skipTraversal: true, child: contents),
    );
  }
}

/// Independent direct action and a full-height 80dp trailing navigation target.
class BookmarkPickerSplitRow extends StatelessWidget {
  const BookmarkPickerSplitRow({
    required this.child,
    required this.onOpen,
    required this.navigationLabel,
    super.key,
  });
  final Widget child;
  final VoidCallback? onOpen;
  final String navigationLabel;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(end: 80),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: child,
        ),
      ),
      PositionedDirectional(
        end: 0,
        top: 0,
        bottom: 0,
        width: 80,
        child: Semantics(
          button: true,
          label: navigationLabel,
          enabled: onOpen != null,
          child: Tooltip(
            message: navigationLabel,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpen,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: BorderDirectional(
                      start: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: const Center(child: Icon(Icons.chevron_right)),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
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
    this.detail,
    this.hideOnTap = true,
    super.key,
  });

  final String title;
  final Widget icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? detail;
  final bool hideOnTap;

  @override
  Widget build(BuildContext context) => KurumiPopupMenuItem(
    icon: IconTheme.merge(
      data: const IconThemeData(size: 20),
      child: icon,
    ),
    title: BookmarkPickerLabel(
      label: title,
      detail: detail,
      enabled: onTap != null,
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

/// Inline metadata shares the group's baseline and the remaining row width.
class BookmarkPickerLabel extends StatelessWidget {
  const BookmarkPickerLabel({
    required this.label,
    this.detail,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String? detail;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: enabled ? theme.colorScheme.onSurface : theme.disabledColor,
      ),
    );
    final detail = this.detail;
    if (detail == null) return title;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
            child: title,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: detail,
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color:
                      theme.dividerTheme.color ??
                      theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
