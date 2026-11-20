import '../providers/following_topic_config_provider.dart';
import '../../../../backups/mitemite/name_dialog.dart';
import '../../../../backups/mitemite/page.dart';
import '../../../../backups/mitemite/collection_alias_ui.dart';
import '../../../../backups/mitemite/mitemite_icon.dart';
import '../types/following_topic_repository.dart';

import 'package:flutter/foundation.dart';

import '../../../../selection/collection_selection_bar.dart';
import '../../../../widgets/multi_select_button.dart';
import '../../../../selection/ordered_selection_canvas.dart';

import 'package:flutter/services.dart';

import '../../../../selection/collection_selection.dart';
import '../../../../selection/ordered_selection_controller.dart';
import '../../../../selection/selection_input.dart';
import '../../../../navigation/navigation_interaction_scopes.dart';
import '../../../../navigation/destination_profile_scope.dart';
import '../../../../router.dart';
import '../../../../errors/types.dart';

import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../groups/folder_tree.dart';
import '../../../../backups/mitemite/providers.dart';
import '../../../../backups/mitemite/following_actions.dart';
import '../types/following_mirror_state.dart';
import '../../../search/routes.dart';
import '../../../search/src/widgets/booru_search_bar.dart';
import '../../../selected_tags/types.dart';
import '../data/providers.dart';
import '../providers/following_topic_selectors.dart';
import '../providers/following_topics_notifier.dart';
import '../providers/following_topic_sort_provider.dart';
import '../types/following_topic_sort.dart';
import '../types/topic_organization.dart';
import '../../../../groups/folder_navigation.dart';
import '../types/following_topic.dart';
import '../types/search_refresh.dart';
import '../widgets/bulk_search_import_dialog.dart';
import '../widgets/move_topic_to_folder_dialog.dart';
import '../widgets/edit_following_topic_dialog.dart';
import '../widgets/following_topic_card.dart';
import '../widgets/following_topic_profile_caption.dart';
import '../widgets/following_topic_folder_card.dart';
import '../widgets/search_folder_dialog.dart';
import '../widgets/following_topic_info_dialog.dart';
import '../widgets/topic_follow_control.dart';
import '../widgets/follow_button_shape.dart';
import 'topic_feeds_page.dart';

enum _FollowingTopicPageAction {
  bulkAdd,
  createFolder,
  folderSettings,
  refresh,
}

class FollowingTopicsPage extends ConsumerStatefulWidget {
  const FollowingTopicsPage({this.folderId, super.key})
    : _ancestorRoutes = const {};
  const FollowingTopicsPage._nested({
    required this.folderId,
    required Map<String?, Route<dynamic>> ancestorRoutes,
  }) : _ancestorRoutes = ancestorRoutes;
  final Map<String?, Route<dynamic>> _ancestorRoutes;

  final String? folderId;

  @override
  ConsumerState<FollowingTopicsPage> createState() =>
      _FollowingTopicsPageState();
}

