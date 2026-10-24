import '../../../selection/collection_selection_bar.dart';
import '../../../widgets/multi_select_button.dart';
import '../types/bookmark_library_state.dart';
import '../../../selection/ordered_selection_canvas.dart';

import 'package:flutter/services.dart';

import '../../../selection/collection_selection.dart';
import '../../../selection/ordered_selection_controller.dart';
import '../../../selection/selection_input.dart';
import '../../../navigation/navigation_interaction_scopes.dart';

import 'package:foundation/performance.dart';

import '../../../../foundation/performance/performance_navigation.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../data/bookmark_group_name_filter.dart';
import '../widgets/bookmark_overview_filter.dart';
import '../widgets/bookmark_group_label.dart';
import '../widgets/bookmark_collection_deletion_summary.dart';
import '../../../configs/config/providers.dart';
import '../../../configs/config/types.dart';
import '../../../images/booru_image.dart';
import '../providers/bookmark_group_selectors.dart';
import '../providers/bookmark_provider.dart';
import '../../../groups/folder_tree.dart';
import '../../../groups/folder_navigation.dart';
import '../services/bookmark_library_service.dart';
import '../providers/bookmark_shuffle_provider.dart';
import '../providers/local_providers.dart';
import '../routes/route_utils.dart';
import '../types/bookmark.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_view.dart';
import '../widgets/bookmark_group_name_dialog.dart';
import '../widgets/bookmark_collection_order.dart';

class BookmarkGroupBrowserPage extends ConsumerStatefulWidget {
  const BookmarkGroupBrowserPage({this.folderId, super.key})
    : _ancestorRoutes = const {};
  const BookmarkGroupBrowserPage._nested({
    required this.folderId,
    required Map<String?, Route<dynamic>> ancestorRoutes,
  }) : _ancestorRoutes = ancestorRoutes;
  final Map<String?, Route<dynamic>> _ancestorRoutes;
  final String? folderId;
  @override
  ConsumerState<BookmarkGroupBrowserPage> createState() =>
      _BookmarkGroupBrowserPageState();
}

