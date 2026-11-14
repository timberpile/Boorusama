import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/performance.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../../../foundation/performance/performance_navigation.dart';
import '../../../navigation/navigation_interaction_scopes.dart';
import '../../../backups/folder_sync/page.dart';
import '../../../backups/folder_sync/providers.dart';
import '../../../backups/folder_sync/reading_state.dart';
import '../../../navigation/destination_activity.dart';
import '../../../selection/collection_selection.dart';
import '../../../selection/collection_selection_bar.dart';
import '../../../selection/ordered_selection_canvas.dart';
import '../../../selection/ordered_selection_controller.dart';
import '../../../selection/selection_input.dart';
import '../../../widgets/multi_select_button.dart';
import '../../../widgets/widgets.dart';
import '../providers/bookmark_group_selectors.dart';
import '../providers/bookmark_group_view_preferences.dart';
import '../providers/bookmark_provider.dart';
import '../providers/bookmark_profile_availability.dart';
import '../providers/bookmark_shuffle_provider.dart';
import '../providers/local_providers.dart';
import '../routes/route_utils.dart';
import '../services/bookmark_library_service.dart';
import '../types/bookmark.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_library_state.dart';
import '../types/bookmark_view.dart';
import '../types/pool_bookmark.dart';
import '../types/content_group_bookmark.dart';
import '../types/bookmark_grid_entry.dart';
import '../widgets/bookmark_collection_deletion_summary.dart';
import '../widgets/bookmark_group_destination_picker.dart';
import '../widgets/bookmark_group_label.dart';
import '../widgets/bookmark_group_name_dialog.dart';
import '../widgets/bookmark_local_group_card.dart';
import '../widgets/bookmark_scroll_view.dart';

export '../widgets/bookmark_local_group_card.dart'
    show BookmarkGroupPreviewGrid, bookmarkGroupPreviewUrl;

/// Home and ordinary groups share navigation and the same timeline surface.
class BookmarkGroupBrowserPage extends ConsumerStatefulWidget {
  const BookmarkGroupBrowserPage({this.groupId, this.folderId, super.key});
  final String? groupId;
  // Transitional route input; resolved through the persisted conversion alias.
  final String? folderId;
  @override
  ConsumerState<BookmarkGroupBrowserPage> createState() =>
      _BookmarkGroupBrowserPageState();
}

