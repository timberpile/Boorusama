import '../../../backups/mitemite/bookmark_subscription_import.dart';
import '../../../backups/mitemite/bookmark_subscription_progress.dart';
import '../../../backups/mitemite/actions.dart' show isCurrentSyncService;

import '../widgets/bookmark_source_selection_scope.dart';
import '../../../backups/mitemite/collection_alias_ui.dart';
import '../../../backups/mitemite/mitemite_icon.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/rendering.dart'
    show SliverConstraints, SliverGridLayout;
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
import '../../../backups/mitemite/page.dart';
import '../../../backups/mitemite/providers.dart';
import '../../../backups/mitemite/name_dialog.dart';
import '../../../backups/mitemite/seen_state.dart';
import '../../../selection/collection_selection.dart';
import '../../../selection/collection_selection_bar.dart';
import '../../../selection/ordered_selection_canvas.dart';
import '../../../selection/ordered_selection_controller.dart';
import '../../../selection/selection_input.dart';
import '../../../settings/providers.dart';
import '../../../widgets/widgets.dart';
import '../providers/bookmark_group_view_preferences.dart';
import '../providers/bookmark_provider.dart';
import '../providers/bookmark_profile_availability.dart';
import '../routes/route_utils.dart';
import '../services/bookmark_library_service.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_library_state.dart';
import '../types/bookmark_view.dart';
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
  var _normalizing = false;
  final _search = TextEditingController();
  final _selection = OrderedSelectionController<CollectionSelectionKey>();
  final _scrolls = <Object, AutoScrollController>{};
  final _previews = <BookmarkView, List<BookmarkGridEntry>>{};
  (BookmarkLibraryState, BookmarkProfileAvailability?)? _previewInputs;

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

  @override
  Widget build(BuildContext context) {
    final visible = TickerMode.valuesOf(context).enabled;
    final library = visible
        ? ref.watch(bookmarkProvider)
        : (_visibleLibrary ??
              ref.read<AsyncValue<BookmarkLibraryState>>(bookmarkProvider));
    if (visible || _visibleLibrary == null) _visibleLibrary = library;
    final state = library.valueOrNull;
    final id = _currentId(state);
    final importing = id == null && visible
        ? ref.watch(bookmarkSubscriptionImportsProvider).values
        : const <BookmarkSubscriptionImport>[];
    final group = state?.groupsById[id];
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
          if (!(state?.mirrors.isReceived(child.id) ?? false))
            (CollectionSelectionKind.group, child.id),
    ], scope: scope);
    final selected = {
      for (final (_, selectedId) in _selection.selectedKeys) selectedId,
    };
    if (state != null && state.mirrors.owners.isNotEmpty) {
      ref.watch(syncCollectionAliasesProvider);
    }
    final title = group == null
        ? context.t.bookmark.groups.selector
        : _groupLabel(state!, group);
    void up() => _open(group?.parentGroupId);

    final hasTimeline =
        view != null &&
        library.when(
          loading: () => false,
          error: (_, _) => false,
          data: (state) =>
              state.bookmarkIdsForView(view).isNotEmpty ||
              (!state.hasUnifiedRecords &&
                  state.pools.any((pool) => pool.groupIds.contains(id))),
        );
    final floatAppBar =
        hasTimeline &&
        // Keep group navigation reachable above the on-screen keyboard.
        MediaQuery.viewInsetsOf(context).bottom == 0 &&
        !ref.watch(
          imageListingSettingsProvider.select(
            (settings) => settings.keepTimelineToolbarVisible,
          ),
        );
    final appBar = KurumiAppBar(
      leading: id == null ? null : BackButton(onPressed: up),
      title: id == null || state == null
          ? Text(title)
          : KurumiPopupMenuButton(
              semanticLabel: context.t.bookmark.groups.choose_ancestor,
              maxWidth: 280,
              items: [_ancestorMenu(state, id, title)],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: KurumiFittedText(Text(title))),
                  if (state.mirrors.isReceived(id)) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: context.t.mitemite.received_group,
                      child: const MiteMiteIcon(
                        size: 18,
                      ),
                    ),
                  ] else if (ref
                      .watch(publishedBookmarkRootsProvider)
                      .contains(id)) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: context.t.mitemite.published,
                      child: const MiteMiteIcon(size: 18),
                    ),
                  ],
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
            if (group != null && state != null) ..._syncActions(state, group),
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
    );

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
                appBar: floatAppBar ? null : appBar,
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
                      final genuinelyEmpty = view != null && !hasTimeline;
                      final cards = _cards(
                        state,
                        id,
                        ordinaryChildren,
                        selected,
                      );
                      final slivers = <Widget>[
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
                        final empty = OrderedSelectionCanvas(
                          controller: _selection,
                          child: CustomScrollView(
                            key: PageStorageKey(scope),
                            controller: scroll,
                            slivers: [
                              ...slivers,
                              if (id == null)
                                ..._deviceSlivers(state, importing),
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
                        return view == null
                            ? empty
                            : BookmarkSourceSelectionScope(
                                view: view,
                                child: empty,
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
                          floatingAppBar: floatAppBar ? appBar : null,
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
            if (index == 0) {
              return KurumiPopupMenuItem(
                title: Text(context.t.sideMenu.home),
                icon: const Icon(Icons.home_outlined),
                onTap: () => _open(null),
              );
            }
            if (index == ancestors.length + 1) {
              return KurumiPopupMenuItem(
                title: Text(title),
                trailing: const Icon(Icons.check),
                onTap: null,
              );
            }
            final ancestor = ancestors[index - 1];
            return KurumiPopupMenuItem(
              title: Text(_groupLabel(state, ancestor)),
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
      visible
          ? ref.watch(bookmarkProfileAvailabilityProvider)
          : _previewInputs?.$2 ?? ref.read(bookmarkProfileAvailabilityProvider),
    );
    final old = _previewInputs;
    if (old == null ||
        !identical(old.$1, state) ||
        !identical(old.$2, inputs.$2)) {
      _previewInputs = inputs;
      _previews.clear();
    }
  }

  Widget _cards(
    BookmarkLibraryState state,
    String? id,
    List<BookmarkGroup> children,
    Set<String> selected,
  ) {
    final published = ref.watch(publishedBookmarkRootsProvider);
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
        (_groupLabel(state, group), BookmarkView.group(group.id), group),
    ];
    return SliverPadding(
      padding: _BookmarkFolderGridDelegate.padding,
      sliver: SliverGrid.builder(
        gridDelegate: const _BookmarkFolderGridDelegate(),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final (title, view, group) = cards[index];
          final previewView =
              group != null &&
                  group.bookmarkIds.isEmpty &&
                  state.groupTree.childrenOf(group.id).isNotEmpty
              ? BookmarkView.subtree(group.id)
              : view;
          final availability = _previewInputs!.$2;
          final previews = _previews.putIfAbsent(
            previewView,
            () => selectBookmarkMosaicEntries(
              state: state,
              view: previewView,
              availablePostIds: availability?.postIds ?? const {},
              availableCollectionIds: availability?.collectionIds ?? const {},
              availableNativeGroupIds: availability?.nativeGroupIds ?? const {},
            ),
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
            readOnly: group != null && state.mirrors.isReceived(group.id),
            syncIndicator:
                group != null &&
                    published.contains(group.id) &&
                    !state.mirrors.isReceived(group.id)
                ? Tooltip(
                    message: context.t.mitemite.published,
                    child: const MiteMiteIcon(color: Colors.white, size: 20),
                  )
                : null,
            unseenCount: group == null
                ? 0
                : syncBookmarkUnseenMembers(state, group.id).length,
            mosaicCandidates: previews,
            selected: group != null && selected.contains(group.id),
            onTap: !editable && _selection.isActive
                ? null
                : () {
                    if (_selection.isActive || selectionModifierPressed) {
                      if (editable) _select(group.id);
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
    );
  }

  String _groupLabel(BookmarkLibraryState state, BookmarkGroup group) {
    final source = bookmarkAliasSource(state.mirrors, group.id);
    return source == null
        ? group.displayName(context)
        : ref.read(syncCollectionAliasesProvider)[source] ??
              group.displayName(context);
  }

  List<Widget> _syncActions(BookmarkLibraryState state, BookmarkGroup group) {
    final owner = state.mirrors.owners[group.id];
    if (owner == null) {
      final direct = ref
          .watch(publishedBookmarkRootsProvider)
          .contains(group.id);
      return [
        KurumiPopupMenuItem(
          title: Text(
            direct
                ? context.t.mitemite.manage_publication
                : context.t.mitemite.publish,
          ),
          icon: const MiteMiteIcon(),
          onTap: direct
              ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MiteMitePage(section: 'publish'),
                  ),
                )
              : () => publishBookmarkGroup(context, ref, group.id),
        ),
      ];
    }
    return [
      ...collectionAliasMenu(
        context,
        ref,
        id: bookmarkAliasSource(state.mirrors, group.id)!,
        sourceName: group.name,
      ),
      KurumiPopupMenuItem(
        title: Text(context.t.mitemite.copy),
        icon: const Icon(Icons.copy),
        onTap: () => runSyncAction(context, () async {
          final service = await ref.read(miteMiteServiceProvider.future);
          if (!mounted || !isCurrentSyncService(context, service)) return;
          await service.localCopy(group.id);
          if (mounted) {
            Kurumi.showSuccessToast(
              context,
              context.t.mitemite.local_copy_created,
            );
          }
        }),
      ),
      if (state.mirrors.subscriptions[owner.publisher]?.contains(
            owner.source,
          ) ??
          false)
        KurumiPopupMenuItem(
          title: Text(context.t.mitemite.unsubscribe),
          icon: const Icon(Icons.link_off),
          onTap: () => runSyncAction(context, () async {
            if (await confirmSyncAction(
                  context,
                  context.t.mitemite.unsubscribe,
                  syncRemovalMessage(
                    context,
                    state,
                    owner.publisher,
                    owner.source,
                  ),
                ) &&
                mounted) {
              final service = await ref.read(miteMiteServiceProvider.future);
              if (!mounted || !isCurrentSyncService(context, service)) return;
              await service.unsubscribe(owner.publisher, owner.source);
            }
          }),
        ),
    ];
  }

  List<Widget> _deviceSlivers(
    BookmarkLibraryState state,
    Iterable<BookmarkSubscriptionImport> imports,
  ) {
    final pending = <String, List<BookmarkSubscriptionImport>>{};
    for (final operation in imports) {
      final collection = operation.collection;
      final subscribed =
          state.mirrors.subscriptions[collection.publisher]?.contains(
            collection.source,
          ) ??
          false;
      final local = state.mirrors.localIdFor(
        collection.publisher,
        collection.source,
      );
      if (!subscribed || !state.groupsById.containsKey(local)) {
        pending.putIfAbsent(collection.publisher, () => []).add(operation);
      }
    }
    return [
      for (final publisher in {
        ...state.mirrors.subscriptions.keys,
        ...pending.keys,
      }) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  const MiteMiteIcon(size: 20),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          (constraints.maxWidth - 92).clamp(
                            0,
                            double.infinity,
                          ) *
                          .75,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        state.mirrors.aliases[publisher] ??
                            state.mirrors.publisherNames[publisher] ??
                            pending[publisher]?.first.publisherName ??
                            publisher,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Divider()),
                  const SizedBox(width: 8),
                  if (state.mirrors.subscriptions.containsKey(publisher))
                    IconButton(
                      key: ValueKey(('bookmark-device-edit', publisher)),
                      tooltip: context.t.generic.action.edit,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => runSyncAction(context, () async {
                        final service = await ref.read(
                          miteMiteServiceProvider.future,
                        );
                        if (context.mounted) {
                          await editSyncDeviceAlias(
                            context,
                            service: service,
                            publisher: publisher,
                            alias: state.mirrors.aliases[publisher],
                          );
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
        ),
        _cards(state, publisher, [
          for (final source
              in state.mirrors.subscriptions[publisher] ?? const <String>{})
            if (state.mirrors.localIdFor(publisher, source) case final id?)
              ?state.groupsById[id],
        ], const {}),
        for (final operation
            in pending[publisher] ?? const <BookmarkSubscriptionImport>[])
          SliverToBoxAdapter(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                key: ValueKey(('bookmark-import', operation.collection.key)),
                leading: const MiteMiteIcon(),
                title: Text(operation.name),
                subtitle: BookmarkSubscriptionProgress(operation: operation),
              ),
            ),
          ),
      ],
    ];
  }

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
      while (true) {
        if (!mounted) return;
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
          if (notifier.lastHierarchyDeletion case final receipt?) {
            notifier.showHierarchyUndo(context, receipt);
          }
          return;
        } on BookmarkCollectionChangedException catch (error) {
          preview = error.preview;
        }
      }
    } catch (_) {
      if (mounted) {
        Kurumi.showErrorToast(
          context,
          context.t.bookmark.groups.operation_failed,
        );
      }
    }
  }

  Future<void> _run(Future<Object?> Function() action) async {
    try {
      await action();
      if (mounted) _selection.disable();
    } catch (_) {
      if (mounted) {
        Kurumi.showErrorToast(
          context,
          context.t.bookmark.groups.operation_failed,
        );
      }
    }
  }
}

class _BookmarkFolderGridDelegate extends SliverGridDelegate {
  const _BookmarkFolderGridDelegate();

  static const padding = EdgeInsets.all(12);

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    // Use the viewport width before padding to keep the existing breakpoints.
    final viewportWidth = constraints.crossAxisExtent + padding.horizontal;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: switch (viewportWidth) {
        < 500 => 2,
        < 850 => 3,
        _ => 4,
      },
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    ).getLayout(constraints);
  }

  @override
  bool shouldRelayout(_BookmarkFolderGridDelegate oldDelegate) => false;
}