class _BookmarkGroupBrowserPageState
    extends ConsumerState<BookmarkGroupBrowserPage> {
  // Imports or another browser can remove the open folder. Fall back to Home.
  String? get _folderId {
    final id = widget.folderId;
    final folders = ref.read(bookmarkProvider).valueOrNull?.folders;
    return folders?.any((f) => f.id == id) == true ? id : null;
  }

  final _selection = OrderedSelectionController<CollectionSelectionKey>();
  final _scroll = ScrollController();
  final _filter = TextEditingController();
  var _filterVisible = false;
  String _lastFilter = '';
  bool _matches(String name) => bookmarkGroupNameMatches(name, _filter.text);
  Set<String> _matchingFolders(BookmarkLibraryState state) =>
      bookmarkMatchingFolderIds(
        folders: state.folders,
        matchingGroupFolderIds: state.groups
            .where((group) => _matches(group.displayName(context)))
            .map((group) => group.folderId),
        query: _filter.text,
      );

  void _toggleFilter() {
    setState(() => _filterVisible = !_filterVisible);
    if (!_filterVisible) {
      _filter.clear();
      FocusScope.of(context).unfocus();
    }
  }

  (BookmarkLibraryState, BookmarkSortType, BookmarkShuffleState)?
  _previewInputs;
  final _previews = <BookmarkView, List<Bookmark>>{};
  AsyncValue<BookmarkLibraryState>? _visibleLibrary;
  Set<String> get _selectedGroups => {
    for (final (kind, id) in _selection.selectedKeys)
      if (kind == CollectionSelectionKind.group) id,
  };
  Set<String> get _selectedFolders => {
    for (final (kind, id) in _selection.selectedKeys)
      if (kind == CollectionSelectionKind.folder) id,
  };
  bool get _selecting => _selection.isActive;
  @override
  void initState() {
    super.initState();
    _selection.addListener(_selectionChanged);
    _filter.addListener(_filterChanged);
  }

  void _filterChanged() {
    if (_lastFilter == _filter.text) return;
    _lastFilter = _filter.text;
    // Hidden cards must never remain selected for a destructive bulk action.
    _selection.disable();
    setState(() {});
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _selectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _filter.removeListener(_filterChanged);
    _filter.dispose();
    _selection.removeListener(_selectionChanged);
    _selection.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _select(String id, {bool folder = false}) {
    final index = _selection.indexOf((
      folder ? CollectionSelectionKind.folder : CollectionSelectionKind.group,
      id,
    ));
    if (index == null) return;
    _selection.click(
      index,
      range: HardwareKeyboard.instance.isShiftPressed,
      additive: selectionAdditivePressed,
    );
  }

  void _openFolder(String? id) {
    if (id == _folderId) return;
    final navigator = Navigator.of(context);
    final previous = widget._ancestorRoutes[id];
    if (previous != null) {
      navigator.popUntil((route) => route == previous);
      return;
    }
    final currentRoute = ModalRoute.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => BookmarkGroupBrowserPage._nested(
          folderId: id,
          ancestorRoutes: {
            ...widget._ancestorRoutes,
            _folderId: ?currentRoute,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = TickerMode.of(context);
    final AsyncValue<BookmarkLibraryState> library = visible
        ? ref.watch(bookmarkProvider)
        : _visibleLibrary ?? ref.read(bookmarkProvider);
    // Covered routes retain their previews until visible again. Refiltering
    // every group here would otherwise run during grid and viewer mutations.
    if (visible || _visibleLibrary == null) _visibleLibrary = library;
    if (library.valueOrNull case final state?) {
      final matchingFolders = _matchingFolders(state);
      final folders = bookmarkFoldersByName(
        FolderTree(state.folders)
            .children(_folderId)
            .where(
              (folder) => matchingFolders.contains(folder.id),
            ),
      );
      final groups = bookmarkGroupsByName(
        state.groups.where(
          (g) =>
              !g.isDefault &&
              g.folderId == _folderId &&
              _matches(g.displayName(context)),
        ),
      );
      _selection.reconcileDuringBuild([
        for (final folder in folders)
          (CollectionSelectionKind.folder, folder.id),
        for (final group in groups) (CollectionSelectionKind.group, group.id),
      ], scope: _folderId);
    }
    return CollectionSelection(
      controller: _selection,
      scrollController: _scroll,
      child: NavigationSelectionBridge(
        controller: _selection,
        selected: _selecting,
        child: PerformanceScreenScope(
          screen: PerfScreen.bookmarkGroups,
          priority: 2,
          child: Scaffold(
            appBar: KurumiAppBar(
              title: Text(
                library.valueOrNull?.folders
                        .where((f) => f.id == _folderId)
                        .firstOrNull
                        ?.name ??
                    context.t.bookmark.groups.selector,
              ),
              actions: [
                if (!_selecting)
                  IconButton(
                    key: const Key('bookmark-group-filter-toggle'),
                    tooltip: _filterVisible
                        ? context.t.generic.action.cancel
                        : context.t.generic.action.search,
                    onPressed: _toggleFilter,
                    icon: Icon(
                      _filterVisible ? Icons.search_off : Icons.search,
                    ),
                  ),
                if (!_selecting)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) => switch (action) {
                      'folder' => _createFolder(),
                      'group' => _create(context, ref),
                      _ => null,
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'folder',
                        child: Text(context.t.bookmark.groups.add_folder),
                      ),
                      PopupMenuItem(
                        value: 'group',
                        child: Text(context.t.bookmark.groups.add),
                      ),
                    ],
                  ),
              ],
            ),
            bottomNavigationBar: _selecting && library.valueOrNull != null
                ? CollectionSelectionBar(
                    controller: _selection,
                    actions: _selectionActions(library.requireValue),
                  )
                : null,
            body: SafeArea(
              top: false,
              child: library.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(child: Icon(Icons.error_outline)),
                data: (state) {
                  final sort = ref.watch(selectedBookmarkSortTypeProvider);
                  final shuffle = ref.watch(bookmarkShuffleProvider);
                  final tree = FolderTree(state.folders);
                  final matchingFolders = _matchingFolders(state);
                  final folders = bookmarkFoldersByName(
                    tree
                        .children(_folderId)
                        .where(
                          (folder) => matchingFolders.contains(folder.id),
                        ),
                  );
                  final groups = bookmarkGroupsByName(
                    state.groups.where(
                      (g) =>
                          !g.isDefault &&
                          g.folderId == _folderId &&
                          _matches(g.displayName(context)),
                    ),
                  );
                  final inputs = (state, sort, shuffle);
                  final previous = _previewInputs;
                  if (previous == null ||
                      !identical(previous.$1, state) ||
                      previous.$2 != sort ||
                      previous.$3 != shuffle) {
                    _previewInputs = inputs;
                    _previews.clear();
                  }
                  List<Bookmark> previews(BookmarkView view) =>
                      _previews.putIfAbsent(
                        view,
                        () => selectBookmarkPreviews(
                          state: state,
                          view: view,
                          sortType: sort,
                          shuffleState: shuffle,
                        ),
                      );
                  Widget specialView(
                    String title,
                    BookmarkView view, {
                    BookmarkGroup? group,
                  }) => _GroupCard(
                    title: title,
                    previews: previews(view),
                    group: group,
                    onTap: (_selecting || selectionModifierPressed)
                        ? null
                        : () => goToBookmarkGroupPage(ref, view, title: title),
                    onRename: null,
                    onDuplicate: null,
                    onDelete: null,
                  );
                  final defaultGroup = state.groupsById[defaultBookmarkGroupId];
                  final specialCards = <Widget>[
                    if (_folderId == null) ...[
                      if (_matches(context.t.bookmark.groups.all))
                        specialView(
                          context.t.bookmark.groups.all,
                          const BookmarkView.all(),
                        ),
                      if (defaultGroup != null &&
                          _matches(defaultGroup.displayName(context)))
                        specialView(
                          defaultGroup.displayName(context),
                          const BookmarkView.defaultGroup(),
                          group: defaultGroup,
                        ),
                    ],
                  ];
                  final noMatches =
                      _filter.text.trim().isNotEmpty &&
                      specialCards.isEmpty &&
                      folders.isEmpty &&
                      groups.isEmpty;
                  return Column(
                    children: [
                      if (_filterVisible)
                        BookmarkOverviewFilter(controller: _filter),
                      if (_folderId != null)
                        FolderBreadcrumbs(
                          tree: tree,
                          currentId: _folderId,
                          onOpen: _openFolder,
                        ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final delegate =
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      switch (constraints.maxWidth) {
                                        < 500 => 2,
                                        < 850 => 3,
                                        _ => 4,
                                      },
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                );
                            return OrderedSelectionCanvas(
                              controller: _selection,
                              child: CustomScrollView(
                                controller: _scroll,
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                slivers: [
                                  if (noMatches)
                                    SliverFillRemaining(
                                      hasScrollBody: false,
                                      child: BookmarkOverviewNoMatches(
                                        onClear: _filter.clear,
                                      ),
                                    ),
                                  if (specialCards.isNotEmpty) ...[
                                    SliverPadding(
                                      padding: const EdgeInsets.all(12),
                                      sliver: SliverGrid(
                                        gridDelegate: delegate,
                                        delegate: SliverChildListDelegate(
                                          specialCards,
                                        ),
                                      ),
                                    ),
                                    const SliverToBoxAdapter(
                                      child: Divider(
                                        indent: 12,
                                        endIndent: 12,
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                  if (!noMatches)
                                    SliverPadding(
                                      padding: const EdgeInsets.all(12),
                                      sliver: SliverGrid(
                                        gridDelegate: delegate,
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) {
                                            if (index < folders.length) {
                                              final folder = folders[index];
                                              final descendants = tree.subtree(
                                                folder.id,
                                              );
                                              final descendantsGroups =
                                                  bookmarkGroupsByName(
                                                    state.groups.where(
                                                      (g) =>
                                                          descendants.contains(
                                                            g.folderId,
                                                          ),
                                                    ),
                                                  );
                                              return CollectionSelectable(
                                                key: ValueKey((
                                                  'folder',
                                                  folder.id,
                                                )),
                                                controller: _selection,
                                                itemKey: (
                                                  CollectionSelectionKind
                                                      .folder,
                                                  folder.id,
                                                ),
                                                child: _GroupCard(
                                                  title: folder.name,
                                                  previews: [
                                                    for (final group
                                                        in descendantsGroups
                                                            .take(
                                                              4,
                                                            ))
                                                      ...previews(
                                                        BookmarkView.group(
                                                          group.id,
                                                        ),
                                                      ).take(1),
                                                  ],
                                                  group: null,
                                                  isFolder: true,
                                                  selected: _selectedFolders
                                                      .contains(
                                                        folder.id,
                                                      ),
                                                  onSelect: _selecting
                                                      ? null
                                                      : () => _select(
                                                          folder.id,
                                                          folder: true,
                                                        ),
                                                  onTap: () =>
                                                      (_selecting ||
                                                          selectionModifierPressed)
                                                      ? _select(
                                                          folder.id,
                                                          folder: true,
                                                        )
                                                      : _openFolder(folder.id),
                                                  onRename: () =>
                                                      _renameFolder(folder),
                                                  onDuplicate: null,
                                                  onDelete: () =>
                                                      _deleteFolder(folder),
                                                  onMove: () => _move(
                                                    folderIds: {folder.id},
                                                  ),
                                                ),
                                              );
                                            }
                                            final group =
                                                groups[index - folders.length];
                                            return CollectionSelectable(
                                              key: ValueKey((
                                                'group',
                                                group.id,
                                              )),
                                              controller: _selection,
                                              itemKey: (
                                                CollectionSelectionKind.group,
                                                group.id,
                                              ),
                                              child: _GroupCard(
                                                title: group.displayName(
                                                  context,
                                                ),
                                                previews: previews(
                                                  BookmarkView.group(group.id),
                                                ),
                                                group: group,
                                                selected: _selectedGroups
                                                    .contains(
                                                      group.id,
                                                    ),
                                                onSelect:
                                                    group.isDefault ||
                                                        _selecting
                                                    ? null
                                                    : () => _select(group.id),
                                                onMove: group.isDefault
                                                    ? null
                                                    : () => _move(
                                                        groupIds: {group.id},
                                                      ),
                                                onTap:
                                                    (_selecting ||
                                                        selectionModifierPressed)
                                                    ? (group.isDefault
                                                          ? null
                                                          : () => _select(
                                                              group.id,
                                                            ))
                                                    : () =>
                                                          goToBookmarkGroupPage(
                                                            ref,
                                                            BookmarkView.group(
                                                              group.id,
                                                            ),
                                                            title: group
                                                                .displayName(
                                                                  context,
                                                                ),
                                                          ),
                                                onRename:
                                                    group.isDefault ||
                                                        _selecting
                                                    ? null
                                                    : () => _rename(
                                                        context,
                                                        ref,
                                                        group,
                                                      ),
                                                onDuplicate: () =>
                                                    _duplicateSelected([group]),
                                                onDelete: group.isDefault
                                                    ? null
                                                    : () => _delete(
                                                        context,
                                                        ref,
                                                        group,
                                                      ),
                                              ),
                                            );
                                          },
                                          childCount:
                                              folders.length + groups.length,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _selectionActions(BookmarkLibraryState state) {
    final groups = [
      for (final group in state.groups)
        if (_selectedGroups.contains(group.id)) group,
    ];
    final folders = [
      for (final folder in state.folders)
        if (_selectedFolders.contains(folder.id)) folder,
    ];
    if (groups.isEmpty && folders.isEmpty) return const [];
    return [
      MultiSelectButton(
        primary: true,
        name: context.t.folders.move,
        icon: const Icon(Icons.drive_file_move_outline),
        onPressed: () => _move(),
      ),
      if (groups.length + folders.length == 1)
        MultiSelectButton(
          name: groups.isNotEmpty
              ? context.t.bookmark.groups.rename
              : context.t.folders.rename,
          icon: const Icon(Icons.edit),
          onPressed: () => groups.isNotEmpty
              ? _rename(context, ref, groups.single)
              : _renameFolder(folders.single),
        ),
      if (folders.isEmpty)
        MultiSelectButton(
          name: context.t.bookmark.groups.duplicate,
          icon: const Icon(Icons.copy),
          onPressed: () => _duplicateSelected(groups),
        ),
      MultiSelectButton(
        primary: true,
        name: context.t.generic.action.delete,
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _deleteSelected(),
      ),
    ];
  }

  Future<void> _deleteSelected() async {
    final folders = _selectedFolders;
    final groups = _selectedGroups;
    final notifier = ref.read(bookmarkProvider.notifier);
    try {
      var preview = await notifier.previewDeleteSelection(
        folderIds: folders,
        groupIds: groups,
      );
      while (mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: Text(context.t.generic.action.delete),
            content: BookmarkCollectionDeletionSummary(
              folders: preview.folderIds.length,
              groups: preview.groupIds.length,
              uniqueBookmarks: preview.orphanBookmarkIds.length,
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
        if (confirmed != true || !mounted) return;
        try {
          await notifier.deleteSelection(preview);
          if (mounted) _selection.disable();
          return;
        } on BookmarkCollectionChangedException catch (error) {
          preview = error.preview;
        }
      }
    } catch (_) {
      if (mounted)
        Kurumi.showErrorToast(
          context,
          context.t.bookmark.groups.operation_failed,
        );
    }
  }

  Future<void> _duplicateSelected(List<BookmarkGroup> groups) async {
    final names = {
      for (final group in groups)
        group.id: context.t.bookmark.groups.copy_name.replaceAll(
          '{name}',
          group.displayName(context),
        ),
    };
    await _runGroupAction(
      context,
      () => ref
          .read(bookmarkProvider.notifier)
          .duplicateGroups(names, expectedGroups: groups),
      clearSelection: true,
    );
  }

  Future<void> _move({Set<String>? folderIds, Set<String>? groupIds}) async {
    final library = ref.read(bookmarkProvider).requireValue;
    final foldersToMove = folderIds ?? _selectedFolders;
    final groupsToMove = groupIds ?? _selectedGroups;
    final choice = await showFolderDestinationPicker(
      context,
      folders: library.folders,
      initialFolderId: _folderId,
      movingFolderIds: foldersToMove,
      sortByName: true,
      confirmationLabel: context.t.bookmark.groups.move_here,
      canMoveTo: (destination) =>
          library.folders.any(
            (f) => foldersToMove.contains(f.id) && f.parentId != destination,
          ) ||
          library.groups.any(
            (g) => groupsToMove.contains(g.id) && g.folderId != destination,
          ),
    );
    if (choice == null || !mounted) return;
    final moved = await _runGroupAction(
      context,
      () => ref
          .read(bookmarkProvider.notifier)
          .moveFolderItems(
            folderIds: foldersToMove,
            groupIds: groupsToMove,
            destination: choice.folderId,
          ),
    );
    if (mounted && moved) {
      _selection.disable();
    }
  }

  Future<void> _createFolder() async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.folders.create,
      hint: context.t.folders.name,
    );
    if (name == null || !mounted) return;
    await _runGroupAction(
      context,
      () => ref
          .read(bookmarkProvider.notifier)
          .createFolder(name, parentId: _folderId),
    );
  }

  Future<void> _renameFolder(CollectionFolder folder) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.folders.rename,
      hint: context.t.folders.name,
      initialName: folder.name,
    );
    if (name == null || !mounted) return;
    await _runGroupAction(
      context,
      () => ref.read(bookmarkProvider.notifier).renameFolder(folder.id, name),
      clearSelection: true,
    );
  }

  Future<void> _deleteFolder(CollectionFolder folder) async {
    var preview = await ref
        .read(bookmarkProvider.notifier)
        .previewDeleteFolder(folder.id);
    while (mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(
            context.t.folders.delete_title.replaceAll('{name}', folder.name),
          ),
          content: BookmarkCollectionDeletionSummary(
            folders: preview.folderIds.length,
            groups: preview.groupIds.length,
            uniqueBookmarks: preview.orphanBookmarkIds.length,
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
      if (confirmed != true || !mounted) return;
      try {
        await ref.read(bookmarkProvider.notifier).deleteFolder(preview);
        return;
      } on BookmarkFolderChangedException catch (e) {
        preview = e.preview;
      } catch (_) {
        if (mounted) {
          Kurumi.showErrorToast(
            context,
            context.t.bookmark.groups.operation_failed,
          );
        }
        return;
      }
    }
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
    );
    if (name == null) return;
    if (!context.mounted) return;
    await _runGroupAction(
      context,
      () => ref
          .read(bookmarkProvider.notifier)
          .createGroup(name, folderId: _folderId),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    BookmarkGroup group,
  ) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.rename,
      initialName: group.name,
    );
    if (name == null) return;
    if (!context.mounted) return;
    await _runGroupAction(
      context,
      () => ref.read(bookmarkProvider.notifier).renameGroup(group.id, name),
      clearSelection: true,
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BookmarkGroup group,
  ) async {
    final groups = ref.read(bookmarkProvider).valueOrNull?.groups ?? [group];
    var current = _deletionPreview(group, groups);
    while (true) {
      if (current.group.bookmarkIds.isNotEmpty) {
        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              context.t.bookmark.groups.delete_group_title.replaceAll(
                '{name}',
                current.group.name,
              ),
            ),
            content: Text(
              context.t.bookmark.groups.delete_group_message.replaceAll(
                '{bookmarks}',
                '${current.group.bookmarkIds.length}',
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
        if (confirmed != true || !context.mounted) return;
      }
      try {
        await ref
            .read(bookmarkProvider.notifier)
            .deleteGroup(
              current.group.id,
              expectedPreview: current,
            );
        return;
      } on BookmarkGroupChangedException catch (error) {
        current = error.preview;
      } catch (_) {
        if (context.mounted) {
          Kurumi.showErrorToast(
            context,
            context.t.bookmark.groups.operation_failed,
          );
        }
        return;
      }
    }
  }

  BookmarkGroupDeletionPreview _deletionPreview(
    BookmarkGroup group,
    Iterable<BookmarkGroup> groups,
  ) {
    final otherBookmarkIds = groups
        .where((other) => other.id != group.id)
        .expand((other) => other.bookmarkIds)
        .toSet();
    return BookmarkGroupDeletionPreview(
      group: group,
      orphanBookmarkIds: group.bookmarkIds.difference(otherBookmarkIds),
    );
  }

  Future<bool> _runGroupAction(
    BuildContext context,
    Future<Object?> Function() action, {
    bool clearSelection = false,
  }) async {
    try {
      await action();
      if (mounted && clearSelection) _selection.disable();
      return true;
    } catch (_) {
      if (context.mounted) {
        Kurumi.showErrorToast(
          context,
          context.t.bookmark.groups.operation_failed,
        );
      }
      return false;
    }
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.previews,
    required this.group,
    required this.onTap,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    this.isFolder = false,
    this.selected = false,
    this.onSelect,
    this.onMove,
  });

  final bool isFolder;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onMove;
  final String title;
  final List<Bookmark> previews;
  final BookmarkGroup? group;
  final VoidCallback? onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    return Semantics(
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? .38 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Kurumi.themeOf(context).colorScheme.outlineVariant,
            ),
            borderRadius: borderRadius,
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                onLongPress: onSelect,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: BookmarkGroupPreviewGrid(
                        previews: previews,
                        itemBuilder: (_, bookmark) =>
                            _BookmarkGroupPreviewImage(bookmark: bookmark),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x99000000), Color(0x66000000)],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      right: onRename == null ? 8 : 52,
                      // Reserve the bottom indicators only when present.
                      bottom: selected || isFolder ? 40 : 8,
                      child: DefaultTextStyle(
                        style: Kurumi.themeOf(context).textTheme.titleMedium!
                            .copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: const [Shadow(blurRadius: 4)],
                            ),
                        child: KurumiFittedText(
                          Text(title),
                          alignment: AlignmentDirectional.topStart,
                        ),
                      ),
                    ),
                    if (selected)
                      const Positioned(
                        bottom: 8,
                        right: 8,
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                        ),
                      ),
                    if (isFolder)
                      const Positioned(
                        bottom: 8,
                        left: 8,
                        child: Icon(Icons.folder, color: Colors.white),
                      ),
                    if (onRename != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                          ),
                          onSelected: (action) => switch (action) {
                            'rename' => onRename?.call(),
                            'duplicate' => onDuplicate?.call(),
                            'delete' => onDelete?.call(),
                            'move' => onMove?.call(),
                            'select' => onSelect?.call(),
                            _ => null,
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'select',
                              child: Text(context.t.folders.select),
                            ),
                            PopupMenuItem(
                              value: 'move',
                              child: Text(context.t.folders.move),
                            ),
                            PopupMenuItem(
                              value: 'rename',
                              child: Text(context.t.bookmark.groups.rename),
                            ),
                            if (onDuplicate != null)
                              PopupMenuItem(
                                value: 'duplicate',
                                child: Text(
                                  context.t.bookmark.groups.duplicate,
                                ),
                              ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(context.t.bookmark.groups.delete),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BookmarkGroupPreviewGrid extends StatelessWidget {
  const BookmarkGroupPreviewGrid({
    required this.previews,
    required this.itemBuilder,
    super.key,
  });

  final List<Bookmark> previews;
  final Widget Function(BuildContext context, Bookmark bookmark) itemBuilder;

  @override
  Widget build(BuildContext context) => GridView.builder(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(2),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 2,
      mainAxisSpacing: 2,
    ),
    itemCount: 4,
    itemBuilder: (context, index) => index < previews.length
        ? itemBuilder(context, previews[index])
        : const SizedBox.shrink(),
  );
}

String bookmarkGroupPreviewUrl(Bookmark bookmark) =>
    bookmark.isVideo ? bookmark.thumbnailUrl : bookmark.sampleUrl;

class _BookmarkGroupPreviewImage extends ConsumerWidget {
  const _BookmarkGroupPreviewImage({required this.bookmark});

  final Bookmark bookmark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = Uri.tryParse(bookmark.sourceUrl)?.host ?? '';
    final imageConfig = ref.watch(
      firstMatchingConfigByBooruTypeProvider((bookmark.booruId, host)),
    );
    return BooruImage(
      imageUrl: bookmarkGroupPreviewUrl(bookmark),
      config: imageConfig?.auth ?? ref.watchConfigAuth,

      fit: BoxFit.cover,
      placeholderWidget: const SizedBox.expand(),
    );
  }
}