class _BookmarkGroupBrowserPageState
    extends ConsumerState<BookmarkGroupBrowserPage> {
  late String? _requestedId = widget.groupId ?? widget.folderId;
  late bool _legacyFolderRequest =
      widget.groupId == null && widget.folderId != null;
  List<String> _lastPath = const [];
  AsyncValue<BookmarkLibraryState>? _visibleLibrary;
  bool _normalizing = false;
  final _search = TextEditingController();
  final _selection = OrderedSelectionController<CollectionSelectionKey>();
  final _scrolls = <Object, AutoScrollController>{};
  final _previews = <String, List<PostBookmark>>{};
  final _poolPreviews = <String, List<CollectionBookmark>>{};
  final _nativePreviews = <String, List<ContentGroupBookmark>>{};
  (
    BookmarkLibraryState,
    BookmarkSortType,
    BookmarkShuffleState,
    BookmarkProfileAvailability?,
  )?
  _previewInputs;

  @override
  void initState() {
    super.initState();
    _selection.addListener(_selectionChanged);
  }

  void _selectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _selection.removeListener(_selectionChanged);
    _selection.dispose();
    _search.dispose();
    for (final scroll in _scrolls.values) {
      scroll.dispose();
    }
    super.dispose();
  }

  String? _currentId(BookmarkLibraryState? state) {
    if (state == null) return _requestedId;
    final resolved = _legacyFolderRequest
        ? state.legacyFolderGroupIds[_requestedId] ?? _requestedId
        : _requestedId;
    if (state.groupsById.containsKey(resolved)) return resolved;
    // A removed open node returns to its nearest surviving ancestor.
    return _lastPath.reversed.where(state.groupsById.containsKey).firstOrNull;
  }

  void _open(String? id) {
    if (id == _currentId(ref.read(bookmarkProvider).valueOrNull)) {
      _requestedId = id;
      _legacyFolderRequest = false;
      return;
    }
    _selection.disable();
    FocusScope.of(context).unfocus();
    _search.clear();
    setState(() {
      _requestedId = id;
      _legacyFolderRequest = false;
      _lastPath = const [];
    });
  }

  void _select(String id) {
    final index = _selection.indexOf((CollectionSelectionKind.group, id));
    if (index == null) return;
    _selection.click(
      index,
      range: HardwareKeyboard.instance.isShiftPressed,
      additive: selectionAdditivePressed,
    );
  }

  final _acknowledged = <(String, int)>{};

  void _acknowledge(BookmarkLibraryState? state, String? id, bool visible) {
    final owner = state?.mirrors.owners[id];
    if (!visible ||
        id == null ||
        owner == null ||
        !(ModalRoute.of(context)?.isCurrent ?? true) ||
        !NavigationActivity.of(context))
      return;
    final key = (id, owner.revision);
    final reading = SyncGroupReadingState.fromJson(owner.reading);
    if (!reading.hasUnseenChange || !_acknowledged.add(key)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _currentId(ref.read(bookmarkProvider).valueOrNull) != id ||
          !(ModalRoute.of(context)?.isCurrent ?? true) ||
          !NavigationActivity.of(context)) {
        _acknowledged.remove(key);
        return;
      }
      final pending = ref.read(folderSyncServiceProvider.future);
      unawaited(() async {
        try {
          final service = await pending;
          if (mounted) await service.acknowledge(id, owner.revision);
        } catch (_) {
          _acknowledged.remove(key);
        }
      }());
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = TickerMode.of(context);
    final AsyncValue<BookmarkLibraryState> library = visible
        ? ref.watch(bookmarkProvider)
        : (_visibleLibrary ?? ref.read(bookmarkProvider));
    if (visible || _visibleLibrary == null) _visibleLibrary = library;
    final state = library.valueOrNull;
    final id = _currentId(state);
    final group = state?.groupsById[id];
    _acknowledge(state, id, visible);
    final children = state?.groupTree.childrenOf(id) ?? const <BookmarkGroup>[];
    final ordinaryChildren = children
        .where(
          (child) =>
              !child.isDefault &&
              (id != null || !(state?.mirrors.isReceived(child.id) ?? false)),
        )
        .toList();
    final requested = _legacyFolderRequest
        ? state?.legacyFolderGroupIds[_requestedId] ?? _requestedId
        : _requestedId;
    if (state != null && requested != id && !_normalizing) {
      _normalizing = true;
      final captured = _requestedId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _normalizing = false;
        if (!mounted || _requestedId != captured) return;
        _selection.disable();
        _search.clear();
        setState(() {
          _requestedId = id;
          _legacyFolderRequest = false;
        });
      });
    }
    if (id != null && state != null && requested == id) {
      _lastPath = [
        for (final ancestor in state.groupTree.ancestors(id)) ancestor.id,
      ];
    }
    final storedMode =
        ref.watch(bookmarkGroupViewPreferencesProvider)[id] ??
        BookmarkGroupViewMode.structure;
    final mode = ordinaryChildren.isEmpty
        ? BookmarkGroupViewMode.structure
        : storedMode;
    final view = id == null
        ? null
        : mode == BookmarkGroupViewMode.allBookmarks
        ? BookmarkView.subtree(id)
        : BookmarkView.group(id);
    final scope = (id, mode);
    final scroll = _scrolls.putIfAbsent(scope, AutoScrollController.new);
    _selection.reconcileDuringBuild([
      if (mode == BookmarkGroupViewMode.structure)
        for (final child in ordinaryChildren)
          (CollectionSelectionKind.group, child.id),
    ], scope: scope);
    final selected = {
      for (final (_, selectedId) in _selection.selectedKeys) selectedId,
    };
    final title =
        group?.displayName(context) ?? context.t.bookmark.groups.selector;
    void up() => _open(group?.parentGroupId);

    return PopScope(
      canPop: id == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_selection.isActive) up();
      },
      child: CollectionSelection(
        controller: _selection,
        scrollController: scroll,
        child: NavigationSelectionBridge(
          controller: _selection,
          selected: _selection.isActive,
          child: PerformanceScreenScope(
            screen: PerfScreen.bookmarkGroups,
            priority: 2,
            child: CustomContextMenuOverlay(
              child: Scaffold(
                appBar: KurumiAppBar(
                  leading: id == null ? null : BackButton(onPressed: up),
                  title: id == null || state == null
                      ? Text(title)
                      : KurumiPopupMenuButton(
                          semanticLabel:
                              context.t.bookmark.groups.choose_ancestor,
                          maxWidth: 280,
                          items: [_ancestorMenu(state, id, title)],
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(child: KurumiFittedText(Text(title))),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                  actions: [
                    if (id != null && ordinaryChildren.isNotEmpty)
                      IconButton(
                        key: const Key('bookmark-group-view-mode'),
                        tooltip: mode == BookmarkGroupViewMode.structure
                            ? context.t.bookmark.groups.all_bookmarks
                            : context.t.bookmark.groups.structure,
                        isSelected: mode == BookmarkGroupViewMode.allBookmarks,
                        icon: Semantics(
                          value: mode == BookmarkGroupViewMode.structure
                              ? context.t.bookmark.groups.structure
                              : context.t.bookmark.groups.all_bookmarks,
                          child: SvgPicture.asset(
                            mode == BookmarkGroupViewMode.structure
                                ? 'assets/icon/bookmark_view_structure.svg'
                                : 'assets/icon/bookmark_view_unified.svg',
                            width: 24,
                            height: 24,
                            colorFilter: ColorFilter.mode(
                              Theme.of(context).colorScheme.onSurface,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        onPressed: () => _setMode(
                          id,
                          mode == BookmarkGroupViewMode.structure
                              ? BookmarkGroupViewMode.allBookmarks
                              : BookmarkGroupViewMode.structure,
                        ),
                      ),
                    KurumiPopupMenuButton(
                      enabled: state != null,
                      semanticLabel: context.t.generic.action.more,
                      items: [
                        if (group != null && state != null)
                          ..._syncActions(state, group),
                        if (!(state?.mirrors.isReceived(id ?? '') ?? false))
                          KurumiPopupMenuItem(
                            title: Text(context.t.bookmark.groups.add),
                            icon: const Icon(Icons.add),
                            onTap: () => _create(id),
                          ),
                        if (group != null &&
                            !group.isDefault &&
                            !state!.mirrors.isReceived(group.id)) ...[
                          KurumiPopupMenuItem(
                            title: Text(context.t.bookmark.groups.rename),
                            onTap: () => _rename(group),
                          ),
                          KurumiPopupMenuItem(
                            title: Text(context.t.folders.move),
                            onTap: () => _move({group.id}, id),
                          ),
                          KurumiPopupMenuItem(
                            title: Text(context.t.bookmark.groups.duplicate),
                            onTap: () => _duplicate([group]),
                          ),
                          KurumiPopupMenuItem(
                            title: Text(context.t.generic.action.delete),
                            onTap: () => _delete({group.id}),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                bottomNavigationBar: !_selection.isActive
                    ? null
                    : CollectionSelectionBar(
                        controller: _selection,
                        actions: [
                          MultiSelectButton(
                            name: context.t.folders.move,
                            icon: const Icon(Icons.drive_file_move_outline),
                            onPressed: () => _move(selected, id),
                          ),
                          if (selected.length == 1)
                            MultiSelectButton(
                              name: context.t.bookmark.groups.rename,
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  _rename(state!.groupsById[selected.single]!),
                            ),
                          MultiSelectButton(
                            name: context.t.bookmark.groups.duplicate,
                            icon: const Icon(Icons.copy),
                            onPressed: () => _duplicate([
                              for (final selectedId in selected)
                                state!.groupsById[selectedId]!,
                            ]),
                          ),
                          MultiSelectButton(
                            primary: true,
                            name: context.t.generic.action.delete,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(selected),
                          ),
                        ],
                      ),
                body: SafeArea(
                  top: false,
                  bottom: false,
                  child: library.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) =>
                        const Center(child: Icon(Icons.error_outline)),
                    data: (state) {
                      _updatePreviewInputs(state, visible: visible);
                      final genuinelyEmpty =
                          view != null &&
                          state.bookmarkIdsForView(view).isEmpty &&
                          (state.hasUnifiedRecords ||
                              !state.pools.any(
                                (pool) => pool.groupIds.contains(id),
                              ));
                      final cards = _cards(
                        state,
                        id,
                        ordinaryChildren,
                        selected,
                      );
                      final slivers = <Widget>[
                        if (id == null && state.mirrors.owners.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Text(context.t.folder_sync.local),
                            ),
                          ),
                        if (mode == BookmarkGroupViewMode.structure &&
                            (id == null || ordinaryChildren.isNotEmpty))
                          if (id != null && !genuinelyEmpty)
                            CollectionSelectionBinding(
                              controller: _selection,
                              child: cards,
                            )
                          else
                            cards,
                        if (id != null &&
                            mode == BookmarkGroupViewMode.structure &&
                            ordinaryChildren.isNotEmpty &&
                            !genuinelyEmpty)
                          const SliverToBoxAdapter(
                            child: Divider(
                              indent: 12,
                              endIndent: 12,
                              height: 1,
                            ),
                          ),
                      ];
                      if (id == null || genuinelyEmpty) {
                        return OrderedSelectionCanvas(
                          controller: _selection,
                          child: CustomScrollView(
                            key: PageStorageKey(scope),
                            controller: scroll,
                            slivers: [
                              ...slivers,
                              if (id == null) ..._deviceSlivers(state),
                              if (genuinelyEmpty &&
                                  (mode != BookmarkGroupViewMode.structure ||
                                      ordinaryChildren.isEmpty))
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(context.t.bookmark.none),
                                  ),
                                ),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: MediaQuery.viewPaddingOf(context)
                                      .bottom,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return OrderedSelectionCanvas(
                        controller: _selection,
                        child: BookmarkScrollView(
                          key: ValueKey(scope),
                          scrollController: scroll,
                          searchController: _search,
                          localGroupSelectionController: _selection,
                          view: view!,
                          title: title,
                          leadingSlivers: slivers,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ancestorMenu(BookmarkLibraryState state, String id, String title) {
    final ancestors = state.groupTree.ancestors(id);
    final media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight:
            (media.size.height -
                    media.viewInsets.bottom -
                    media.padding.vertical)
                .clamp(0.0, double.infinity) *
            .6,
      ),
      child: SizedBox(
        width: 280,
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: ancestors.length + 2,
          itemBuilder: (context, index) {
            if (index == 0)
              return KurumiPopupMenuItem(
                title: Text(context.t.sideMenu.home),
                icon: const Icon(Icons.home_outlined),
                onTap: () => _open(null),
              );
            if (index == ancestors.length + 1)
              return KurumiPopupMenuItem(
                title: Text(title),
                trailing: const Icon(Icons.check),
                onTap: null,
              );
            final ancestor = ancestors[index - 1];
            return KurumiPopupMenuItem(
              title: Text(ancestor.displayName(context)),
              onTap: () => _open(ancestor.id),
            );
          },
        ),
      ),
    );
  }

  void _updatePreviewInputs(
    BookmarkLibraryState state, {
    required bool visible,
  }) {
    final inputs = (
      state,
      ref.watch(selectedBookmarkSortTypeProvider),
      ref.watch(bookmarkShuffleProvider),
      visible
          ? ref.watch(bookmarkProfileAvailabilityProvider)
          : _previewInputs?.$4 ?? ref.read(bookmarkProfileAvailabilityProvider),
    );
    final old = _previewInputs;
    if (old == null ||
        !identical(old.$1, state) ||
        old.$2 != inputs.$2 ||
        old.$3 != inputs.$3 ||
        !identical(old.$4, inputs.$4)) {
      _previewInputs = inputs;
      _previews.clear();
      _poolPreviews.clear();
      _nativePreviews.clear();
    }
  }

  Widget _cards(
    BookmarkLibraryState state,
    String? id,
    List<BookmarkGroup> children,
    Set<String> selected,
  ) {
    final published = ref.exists(folderSyncServiceProvider)
        ? ref.watch(folderSyncServiceProvider).valueOrNull?.publishedRoots ??
              const <String>{}
        : const <String>{};
    bool isPublished(BookmarkGroup group) =>
        published.contains(group.id) ||
        state.groupTree
            .ancestors(group.id)
            .any((parent) => published.contains(parent.id));
    final cards = <(String, BookmarkView, BookmarkGroup?)>[
      if (id == null) ...[
        (context.t.bookmark.groups.all, const BookmarkView.all(), null),
        if (state.groupsById[defaultBookmarkGroupId] case final defaultGroup?)
          (
            defaultGroup.displayName(context),
            const BookmarkView.defaultGroup(),
            defaultGroup,
          ),
      ],
      for (final group in children)
        (group.displayName(context), BookmarkView.group(group.id), group),
    ];
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverPadding(
        padding: const EdgeInsets.all(12),
        sliver: SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: switch (constraints.crossAxisExtent) {
              < 500 => 2,
              < 850 => 3,
              _ => 4,
            },
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final (title, view, group) = cards[index];
            final previewView =
                group != null &&
                    group.bookmarkIds.isEmpty &&
                    state.groupTree.childrenOf(group.id).isNotEmpty
                ? BookmarkView.subtree(group.id)
                : view;
            final previewGroups = state.groupIdsForView(previewView);
            final key = view.groupId ?? 'all';
            final preview = _previews.putIfAbsent(
              key,
              () => selectBookmarkPreviews(
                state: state,
                view: previewView,
                sortType: _previewInputs!.$2,
                shuffleState: _previewInputs!.$3,
                availablePostIds: _previewInputs!.$4?.postIds ?? const {},
              ),
            );
            final pools = _poolPreviews.putIfAbsent(
              key,
              () => state.pools
                  .where(
                    (pool) =>
                        (_previewInputs!.$4?.collectionIds.contains(
                              pool.localId,
                            ) ??
                            false) &&
                        pool.groupIds.any(previewGroups.contains),
                  )
                  .take(4)
                  .toList(),
            );
            final editable =
                group != null &&
                !group.isDefault &&
                !state.mirrors.isReceived(group.id);
            final card = BookmarkLocalGroupCard(
              key: ValueKey(('bookmark-card', group?.id ?? 'all')),
              title: title,
              syncActions: group == null || _selection.isActive
                  ? const []
                  : _syncActions(state, group),
              syncIndicator: group != null && state.mirrors.isReceived(group.id)
                  ? Tooltip(
                      message: context.t.folder_sync.received,
                      child: const Icon(
                        Icons.sync_lock,
                        color: Colors.white,
                        size: 20,
                      ),
                    )
                  : group != null && isPublished(group)
                  ? Tooltip(
                      message: context.t.folder_sync.published,
                      child: const Icon(
                        Icons.upload,
                        color: Colors.white,
                        size: 20,
                      ),
                    )
                  : null,
              arrivals: group == null || state.mirrors.owners[group.id] == null
                  ? 0
                  : SyncGroupReadingState.fromJson(
                      state.mirrors.owners[group.id]!.reading,
                    ).arrivals.length,
              hasUnseenChange:
                  group == null || state.mirrors.owners[group.id] == null
                  ? false
                  : SyncGroupReadingState.fromJson(
                      state.mirrors.owners[group.id]!.reading,
                    ).hasUnseenChange,
              previews: preview,
              pools: pools,
              nativeGroups: _nativePreviews.putIfAbsent(
                key,
                () => selectNativeGroupBookmarks(
                  state: state,
                  view: previewView,
                  selectedTags: const [],
                  availableRecordIds:
                      _previewInputs!.$4?.nativeGroupIds ?? const {},
                ).take(4).toList(),
              ),
              group: group,
              selected: group != null && selected.contains(group.id),
              onTap:
                  !editable && (_selection.isActive || selectionModifierPressed)
                  ? null
                  : () {
                      if (editable &&
                          (_selection.isActive || selectionModifierPressed)) {
                        _select(group.id);
                        return;
                      }
                      if (group == null) {
                        goToBookmarkGroupPage(ref, view, title: title);
                      } else {
                        _open(group.id);
                      }
                    },
              onSelect: editable && !_selection.isActive
                  ? () => _select(group.id)
                  : null,
              onRename: editable ? () => _rename(group) : null,
              onMove: editable ? () => _move({group.id}, id) : null,
              onDuplicate: editable ? () => _duplicate([group]) : null,
              onDelete: editable ? () => _delete({group.id}) : null,
            );
            return !editable
                ? card
                : CollectionSelectable(
                    key: ValueKey(group.id),
                    controller: _selection,
                    itemKey: (CollectionSelectionKind.group, group.id),
                    child: card,
                  );
          },
        ),
      ),
    );
  }

  List<Widget> _syncActions(BookmarkLibraryState state, BookmarkGroup group) {
    final owner = state.mirrors.owners[group.id];
    if (owner == null)
      return [
        KurumiPopupMenuItem(
          title: Text(context.t.folder_sync.publish),
          icon: const Icon(Icons.upload),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const FolderSyncPage(section: 'publish'),
            ),
          ),
        ),
      ];
    return [
      KurumiPopupMenuItem(
        title: Text(context.t.folder_sync.copy),
        icon: const Icon(Icons.copy),
        onTap: () => runSyncAction(context, () async {
          await (await ref.read(folderSyncServiceProvider.future))
              .localCopy(group.id);
        }),
      ),
      if (state.mirrors.subscriptions[owner.publisher]?.contains(
            owner.source,
          ) ??
          false)
        KurumiPopupMenuItem(
          title: Text(context.t.folder_sync.unsubscribe),
          icon: const Icon(Icons.link_off),
          onTap: () => runSyncAction(context, () async {
            if (await confirmSyncAction(
              context,
              context.t.folder_sync.unsubscribe,
              syncRemovalMessage(context, state, owner.publisher, owner.source),
            ))
              await (await ref.read(folderSyncServiceProvider.future))
                  .unsubscribe(owner.publisher, owner.source);
          }),
        ),
    ];
  }

  List<Widget> _deviceSlivers(BookmarkLibraryState state) => [
    for (final publisher in state.mirrors.subscriptions.keys) ...[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Expanded(child: Divider()),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  state.mirrors.aliases[publisher] ??
                      state.mirrors.publisherNames[publisher] ??
                      publisher,
                ),
              ),
              IconButton(
                tooltip: context.t.folder_sync.receive,
                icon: const Icon(Icons.more_vert),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FolderSyncPage(section: 'receive'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      _cards(state, publisher, [
        for (final source
            in state.mirrors.subscriptions[publisher] ?? const <String>{})
          if (state.mirrors.localIdFor(publisher, source) case final id?)
            state.groupsById[id]!,
      ], const {}),
    ],
  ];

  Future<void> _setMode(String id, BookmarkGroupViewMode mode) async {
    _selection.disable();
    await _run(
      () => ref
          .read(bookmarkGroupViewPreferencesProvider.notifier)
          .setMode(id, mode),
    );
  }

  Future<void> _create(String? parent) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
    );
    if (name == null || !mounted) return;
    await _run(
      () => ref
          .read(bookmarkProvider.notifier)
          .createGroup(name, parentGroupId: parent),
    );
  }

  Future<void> _rename(BookmarkGroup group) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.rename,
      initialName: group.name,
    );
    if (name == null || !mounted) return;
    await _run(
      () => ref.read(bookmarkProvider.notifier).renameGroup(group.id, name),
    );
  }

  Future<void> _duplicate(List<BookmarkGroup> groups) => _run(
    () => ref.read(bookmarkProvider.notifier).duplicateGroups({
      for (final group in groups)
        group.id: context.t.bookmark.groups.copy_name.replaceAll(
          '{name}',
          group.displayName(context),
        ),
    }, expectedGroups: groups),
  );
  Future<void> _move(Set<String> ids, String? current) async {
    final destination = await showBookmarkGroupDestinationPicker(
      context,
      groups: ref
          .read(bookmarkProvider)
          .requireValue
          .groups
          .where(
            (group) => !ref
                .read(bookmarkProvider)
                .requireValue
                .mirrors
                .isReceived(group.id),
          )
          .toList(),
      movingGroupIds: ids,
      initialParentGroupId: current,
    );
    if (destination == null || !mounted) return;
    await _run(
      () => ref
          .read(bookmarkProvider.notifier)
          .moveGroups(ids, parentGroupId: destination.parentGroupId),
    );
  }

  Future<void> _delete(Set<String> ids) async {
    final notifier = ref.read(bookmarkProvider.notifier);
    try {
      var preview = await notifier.previewDeleteSelection(
        folderIds: const {},
        groupIds: ids,
      );
      while (mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => KurumiDialog(
            semanticLabel: context.t.generic.action.delete,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.t.generic.action.delete,
                    style: Kurumi.themeOf(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  BookmarkCollectionDeletionSummary(
                    folders: 0,
                    groups: preview.groupIds.length,
                    uniqueBookmarks:
                        preview.orphanBookmarkIds.length +
                        preview.orphanPoolIds.length,
                  ),
                  if (preview.snapshot.groups.any(
                    (group) =>
                        ids.contains(group.parentGroupId) &&
                        !ids.contains(group.id),
                  )) ...[
                    const SizedBox(height: 8),
                    Text(context.t.bookmark.groups.deleted_subgroups),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
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
                ],
              ),
            ),
          ),
        );
        if (confirmed != true || !mounted) return;
        try {
          await notifier.deleteSelection(preview);
          if (!mounted) return;
          _selection.disable();
          if (notifier.lastHierarchyDeletion case final receipt?)
            notifier.showHierarchyUndo(context, receipt);
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

  Future<void> _run(Future<Object?> Function() action) async {
    try {
      await action();
      if (mounted) _selection.disable();
    } catch (_) {
      if (mounted)
        Kurumi.showErrorToast(
          context,
          context.t.bookmark.groups.operation_failed,
        );
    }
  }
}