class _FollowingTopicsPageState extends ConsumerState<FollowingTopicsPage> {
  @override
  void initState() {
    super.initState();
    _selection.addListener(_selectionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.folderId == null) {
        unawaited(
          ref
              .read(followingTopicsProvider.notifier)
              .initializeUnifiedFollowing()
              .catchError((_) {
                if (mounted) {
                  Kurumi.showErrorToast(
                    context,
                    context.t.following_topics.operation_failed,
                  );
                }
              }),
        );
      }
    });
  }

  // Imports or another browser can remove the open folder. Fall back to Home.
  String? get _folderId {
    final id = widget.folderId;
    final folders = ref
        .read(followingTopicsProvider)
        .valueOrNull
        ?.organization
        .folders;
    return (folders?.any((f) => f.id == id) ?? false) ? id : null;
  }

  final _openingIds = <String>{};
  final _selection = OrderedSelectionController<CollectionSelectionKey>();
  final _scroll = ScrollController();
  Object? _bodyInputs;
  Set<String> _bodyRefreshable = const {};
  Widget? _cachedBody;
  Set<String> get _selectedFolders => {
    for (final (kind, id) in _selection.selectedKeys)
      if (kind == CollectionSelectionKind.folder) id,
  };
  Set<String> get _selectedSearches => {
    for (final (kind, id) in _selection.selectedKeys)
      if (kind == CollectionSelectionKind.topic) id,
  };
  bool get _selecting => _selection.isActive;
  void _selectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _selection.removeListener(_selectionChanged);
    _selection.dispose();
    _scroll.dispose();
    super.dispose();
  }

  var _filterQuery = '';
  String? _filterProfileId;
  var _filterVisible = false;
  void _clearSelection() => _selection.disable();

  Set<String> _selectedTopicIds(FollowingTopicsState state) => {
    ..._selectedSearches.where(
      state.topics.map((topic) => topic.id).toSet().contains,
    ),
    for (final folderId in _selectedFolders)
      ...state.organization.folders.any((folder) => folder.id == folderId)
          ? state.organization.recursiveIds(folderId)
          : const <String>[],
  };
  void _select(String id, {bool folder = false}) {
    if (ref.read(followingTopicsProvider).valueOrNull?.mirrors.isReceived(id) ??
        false)
      return;
    final index = _selection.indexOf((
      folder ? CollectionSelectionKind.folder : CollectionSelectionKind.topic,
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
    if (DestinationScope.maybeOf(context) != null) {
      final organization = ref
          .read(followingTopicsProvider)
          .valueOrNull
          ?.organization;
      final ancestors = <String?>{null};
      var parent = organization?.folders
          .where((f) => f.id == _folderId)
          .firstOrNull
          ?.parentId;
      while (parent != null && ancestors.add(parent)) {
        parent = organization?.folders
            .where((f) => f.id == parent)
            .firstOrNull
            ?.parentId;
      }
      if (ancestors.contains(id)) {
        var found = false;
        navigator.popUntil((route) {
          found = id == null
              ? route.isFirst
              : route.settings.name == 'following-folder:$id';
          return found || route.isFirst;
        });
        if (found) return;
      }
      if (id != null)
        unawaited(
          ref.pushNamedRoute<void>(
            '/following-topics/folder',
            pathParameters: {'folderId': id},
          ),
        );
      return;
    }
    final previous = widget._ancestorRoutes[id];
    if (previous != null) {
      navigator.popUntil((route) => route == previous);
      return;
    }
    final currentRoute = ModalRoute.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => FollowingTopicsPage._nested(
          folderId: id,
          ancestorRoutes: {
            ...widget._ancestorRoutes,
            _folderId: ?currentRoute,
          },
        ),
      ),
    );
  }

  Future<void> _moveSelected({
    Set<String>? folderIds,
    Set<String>? searchIds,
  }) async {
    final foldersToMove = {...(folderIds ?? _selectedFolders)};
    final topicsToMove = {...(searchIds ?? _selectedSearches)};
    final choice = await showFolderDestinationPicker(
      context,
      folders: ref
          .read(followingTopicsProvider)
          .requireValue
          .organization
          .folders,
      movingFolderIds: foldersToMove,
    );
    if (choice == null || !mounted) return;
    final moved = await _runAction(
      () => ref
          .read(followingTopicsProvider.notifier)
          .moveFolderItems(
            folderIds: foldersToMove,
            searchIds: topicsToMove,
            destination: choice.folderId,
          ),
    );
    if (mounted && moved) _clearSelection();
  }

  var _refreshingAllProfiles = false;

  @override
  Widget build(BuildContext context) {
    final eligibleProfiles = ref
        .watch(orderedProfileConfigsProvider)
        .where(
          (c) => ref.watch(followingTopicTrackingSupportedProvider(c.auth)),
        )
        .map((c) => c.id)
        .toList();
    final refreshableProfileIds = eligibleProfiles.toSet();
    final activity = ref.watch(followingTopicsProvider).valueOrNull;
    for (final topic in activity?.topics ?? const <FollowingTopic>[]) {
      if (!(activity?.mirrors.isReceived(topic.id) ?? false) &&
          topic.localSource == null)
        continue;
      final config = ref.watch(followingTopicConfigProvider(topic.id));
      if (config != null &&
          ref.watch(followingTopicTrackingSupportedProvider(config.auth))) {
        refreshableProfileIds.add(topic.profileId);
        if (!eligibleProfiles.contains(topic.profileId))
          eligibleProfiles.add(topic.profileId);
      }
    }

    final strings = context.t.following_topics;
    final readOnlyFolder =
        activity?.mirrors.isReceived(_folderId ?? '') ?? false;
    final directFolder = activity?.organization.folders
        .where((folder) => folder.id == _folderId)
        .firstOrNull;
    final folder = directFolder == null
        ? null
        : TopicFolder(
            id: directFolder.id,
            name: directFolder.name,
            feedEnabled: directFolder.feedEnabled,
            feedMaxPosts: directFolder.feedMaxPosts,
            searchIds: activity!.organization.recursiveIds(directFolder.id),
          );
    final batchRunning =
        (activity?.batchCompleted ?? 0) < (activity?.batchTotal ?? 0);
    final canRefreshAll =
        !_refreshingAllProfiles &&
        !batchRunning &&
        (activity?.topics.any(
              (topic) =>
                  !activity.feeds.any(
                    (feed) =>
                        !activity.organization.folders.any(
                          (folder) => folder.id == feed.id,
                        ) &&
                        feed.sourceIds.contains(topic.id),
                  ) &&
                  eligibleProfiles.contains(topic.profileId),
            ) ??
            false);
    final canRefreshFolder = canRefreshFollowingTopicFolder(
      folder: folder,
      topics: activity?.topics ?? const <FollowingTopic>[],
      refreshingIds: activity?.pendingRefreshIds ?? const <String>{},
      refreshableProfileIds: refreshableProfileIds,
    );
    final selectedTopicIds = activity == null
        ? const <String>{}
        : _selectedTopicIds(activity);
    return CollectionSelection(
      controller: _selection,
      scrollController: _scroll,
      child: NavigationSelectionBridge(
        controller: _selection,
        selected: _selecting,
        child: PopScope(
          canPop: true,
          child: Scaffold(
            appBar: KurumiAppBar(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      folder == null
                          ? strings.page_title
                          : followingAliasLabel(
                              folder.name,
                              folder.id,
                              activity!.mirrors,
                              followingAliasSource(
                                        activity.mirrors,
                                        folder.id,
                                      ) ==
                                      null
                                  ? const {}
                                  : ref.watch(syncCollectionAliasesProvider),
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (readOnlyFolder)
                    FollowingSyncStatus(
                      readOnly: true,
                      published: false,
                      changed:
                          activity != null &&
                          unseenFollowingTopicDefinitions(
                            activity.mirrors,
                            activity.organization,
                            directFolder!.id,
                          ).isNotEmpty,
                    ),
                ],
              ),
              actions: [
                ...[
                  IconButton(
                    tooltip: context.t.generic.action.search,
                    icon: const Icon(Symbols.search),
                    onPressed: () => setState(() {
                      _filterVisible = !_filterVisible;
                      if (!_filterVisible) {
                        _filterQuery = '';
                        _filterProfileId = null;
                      }
                    }),
                  ),
                  if (directFolder?.feedEnabled ?? false)
                    IconButton(
                      tooltip: strings.open_feed,
                      icon: const Icon(Symbols.rss_feed),
                      onPressed: () => _openFolderFeed(directFolder!.id),
                    ),
                  if (!readOnlyFolder)
                    KurumiPopupMenuButton(
                      tooltip: context.t.sort.sort_by,
                      semanticLabel: context.t.sort.sort_by,
                      icon: const Icon(Symbols.sort),
                      iconPadding: const EdgeInsets.all(12),
                      items: [
                        for (final (sort, icon, label) in [
                          (
                            FollowingTopicSort.manual,
                            Icons.drag_handle,
                            strings.sort_manual,
                          ),
                          (
                            FollowingTopicSort.nameAsc,
                            Icons.sort_by_alpha,
                            context.t.sort.name,
                          ),
                          (
                            FollowingTopicSort.updatesFirst,
                            Icons.new_releases_outlined,
                            strings.sort_unread_first,
                          ),
                          (
                            FollowingTopicSort.addedNewest,
                            Icons.arrow_downward,
                            strings.sort_recently_added,
                          ),
                        ])
                          KurumiPopupMenuItem(
                            title: Text(label),
                            icon: Icon(icon),
                            trailing:
                                ref.watch(followingTopicSortProvider) == sort
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () => ref
                                .read(followingTopicSortProvider.notifier)
                                .select(sort),
                          ),
                      ],
                    ),
                  KurumiPopupMenuButton(
                    tooltip: context.t.generic.action.more,
                    icon: const Icon(Icons.more_vert),
                    semanticLabel: context.t.generic.action.more,
                    iconPadding: const EdgeInsets.all(12),
                    items: [
                      if (directFolder != null && activity != null)
                        ...followingSyncMenu(
                          context,
                          ref,
                          activity,
                          directFolder.id,
                        ),
                      if (!readOnlyFolder) ...[
                        KurumiPopupMenuItem(
                          title: Text(strings.bulk_add),
                          icon: const Icon(Icons.playlist_add),
                          onTap:
                              ref.watch(orderedProfileConfigsProvider).isEmpty
                              ? null
                              : () => _onPageAction(
                                  _FollowingTopicPageAction.bulkAdd,
                                  eligibleProfiles: eligibleProfiles,
                                ),
                        ),
                        KurumiPopupMenuItem(
                          title: Text(strings.create_folder),
                          icon: const Icon(Icons.create_new_folder_outlined),
                          onTap: () => _onPageAction(
                            _FollowingTopicPageAction.createFolder,
                            eligibleProfiles: eligibleProfiles,
                          ),
                        ),
                        if (directFolder != null)
                          KurumiPopupMenuItem(
                            title: Text(strings.edit_folder),
                            icon: const Icon(Icons.tune),
                            onTap: () => _onPageAction(
                              _FollowingTopicPageAction.folderSettings,
                              eligibleProfiles: eligibleProfiles,
                            ),
                          ),
                      ],
                      KurumiPopupMenuItem(
                        title: Text(
                          _folderId == null
                              ? strings.refresh_all
                              : strings.refresh_folder,
                        ),
                        icon: const Icon(Icons.refresh),
                        onTap:
                            (_folderId == null
                                ? canRefreshAll
                                : canRefreshFolder)
                            ? () => _onPageAction(
                                _FollowingTopicPageAction.refresh,
                                eligibleProfiles: eligibleProfiles,
                              )
                            : null,
                      ),
                    ],
                  ),
                ],
              ],
            ),
            bottomNavigationBar: _selecting && activity != null
                ? CollectionSelectionBar(
                    controller: _selection,
                    actions: _selectionActions(activity, refreshableProfileIds),
                  )
                : null,
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  if (_selecting &&
                      selectedTopicIds.length !=
                          _selectedFolders.length + _selectedSearches.length)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Text(
                        strings.selection_scope
                            .replaceAll(
                              '{selected}',
                              '${_selectedFolders.length + _selectedSearches.length}',
                            )
                            .replaceAll(
                              '{topics}',
                              '${selectedTopicIds.length}',
                            ),
                      ),
                    ),
                  Expanded(child: _allProfilesBody(refreshableProfileIds)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _selectionActions(
    FollowingTopicsState state,
    Set<String> refreshableProfiles,
  ) {
    final folderIds = _selectedFolders;
    final topicIds = _selectedSearches;
    final count = folderIds.length + topicIds.length;
    if (count == 0) return const [];
    final targets = _selectedTopicIds(state);
    final topics = state.topics
        .where((topic) => targets.contains(topic.id))
        .toList();
    final canRefresh =
        topics.length == targets.length &&
        topics
            .where((t) => topicIds.contains(t.id))
            .every((t) => refreshableProfiles.contains(t.profileId)) &&
        folderIds.every(
          (id) => canRefreshFollowingTopicFolder(
            folder: TopicFolder(
              id: id,
              name: '',
              searchIds: state.organization.recursiveIds(id),
            ),
            topics: state.topics,
            refreshingIds: const {},
            refreshableProfileIds: refreshableProfiles,
          ),
        );
    final manualOrder =
        ref.read(followingTopicSortProvider) == FollowingTopicSort.manual &&
        _filterQuery.trim().isEmpty &&
        _filterProfileId == null;
    final sameKind = folderIds.isEmpty || topicIds.isEmpty;
    final order = folderIds.isNotEmpty
        ? (state.organization.folders
                  .where(
                    (f) =>
                        f.parentId == _folderId &&
                        !state.mirrors.isReceived(f.id),
                  )
                  .toList()
                ..sort((a, b) {
                  final p = a.position.compareTo(b.position);
                  return p == 0 ? a.id.compareTo(b.id) : p;
                }))
              .map((f) => f.id)
              .toList()
        : ref
                  .read(visibleFollowingTopicsProvider(_folderId))
                  .valueOrNull
                  ?.where((t) => !state.mirrors.isReceived(t.id))
                  .map((t) => t.id)
                  .toList() ??
              <String>[];
    final selected = {...folderIds, ...topicIds};
    final allInOrder = order.toSet().containsAll(selected);
    return [
      MultiSelectButton(
        primary: true,
        name: context.t.folders.move,
        icon: const Icon(Icons.drive_file_move_outline),
        onPressed: () =>
            _moveSelected(folderIds: folderIds, searchIds: topicIds),
      ),
      if (canRefresh)
        MultiSelectButton(
          name: context.t.following_topics.refresh,
          icon: const Icon(Icons.refresh),
          onPressed: topics.any((t) => state.pendingRefreshIds.contains(t.id))
              ? null
              : () => _refreshSelected(targets),
        ),
      if (topics.any((t) => t.hasNewPosts))
        MultiSelectButton(
          primary: true,
          name: context.t.following_topics.mark_read,
          icon: const Icon(Icons.done_all),
          onPressed: () => _runSelectedAction(
            () => ref
                .read(followingTopicsProvider.notifier)
                .markTopicsRead(targets),
            clearSelection: true,
          ),
        ),
      if (manualOrder && sameKind && allInOrder && order.isNotEmpty) ...[
        MultiSelectButton(
          menuOnly: true,
          name: context.t.following_topics.move_up,
          icon: const Icon(Icons.arrow_upward),
          onPressed: selected.contains(order.first)
              ? null
              : () => _reorderSelected(state, order, down: false),
        ),
        MultiSelectButton(
          menuOnly: true,
          name: context.t.following_topics.move_down,
          icon: const Icon(Icons.arrow_downward),
          onPressed: selected.contains(order.last)
              ? null
              : () => _reorderSelected(state, order, down: true),
        ),
      ],
      MultiSelectButton(
        primary: true,
        name: context.t.following_topics.remove_selection,
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _removeSelected(state),
      ),
    ];
  }

  Future<void> _reorderSelected(
    FollowingTopicsState state,
    List<String> order, {
    required bool down,
  }) async {
    final folderIds = _selectedFolders;
    final selected = {...folderIds, ..._selectedSearches};
    var expected = state.organization;
    final indices = [
      for (var i = 0; i < order.length; i++)
        if (selected.contains(order[i])) i,
    ];
    final moves = down ? indices.reversed : indices;
    await _runSelectedAction(() async {
      final notifier = ref.read(followingTopicsProvider.notifier);
      for (final index in moves) {
        if (ref.read(followingTopicsProvider).requireValue.organization !=
            expected)
          throw StateError('Topic organization changed');
        if (folderIds.isNotEmpty) {
          await notifier.reorderSharedFolders(
            index,
            index + (down ? 1 : -1),
            parentId: _folderId,
          );
        } else {
          await notifier.reorderSharedTopics(
            _folderId,
            index,
            index + (down ? 1 : -1),
          );
        }
        expected = ref.read(followingTopicsProvider).requireValue.organization;
      }
      return null;
    });
  }

  Future<void> _runSelectedAction(
    Future<Object?> Function() action, {
    bool clearSelection = false,
  }) async {
    final succeeded = await _runAction(action);
    if (mounted && succeeded && clearSelection) _clearSelection();
  }

  Future<void> _refreshSelected(Set<String> ids) => _runSelectedAction(
    () => ref.read(followingTopicsProvider.notifier).refreshTopics(ids),
  );

  Future<void> _removeSelected(FollowingTopicsState state) async {
    final folderIds = {..._selectedFolders};
    final topicIds = {..._selectedSearches};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.following_topics.remove_selected_title),
        content: Text(context.t.following_topics.remove_selected_message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t.generic.action.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t.following_topics.remove_selection),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && mounted) {
      await _runSelectedAction(
        () => ref
            .read(followingTopicsProvider.notifier)
            .removeSelection(
              folderIds: folderIds,
              topicIds: topicIds,
              expectedOrganization: state.organization,
            ),
        clearSelection: true,
      );
    }
  }

  Future<void> _onPageAction(
    _FollowingTopicPageAction action, {
    required List<String> eligibleProfiles,
  }) async {
    switch (action) {
      case _FollowingTopicPageAction.bulkAdd:
        await _bulkAdd();
      case _FollowingTopicPageAction.createFolder:
        await _createFolder();
      case _FollowingTopicPageAction.folderSettings:
        final folder = ref
            .read(followingTopicsProvider)
            .valueOrNull
            ?.organization
            .folders
            .where((folder) => folder.id == _folderId)
            .firstOrNull;
        if (folder != null) {
          await _editFolderSettings(folder);
        }
      case _FollowingTopicPageAction.refresh:
        if (_folderId case final folderId?) {
          await _runAction(
            () => ref
                .read(followingTopicsProvider.notifier)
                .refreshSharedFolder(folderId),
          );
        } else {
          await _refreshProfiles(eligibleProfiles);
        }
    }
  }

  Future<void> _createFolder() async {
    final organization = (await ref.read(
      followingTopicsProvider.future,
    )).organization;
    if (!mounted) return;
    final options = await showSearchFolderSettingsDialog(
      context,
      folders: organization.folders,
      parentId: _folderId,
    );
    if (options == null || !mounted) return;
    await _runAction(
      () => ref
          .read(followingTopicsProvider.notifier)
          .createSharedFolder(
            options.name,
            parentId: options.parentId,
            feedEnabled: options.feedEnabled,
            feedMaxPosts: options.maxPosts,
          ),
    );
  }

  Future<void> _editFolderSettings(TopicFolder folder) async {
    final organization = ref
        .read(followingTopicsProvider)
        .valueOrNull
        ?.organization;
    if (organization == null) return;
    final options = await showSearchFolderSettingsDialog(
      context,
      name: folder.name,
      folders: organization.folders,
      parentId: folder.parentId,
      editingFolderId: folder.id,
      feedEnabled: folder.feedEnabled,
      maxPosts: folder.feedMaxPosts,
    );
    if (options == null || !mounted) return;
    await _runAction(
      () => ref
          .read(followingTopicsProvider.notifier)
          .renameSharedFolder(
            folder.id,
            options.name,
            parentId: options.parentId,
            feedEnabled: options.feedEnabled,
            maxPosts: options.maxPosts,
          ),
    );
  }

  Future<void> _openFolderFeed(String folderId) async {
    try {
      final feed = await ref
          .read(followingTopicsProvider.notifier)
          .openFolderFeed(folderId);
      if (!mounted) return;
      if (feed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.following_topics.feed_posts_empty)),
        );
        return;
      }
      if (DestinationScope.maybeOf(context) != null) {
        await ref.pushNamedRoute<void>(
          '/following-topics/feed',
          pathParameters: {'feedId': feed.id},
          queryParameters: {'_profile': feed.profileId},
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TopicFeedPage(
              feedId: feed.id,
              profileId: feed.profileId,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        Kurumi.showErrorToast(
          context,
          context.t.following_topics.feed_operation_failed,
        );
      }
    }
  }

  Future<void> _bulkAdd() async {
    final configs = ref.read(booruConfigProvider);
    final profiles = configs;
    final folder = ref
        .read(followingTopicsProvider)
        .valueOrNull
        ?.organization
        .folders
        .where((item) => item.id == _folderId)
        .firstOrNull;
    final count = await showBulkSearchImportDialog(
      context,
      destination: folder?.name ?? context.t.following_topics.home,
      profiles: profiles,
      initialProfileId: ref.readConfig.id,
      onAdd: (profileId, queries) => ref
          .read(followingTopicsProvider.notifier)
          .bulkFollowToFolder(
            profileId: profileId!,
            folderId: _folderId,
            rawQueries: queries,
          ),
    );
    if (count == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t.following_topics.bulk_added.replaceAll('{count}', '$count'),
        ),
      ),
    );
  }

  Widget _allProfilesBody(Set<String> refreshableProfileIds) {
    final strings = context.t.following_topics;
    final profiles = ref.watch(orderedProfileConfigsProvider);
    final activity = ref.watch(followingTopicsProvider).valueOrNull;
    final visible = ref.watch(organizedFollowingTopicsProvider(_folderId));
    final published = ref.watch(publishedFollowingRootsProvider);
    final syncRevision = ref.exists(miteMiteServiceProvider)
        ? ref.watch(followingSyncPresentationProvider)
        : 0;
    final selectedSort = ref.watch(followingTopicSortProvider);
    final inputs = (
      profiles,
      activity,
      visible,
      selectedSort,
      _folderId,
      _filterQuery,
      _filterProfileId,
      _filterVisible,
      _openingIds.length,
      published,
      syncRevision,
      (activity?.mirrors.owners.isNotEmpty ?? false)
          ? ref.watch(syncCollectionAliasesProvider)
          : const {},
    );
    if (_bodyInputs == inputs &&
        setEquals(_bodyRefreshable, refreshableProfileIds) &&
        _cachedBody != null)
      return _cachedBody!;
    _bodyInputs = inputs;
    _bodyRefreshable = {...refreshableProfileIds};
    final profilesById = {for (final profile in profiles) profile.id: profile};
    final topicsById = {
      for (final topic in activity?.topics ?? const <FollowingTopic>[])
        topic.id: topic,
    };
    final canReorder =
        ref.watch(followingTopicSortProvider) == FollowingTopicSort.manual;
    final filtering =
        _filterQuery.trim().isNotEmpty || _filterProfileId != null;
    final folders =
        activity?.organization.folders
            .where((f) => !filtering && f.parentId == _folderId)
            .toList() ??
        <TopicFolder>[];
    if (_folderId == null && !filtering && activity != null) {
      for (final e in activity.mirrors.owners.entries) {
        if (e.value.kind == FollowingMirrorKind.folder &&
            (activity.mirrors.subscriptions[e.value.publisher]?.contains(
                  e.value.source,
                ) ??
                false) &&
            !folders.any((f) => f.id == e.key)) {
          folders.add(
            activity.organization.folders.firstWhere((f) => f.id == e.key),
          );
        }
      }
    }
    final folderSummaries =
        <
          String,
          ({
            TopicFolder folder,
            int newCount,
            bool countIsLowerBound,
            DateTime? lastPost,
            FollowingTopicFolderLastPost lastPostInfo,
            Iterable<FollowingTopic> previewTopics,
            bool canRefresh,
            bool refreshing,
            int remainingRefreshes,
          })
        >{
          for (final folder in folders)
            folder.id: (() {
              final summary = TopicFolder(
                id: folder.id,
                name: folder.name,
                searchIds: activity!.organization.recursiveIds(folder.id),
              );
              final unread = activity.topics.where(
                (topic) =>
                    summary.searchIds.contains(topic.id) && topic.hasNewPosts,
              );
              final lastPost = selectFollowingTopicFolderLastPost(
                folder: summary,
                topics: topicsById,
              );
              return (
                folder: summary,
                newCount: unread.fold(
                  0,
                  (count, topic) => count + (topic.newPostCountEstimate ?? 1),
                ),
                countIsLowerBound: unread.any(
                  (topic) =>
                      topic.newPostCountEstimate == null ||
                      topic.newPostCountIsLowerBound,
                ),
                lastPost: lastPost.lastPostAt,
                lastPostInfo: lastPost,
                previewTopics: summary.searchIds
                    .map((id) => topicsById[id])
                    .nonNulls,
                canRefresh: canRefreshFollowingTopicFolder(
                  folder: summary,
                  topics: activity.topics,
                  refreshingIds: activity.pendingRefreshIds,
                  refreshableProfileIds: refreshableProfileIds,
                ),
                refreshing: activity.pendingRefreshIds.any(
                  summary.searchIds.contains,
                ),
                remainingRefreshes: activity.pendingRefreshIds
                    .where(summary.searchIds.contains)
                    .length,
              );
            })(),
        };
    folders.sort((a, b) {
      final left = folderSummaries[a.id]!;
      final right = folderSummaries[b.id]!;
      final order = switch (selectedSort) {
        FollowingTopicSort.nameAsc => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        FollowingTopicSort.updatesFirst => switch ((
          left.newCount > 0,
          right.newCount > 0,
        )) {
          (true, false) => -1,
          (false, true) => 1,
          _ => 0,
        },
        FollowingTopicSort.manual || FollowingTopicSort.addedNewest => 0,
      };
      if (order != 0) return order;
      final position = a.position.compareTo(b.position);
      return position != 0 ? position : a.id.compareTo(b.id);
    });
    return _cachedBody = ListenableBuilder(
      listenable: _selection,
      builder: (context, _) => visible.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.load_failed),
              TextButton(
                onPressed: () {
                  ref.invalidate(followingTopicRepositoryProvider);
                  ref.invalidate(followingTopicsProvider);
                },
                child: Text(context.t.generic.action.retry),
              ),
            ],
          ),
        ),
        data: (items) {
          final normalizedFilter = _filterQuery.trim().toLowerCase();
          final allowedFolderIds = activity == null || _folderId == null
              ? null
              : activity.organization.tree.subtree(_folderId!);
          final placements = {
            for (final placement
                in activity?.organization.placements ??
                    const <FolderPlacement>[])
              placement.itemId: placement.folderId,
          };
          Iterable<String> orderedIds(String? folder) sync* {
            if (activity == null) return;
            yield* activity.organization.directIds(folder);
            for (final child in activity.organization.tree.children(folder)) {
              yield* orderedIds(child.id);
            }
          }

          final candidates = [
            for (final id in orderedIds(_folderId)) ?topicsById[id],
          ];
          var displayItems = filtering && activity != null
              ? candidates.where((topic) {
                  final folderId = placements[topic.id];
                  final inScope =
                      _folderId == null ||
                      (folderId != null &&
                          allowedFolderIds!.contains(folderId));
                  final matchesText =
                      normalizedFilter.isEmpty ||
                      topic.displayName.toLowerCase().contains(
                        normalizedFilter,
                      ) ||
                      topic.query.toLowerCase().contains(normalizedFilter);
                  return (profilesById.containsKey(topic.profileId) ||
                          activity.mirrors.isReceived(topic.id) ||
                          topic.localSource != null) &&
                      inScope &&
                      matchesText &&
                      (_filterProfileId == null ||
                          topic.profileId == _filterProfileId);
                }).toList()
              : List<FollowingTopic>.of(items);
          if (_folderId == null && !filtering && activity != null) {
            for (final e in activity.mirrors.owners.entries) {
              if (e.value.kind == FollowingMirrorKind.topic &&
                  (activity.mirrors.subscriptions[e.value.publisher]?.contains(
                        e.value.source,
                      ) ??
                      false) &&
                  !displayItems.any((t) => t.id == e.key)) {
                displayItems.add(
                  activity.topics.firstWhere((t) => t.id == e.key),
                );
              }
            }
          }
          // Sort the final unique projection after filtering and direct received
          // roots have been added. Publisher sections retain their own hierarchy.
          displayItems = sortFollowingTopics(
            {for (final topic in displayItems) topic.id: topic}.values.toList(),
            selectedSort,
          );
          _selection.reconcileDuringBuild(
            [
              for (final folder in folders)
                if (!(activity?.mirrors.isReceived(folder.id) ?? false))
                  (CollectionSelectionKind.folder, folder.id),
              for (final topic in displayItems)
                if (!(activity?.mirrors.isReceived(topic.id) ?? false))
                  (CollectionSelectionKind.topic, topic.id),
            ],
            scope: (_folderId, normalizedFilter, _filterProfileId),
          );
          final showBatchProgress =
              (activity?.batchCompleted ?? 0) < (activity?.batchTotal ?? 0);
          final localFolders = folders
              .where((f) => !(activity?.mirrors.isReceived(f.id) ?? false))
              .toList();
          final localTopics = displayItems
              .where((t) => !(activity?.mirrors.isReceived(t.id) ?? false))
              .toList();
          final records =
              <
                ({String? section, TopicFolder? folder, FollowingTopic? topic})
              >[];
          final publishers = {
            for (final id in [
              ...folders.map((f) => f.id),
              ...displayItems.map((t) => t.id),
            ])
              if (activity?.mirrors.owners[id]?.publisher case final publisher?)
                publisher,
          }.toList()..sort();
          final sections = _folderId == null && publishers.isNotEmpty;
          for (final publisher in <String?>[null, ...publishers]) {
            if (sections)
              records.add((
                section: publisher ?? '',
                folder: null,
                topic: null,
              ));
            for (final f in folders.where(
              (f) => activity?.mirrors.owners[f.id]?.publisher == publisher,
            )) {
              records.add((section: null, folder: f, topic: null));
            }
            for (final t in displayItems.where(
              (t) => activity?.mirrors.owners[t.id]?.publisher == publisher,
            )) {
              records.add((section: null, folder: null, topic: t));
            }
          }
          return Column(
            children: [
              if (_filterVisible || filtering)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: BooruSearchBar(
                          dense: true,
                          leading: const Icon(Symbols.search),
                          hintText: strings.filter_topics,
                          trailing: _filterQuery.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: context.t.generic.action.clear,
                                  onPressed: () =>
                                      setState(() => _filterQuery = ''),
                                  icon: const Icon(Symbols.close),
                                ),
                          onChanged: (value) =>
                              setState(() => _filterQuery = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: _filterProfileId,
                          onChanged: (value) =>
                              setState(() => _filterProfileId = value),
                          items: [
                            DropdownMenuItem(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.public, size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(child: Text(strings.all_profiles)),
                                ],
                              ),
                            ),
                            for (final profile in profiles)
                              DropdownMenuItem(
                                value: profile.id,
                                child: FollowingTopicProfileOption(
                                  profile: profile,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: displayItems.isEmpty && folders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              filtering
                                  ? strings.no_matching_topics
                                  : strings.empty,
                            ),
                            if (!filtering &&
                                !(activity?.mirrors.isReceived(
                                      _folderId ?? '',
                                    ) ??
                                    false)) ...[
                              const SizedBox(height: 12),
                              Tooltip(
                                message: strings.follow_a_topic,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    shape: followActionButtonShape,
                                  ),
                                  onPressed: _showEmptyFollow,
                                  icon: const Icon(Symbols.rss_feed),
                                  label: Text(strings.follow),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _bulkAdd,
                                icon: const Icon(Icons.playlist_add),
                                label: Text(strings.bulk_add),
                              ),
                            ],
                          ],
                        ),
                      )
                    : OrderedSelectionCanvas(
                        controller: _selection,
                        child: ListView.builder(
                          controller: _scroll,
                          itemCount:
                              records.length + (showBatchProgress ? 1 : 0),
                          itemBuilder: (context, rawIndex) {
                            if (showBatchProgress && rawIndex == 0) {
                              return LinearProgressIndicator(
                                key: const ValueKey(
                                  'following-batch-progress',
                                ),
                                value:
                                    activity!.batchCompleted /
                                    activity.batchTotal,
                              );
                            }
                            final index =
                                rawIndex - (showBatchProgress ? 1 : 0);
                            final row = records[index];
                            if (row.section case final publisher?) {
                              final name = publisher.isEmpty
                                  ? context.t.mitemite.local
                                  : ref
                                            .read(
                                              currentMiteMiteServiceProvider,
                                            )
                                            ?.receiverMirrors
                                            ?.aliases[publisher] ??
                                        activity
                                            ?.mirrors
                                            .publisherNames[publisher] ??
                                        publisher;
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  4,
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) => Row(
                                    children: [
                                      if (publisher.isNotEmpty) ...[
                                        const MiteMiteIcon(size: 20),
                                        const SizedBox(width: 8),
                                      ],
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: publisher.isEmpty
                                              ? constraints.maxWidth
                                              : (constraints.maxWidth - 92)
                                                        .clamp(
                                                          0,
                                                          double.infinity,
                                                        ) *
                                                    .75,
                                        ),
                                        child: Semantics(
                                          header: true,
                                          child: Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      if (publisher.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        const Expanded(child: Divider()),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          key: ValueKey((
                                            'following-device-edit',
                                            publisher,
                                          )),
                                          tooltip:
                                              context.t.generic.action.edit,
                                          constraints: const BoxConstraints(
                                            minWidth: 48,
                                            minHeight: 48,
                                          ),
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => runSyncAction(
                                            context,
                                            () async {
                                              final service = await ref.read(
                                                miteMiteServiceProvider.future,
                                              );
                                              if (context.mounted) {
                                                await editSyncDeviceAlias(
                                                  context,
                                                  service: service,
                                                  publisher: publisher,
                                                  alias: service
                                                      .receiverMirrors
                                                      ?.aliases[publisher],
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }
                            if (row.folder case final folder?) {
                              final localIndex = localFolders.indexOf(folder);
                              final summary =
                                  folderSummaries[folder.id]!.folder;
                              final lastPost =
                                  folderSummaries[folder.id]!.lastPostInfo;
                              return CollectionSelectable(
                                controller: _selection,
                                itemKey: (
                                  CollectionSelectionKind.folder,
                                  folder.id,
                                ),
                                child: Padding(
                                  key: ValueKey(
                                    'following-list-folder-${folder.id}',
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: FollowingTopicFolderCard(
                                    key: ValueKey(
                                      'following-topic-folder-${folder.id}',
                                    ),
                                    selecting: _selecting,
                                    readOnly:
                                        activity?.mirrors.isReceived(
                                          folder.id,
                                        ) ??
                                        false,
                                    definitionChanged:
                                        activity != null &&
                                        unseenFollowingTopicDefinitions(
                                          activity.mirrors,
                                          activity.organization,
                                          folder.id,
                                        ).isNotEmpty,
                                    published: published.contains(folder.id),
                                    syncActions: activity == null
                                        ? null
                                        : followingSyncMenu(
                                            context,
                                            ref,
                                            activity,
                                            folder.id,
                                          ),
                                    selected: _selectedFolders.contains(
                                      folder.id,
                                    ),
                                    onSelect:
                                        _selecting ||
                                            (activity?.mirrors.isReceived(
                                                  folder.id,
                                                ) ??
                                                false)
                                        ? null
                                        : () => _select(
                                            folder.id,
                                            folder: true,
                                          ),
                                    name: followingAliasLabel(
                                      folder.name,
                                      folder.id,
                                      activity!.mirrors,
                                      followingAliasSource(
                                                activity.mirrors,
                                                folder.id,
                                              ) ==
                                              null
                                          ? const {}
                                          : ref.read(
                                              syncCollectionAliasesProvider,
                                            ),
                                    ),
                                    onOpenFeed: folder.feedEnabled
                                        ? () => _openFolderFeed(folder.id)
                                        : null,
                                    itemCount: summary.searchIds.length,
                                    newPostCount:
                                        folderSummaries[folder.id]!.newCount,
                                    newPostCountIsLowerBound:
                                        folderSummaries[folder.id]!
                                            .countIsLowerBound,
                                    previewTopics: folderSummaries[folder.id]!
                                        .previewTopics,
                                    lastPostAt: lastPost.lastPostAt,
                                    hasBaseline: lastPost.hasBaseline,
                                    refreshing:
                                        folderSummaries[folder.id]!.refreshing,
                                    remainingRefreshes:
                                        folderSummaries[folder.id]!
                                            .remainingRefreshes,
                                    canRefresh:
                                        folderSummaries[folder.id]!.canRefresh,
                                    showMoveActions: canReorder,
                                    canMoveUp: localIndex > 0,
                                    canMoveDown:
                                        localIndex >= 0 &&
                                        localIndex < localFolders.length - 1,
                                    onOpen:
                                        (_selecting || selectionModifierPressed)
                                        ? () => _select(folder.id, folder: true)
                                        : () => _openFolder(folder.id),
                                    onAction: (action) => _onFolderAction(
                                      action,
                                      folder,
                                      localIndex,
                                    ),
                                  ),
                                ),
                              );
                            }
                            final topic = row.topic!;
                            final topicIndex = localTopics.indexOf(topic);
                            final owner = ref.watch(
                              followingTopicConfigProvider(topic.id),
                            );
                            final caption = owner == null
                                ? context.t.mitemite.following_paused
                                : followingTopicProfileCaption(
                                    owner,
                                    profiles,
                                  );
                            return CollectionSelectable(
                              controller: _selection,
                              itemKey: (
                                CollectionSelectionKind.topic,
                                topic.id,
                              ),
                              child: Padding(
                                key: ValueKey(
                                  'following-list-topic-${topic.id}',
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (filtering)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 12,
                                          top: 4,
                                        ),
                                        child: Text(
                                          placements[topic.id] == null
                                              ? strings.no_folder
                                              : activity!.organization.tree
                                                    .path(
                                                      placements[topic.id],
                                                    ),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ),
                                    FollowingTopicCard(
                                      key: ValueKey(topic.id),
                                      selecting: _selecting,
                                      selected: _selectedSearches.contains(
                                        topic.id,
                                      ),
                                      onSelect:
                                          _selecting ||
                                              (activity?.mirrors.isReceived(
                                                    topic.id,
                                                  ) ??
                                                  false)
                                          ? null
                                          : () => _select(topic.id),
                                      topic: topic,
                                      config: owner?.auth,
                                      readOnly:
                                          activity?.mirrors.isReceived(
                                            topic.id,
                                          ) ??
                                          false,
                                      definitionChanged:
                                          activity
                                              ?.mirrors
                                              .owners[topic.id]
                                              ?.hasDefinitionChange ??
                                          false,
                                      published: false,
                                      syncActions: activity == null
                                          ? null
                                          : followingSyncMenu(
                                              context,
                                              ref,
                                              activity,
                                              topic.id,
                                            ),
                                      onToggleAutoUpdate:
                                          activity?.mirrors.isReceived(
                                                topic.id,
                                              ) ??
                                              false
                                          ? () => _runAction(
                                              () => ref
                                                  .read(
                                                    followingTopicsProvider
                                                        .notifier,
                                                  )
                                                  .setAutoUpdate([
                                                    topic.id,
                                                  ], !topic.autoUpdateEnabled),
                                            )
                                          : null,
                                      ownerCaption: caption,
                                      refreshing:
                                          activity?.refreshingIds.contains(
                                            topic.id,
                                          ) ??
                                          false,
                                      onOpen: owner == null
                                          ? null
                                          : (_selecting ||
                                                selectionModifierPressed)
                                          ? () => _select(topic.id)
                                          : _openingIds.contains(topic.id)
                                          ? null
                                          : () => _open(
                                              topic,
                                              definitionDigest: activity
                                                  ?.mirrors
                                                  .owners[topic.id]
                                                  ?.definitionDigest,
                                            ),
                                      showMoveActions: canReorder,
                                      canMoveUp: topicIndex > 0,
                                      canMoveDown:
                                          topicIndex >= 0 &&
                                          topicIndex < localTopics.length - 1,
                                      onAction: (action) => _onAction(
                                        action,
                                        topic,
                                        localTopics,
                                        definitionDigest: activity
                                            ?.mirrors
                                            .owners[topic.id]
                                            ?.definitionDigest,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEmptyFollow() async {
    if (ref
            .read(followingTopicsProvider)
            .valueOrNull
            ?.mirrors
            .isReceived(_folderId ?? '') ??
        false)
      return;
    final profiles = ref.read(booruConfigProvider);
    if (profiles.isEmpty) return;
    final profileId = profiles.any((profile) => profile.id == ref.readConfig.id)
        ? ref.readConfig.id
        : profiles.first.id;
    final selection = await showDialog<({String profileId, String query})>(
      context: context,
      builder: (_) => _FollowTopicQueryDialog(
        profiles: profiles,
        initialProfileId: profileId,
        followDirectly: _folderId != null,
      ),
    );
    if (selection == null || !mounted) return;
    if (_folderId case final folderId?) {
      try {
        final notifier = ref.read(followingTopicsProvider.notifier);
        final existingDestinations = {
          for (final match in selectMatchingFollowingTopics(
            ref.read(followingTopicsProvider).requireValue,
            profileId: selection.profileId,
            query: selection.query,
          ))
            match.folderId,
        };
        final result = await notifier.setFollowDestinations(
          profileId: selection.profileId,
          query: selection.query,
          folderIds: {...existingDestinations, folderId},
        );
        final profile = profiles
            .where((profile) => profile.id == selection.profileId)
            .firstOrNull;
        if (profile != null &&
            ref.read(followingTopicTrackingSupportedProvider(profile.auth))) {
          for (final topic in result.added) {
            unawaited(notifier.refresh(topic.id));
          }
        }
      } catch (_) {
        if (mounted) {
          Kurumi.showErrorToast(
            context,
            context.t.following_topics.save_failed,
          );
        }
      }
      return;
    }
    await showTopicFollowFlow(
      context,
      ref,
      profileId: selection.profileId,
      query: selection.query,
      initialFolderId: _folderId,
    );
  }

  Future<void> _onFolderAction(
    FollowingTopicAction action,
    TopicFolder folder,
    int index,
  ) async {
    final notifier = ref.read(followingTopicsProvider.notifier);
    if ((ref
                .read(followingTopicsProvider)
                .valueOrNull
                ?.mirrors
                .isReceived(folder.id) ??
            false) &&
        action != FollowingTopicAction.refresh &&
        action != FollowingTopicAction.info)
      return;
    switch (action) {
      case FollowingTopicAction.refresh:
        await _runAction(() => notifier.refreshSharedFolder(folder.id));
      case FollowingTopicAction.rename || FollowingTopicAction.edit:
        await _editFolderSettings(folder);
      case FollowingTopicAction.moveUp || FollowingTopicAction.moveDown:
        await _runAction(
          () => notifier.reorderSharedFolders(
            index,
            index + (action == FollowingTopicAction.moveUp ? -1 : 1),
            parentId: _folderId,
          ),
        );
      case FollowingTopicAction.delete:
        await _deleteFolder(folder);
      case FollowingTopicAction.moveFolder:
        await _moveSelected(folderIds: {folder.id}, searchIds: {});
      case FollowingTopicAction.info:
        return;
    }
  }

  Future<void> _deleteFolder(TopicFolder folder) async {
    var expected = ref.read(followingTopicsProvider).requireValue.organization;
    while (true) {
      if (!mounted || !expected.tree.byId.containsKey(folder.id)) return;
      final folderIds = expected.tree.subtree(folder.id);
      final searchIds = expected.recursiveIds(folder.id);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            context.t.folders.delete_title.replaceAll('{name}', folder.name),
          ),
          content: Text(
            context.t.folders.delete_searches
                .replaceAll('{folders}', '${folderIds.length}')
                .replaceAll('{searches}', '${searchIds.length}'),
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
        await ref
            .read(followingTopicsProvider.notifier)
            .deleteSharedFolderAndTopics(
              folder.id,
              expectedOrganization: expected,
            );
        return;
      } on SearchFolderChangedException catch (e) {
        expected = e.organization;
      } catch (_) {
        if (mounted) {
          Kurumi.showErrorToast(
            context,
            context.t.following_topics.operation_failed,
          );
        }
        return;
      }
    }
  }

  Future<void> _open(FollowingTopic topic, {String? definitionDigest}) async {
    setState(() => _openingIds.add(topic.id));
    try {
      final owner = ref.read(followingTopicConfigProvider(topic.id));
      if (owner == null) return;
      await ref.read(followingTopicsProvider.notifier).markRead(topic.id);
      if (!mounted) return;
      switch (topic.queryStructure) {
        case final structure?:
          goToSearchPage(
            ref,
            tags: SearchTagSet.fromList(structure.typedTags),
            queryType: QueryType.list,
            config: owner,
            originatingTopicId: topic.id,
            followingDefinitionReceipts: definitionDigest == null
                ? const {}
                : {topic.id: definitionDigest},
          );
        case null:
          goToSearchPage(
            ref,
            tag: topic.query,
            queryType: QueryType.simple,
            config: owner,
            originatingTopicId: topic.id,
            followingDefinitionReceipts: definitionDigest == null
                ? const {}
                : {topic.id: definitionDigest},
          );
      }
    } catch (_) {
      if (mounted) {
        Kurumi.showErrorToast(
          context,
          context.t.following_topics.mark_read_failed,
        );
      }
    } finally {
      if (mounted) setState(() => _openingIds.remove(topic.id));
    }
  }

  Future<void> _refreshProfiles(List<String> profileIds) async {
    setState(() => _refreshingAllProfiles = true);
    SearchRefreshProgress? progress;
    try {
      progress = await ref
          .read(followingTopicsProvider.notifier)
          .planIndependentRefreshes(profileIds);
      for (final id in profileIds) {
        if (!mounted) return;
        await _refreshAll(id, progress: progress);
      }
    } finally {
      progress?.close();
      if (mounted) setState(() => _refreshingAllProfiles = false);
    }
  }

  Future<void> _refreshAll(
    String profileId, {
    SearchRefreshProgress? progress,
  }) async {
    await _runAction(
      () => ref
          .read(followingTopicsProvider.notifier)
          .refreshAll(profileId, progress: progress),
    );
  }

  Future<void> _onAction(
    FollowingTopicAction action,
    FollowingTopic topic,
    List<FollowingTopic> group, {
    String? definitionDigest,
  }) async {
    if ((ref
                .read(followingTopicsProvider)
                .valueOrNull
                ?.mirrors
                .isReceived(topic.id) ??
            false) &&
        action != FollowingTopicAction.refresh &&
        action != FollowingTopicAction.info)
      return;
    switch (action) {
      case FollowingTopicAction.rename:
        return;
      case FollowingTopicAction.info:
        await showDialog<void>(
          context: context,
          builder: (_) => FollowingTopicInfoDialog(topicId: topic.id),
        );
      case FollowingTopicAction.refresh:
        await _runAction(
          () => ref.read(followingTopicsProvider.notifier).refresh(topic.id),
        );
      case FollowingTopicAction.edit:
        final profiles = ref.read(booruConfigProvider);
        final sourceConfig = topic.localSource == null
            ? null
            : ref.read(followingTopicConfigProvider(topic.id));
        await showEditFollowingTopicDialog(
          context,
          topic: topic,
          profiles: profiles,
          sourceConfig: sourceConfig,
          trackingSupported: (auth) =>
              ref.read(followingTopicTrackingSupportedProvider(auth)),
          onSave: (profile, query, name, autoUpdateEnabled, structure) async {
            final anonymous = profile.anonymousReadScope;
            final profileId = anonymous == null ? profile.id : topic.profileId;
            final currentProfile = anonymous != null
                ? ref.read(followingTopicConfigProvider(topic.id))
                : ref
                      .read(booruConfigProvider)
                      .where((p) => p.id == profileId)
                      .firstOrNull;
            if (currentProfile == null ||
                currentProfile.auth != profile.auth ||
                (anonymous != null &&
                    (!anonymous.isCurrent ||
                        currentProfile.anonymousReadScope?.key !=
                            anonymous.key))) {
              throw MissingFollowingTopicProfileException();
            }
            final notifier = ref.read(followingTopicsProvider.notifier);
            final saved = await notifier.editLocally(
              topic.id,
              profileId: profileId,
              query: query,
              name: name,
              autoUpdateEnabled: autoUpdateEnabled,
              queryStructure: () => structure,
              expectedTopic: topic,
            );
            return (topic: saved.topic, refresh: null);
          },
        );
      case FollowingTopicAction.moveUp || FollowingTopicAction.moveDown:
        await _runAction(
          () => ref
              .read(followingTopicsProvider.notifier)
              .reorderSharedTopics(
                _folderId,
                group.indexOf(topic),
                group.indexOf(topic) +
                    (action == FollowingTopicAction.moveUp ? -1 : 1),
              ),
        );
      case FollowingTopicAction.moveFolder:
        final folders = ref
            .read(followingTopicsProvider)
            .requireValue
            .organization
            .folders;
        final choice = await showMoveTopicToFolderDialog(context, folders);
        if (choice == null || !mounted) return;
        final notifier = ref.read(followingTopicsProvider.notifier);
        await _runAction(() {
          if (choice.createName case final name?) {
            return notifier.createSharedFolderAndMoveTopic(
              topic.id,
              name,
              parentId: choice.parentId,
            );
          }
          return notifier.moveTopicToSharedFolder(
            topic.id,
            choice.folderId,
          );
        });
      case FollowingTopicAction.delete:
        await _unfollowTopic(topic);
    }
  }

  Future<void> _unfollowTopic(FollowingTopic topic) async {
    final state = ref.read(followingTopicsProvider).requireValue;
    final folderId = state.organization.placements
        .where((placement) => placement.itemId == topic.id)
        .firstOrNull
        ?.folderId;
    final notifier = ref.read(followingTopicsProvider.notifier);
    if (!await _runAction(() => notifier.delete(topic.id)) || !mounted) return;
    Kurumi.showSuccessToast(
      context,
      context.t.following_topics.unfollowed,
      duration: const Duration(seconds: 5),
      actionLabel: context.t.following_topics.undo,
      onAction: () async {
        try {
          if (topic.localSource != null) {
            await notifier.restoreIndependentTopic(topic, folderId: folderId);
            return;
          }
          final current = ref.read(followingTopicsProvider).valueOrNull;
          final destinations = current == null
              ? <String?>{}
              : {
                  for (final match in selectMatchingFollowingTopics(
                    current,
                    profileId: topic.profileId,
                    query: topic.query,
                  ))
                    match.folderId,
                };
          final restored = await notifier.setFollowDestinations(
            profileId: topic.profileId,
            query: topic.query,
            queryStructure: topic.queryStructure,
            name: topic.name,
            folderIds: {...destinations, folderId},
          );
          if (!topic.autoUpdateEnabled) {
            await notifier.setAutoUpdate(
              restored.added.map((item) => item.id),
              false,
            );
          }
        } catch (_) {
          if (mounted) {
            Kurumi.showErrorToast(
              context,
              context.t.following_topics.undo_failed,
            );
          }
        }
      },
    );
  }

  Future<bool> _runAction(Future<Object?> Function() action) async {
    try {
      final result = await action();
      final outcomes = switch (result) {
        SearchRefreshOutcome() => [result],
        List<SearchRefreshOutcome>() => result,
        _ => const <SearchRefreshOutcome>[],
      };
      final waits = outcomes.whereType<SearchRefreshDeferred>().toList();
      if (mounted && waits.isNotEmpty) {
        final retryAt = waits
            .map((r) => r.retryAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        Kurumi.showErrorToast(context, rateLimitWaitText(context, retryAt));
      }
      return true;
    } catch (_) {
      if (mounted) {
        Kurumi.showErrorToast(
          context,
          context.t.following_topics.operation_failed,
        );
      }
      return false;
    }
  }
}

class _FollowTopicQueryDialog extends StatefulWidget {
  const _FollowTopicQueryDialog({
    required this.profiles,
    required this.initialProfileId,
    required this.followDirectly,
  });

  final List<BooruConfig> profiles;
  final String initialProfileId;
  final bool followDirectly;

  @override
  State<_FollowTopicQueryDialog> createState() =>
      _FollowTopicQueryDialogState();
}

class _FollowTopicQueryDialogState extends State<_FollowTopicQueryDialog> {
  final _query = TextEditingController();
  late String _profileId = widget.initialProfileId;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.t.following_topics.follow_topic_title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _query,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.t.following_topics.edit_query,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _profileId,
            decoration: InputDecoration(
              labelText: context.t.following_topics.edit_profile,
            ),
            items: [
              for (final profile in widget.profiles)
                DropdownMenuItem(
                  value: profile.id,
                  child: FollowingTopicProfileOption(profile: profile),
                ),
            ],
            onChanged: (value) => setState(
              () => _profileId = value ?? _profileId,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.t.generic.action.cancel),
      ),
      FilledButton(
        style: widget.followDirectly
            ? FilledButton.styleFrom(shape: followActionButtonShape)
            : null,
        onPressed: _query.text.trim().isEmpty
            ? null
            : () => Navigator.pop(
                context,
                (profileId: _profileId, query: _query.text.trim()),
              ),
        child: Text(
          widget.followDirectly
              ? context.t.following_topics.follow
              : context.t.following_topics.next,
        ),
      ),
    ],
  );
}
