import '../../../../errors/types.dart';
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
import '../../../search/routes.dart';
import '../../../selected_tags/types.dart';
import '../data/providers.dart';
import '../providers/search_subscription_selectors.dart';
import '../providers/search_subscriptions_notifier.dart';
import '../providers/pinned_search_sort_provider.dart';
import '../types/pinned_search_sort.dart';
import '../types/search_organization.dart';
import '../../../../groups/folder_navigation.dart';
import '../types/search_subscription.dart';
import '../types/search_refresh.dart';
import '../widgets/bulk_search_import_dialog.dart';
import '../widgets/move_pin_to_folder_dialog.dart';
import '../widgets/edit_pinned_search_dialog.dart';
import '../widgets/pinned_search_card.dart';
import '../widgets/pinned_search_profile_caption.dart';
import '../widgets/pinned_search_folder_card.dart';
import '../widgets/search_folder_dialog.dart';
import '../widgets/pinned_search_info_dialog.dart';

enum _PinnedSearchPageAction {
  bulkAdd,
  createFolder,
  refresh,
}

class PinnedSearchesPage extends ConsumerStatefulWidget {
  const PinnedSearchesPage({this.folderId, super.key})
    : _ancestorRoutes = const {};
  const PinnedSearchesPage._nested({
    required this.folderId,
    required Map<String?, Route<dynamic>> ancestorRoutes,
  }) : _ancestorRoutes = ancestorRoutes;
  final Map<String?, Route<dynamic>> _ancestorRoutes;

  final String? folderId;

  @override
  ConsumerState<PinnedSearchesPage> createState() => _PinnedSearchesPageState();
}

class _PinnedSearchesPageState extends ConsumerState<PinnedSearchesPage> {
  // Imports or another browser can remove the open folder. Fall back to Home.
  String? get _folderId {
    final id = widget.folderId;
    final folders = ref
        .read(searchSubscriptionsProvider)
        .valueOrNull
        ?.organization
        .folders;
    return folders?.any((f) => f.id == id) == true ? id : null;
  }

  final _openingIds = <String>{};
  final _selectedFolders = <String>{};
  final _selectedSearches = <String>{};
  var _selecting = false;
  void _select(String id, {bool folder = false}) => setState(() {
    final ids = folder ? _selectedFolders : _selectedSearches;
    if (!ids.add(id)) ids.remove(id);
    _selecting = _selectedFolders.isNotEmpty || _selectedSearches.isNotEmpty;
  });
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
        builder: (_) => PinnedSearchesPage._nested(
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
    final choice = await showFolderDestinationPicker(
      context,
      folders: ref
          .read(searchSubscriptionsProvider)
          .requireValue
          .organization
          .folders,
      movingFolderIds: folderIds ?? _selectedFolders,
    );
    if (choice == null || !mounted) return;
    await _runAction(
      () => ref
          .read(searchSubscriptionsProvider.notifier)
          .moveFolderItems(
            folderIds: folderIds ?? _selectedFolders,
            searchIds: searchIds ?? _selectedSearches,
            destination: choice.folderId,
          ),
    );
    if (mounted) {
      setState(() {
        _selectedFolders.clear();
        _selectedSearches.clear();
        _selecting = false;
      });
    }
  }

  var _refreshingAllProfiles = false;

  @override
  Widget build(BuildContext context) {
    final eligibleProfiles = ref
        .watch(booruConfigProvider)
        .where((c) => ref.watch(pinnedSearchTrackingSupportedProvider(c.auth)))
        .map((c) => c.id)
        .toList();
    final refreshableProfileIds = eligibleProfiles.toSet();
    final activity = ref.watch(searchSubscriptionsProvider).valueOrNull;
    final strings = context.t.pinned_searches;
    final directFolder = activity?.organization.folders
        .where((folder) => folder.id == _folderId)
        .firstOrNull;
    final folder = directFolder == null
        ? null
        : SharedSearchFolder(
            id: directFolder.id,
            name: directFolder.name,
            searchIds: activity!.organization.recursiveIds(directFolder.id),
          );
    final batchRunning =
        (activity?.batchCompleted ?? 0) < (activity?.batchTotal ?? 0);
    final canRefreshAll =
        !_refreshingAllProfiles &&
        !batchRunning &&
        (activity?.subscriptions.any(
              (subscription) =>
                  !activity.feeds.any(
                    (feed) => feed.sourceIds.contains(subscription.id),
                  ) &&
                  eligibleProfiles.contains(subscription.profileId),
            ) ??
            false);
    final canRefreshFolder = canRefreshPinnedSearchFolder(
      folder: folder,
      subscriptions: activity?.subscriptions ?? const <SearchSubscription>[],
      refreshingIds: activity?.pendingRefreshIds ?? const <String>{},
      refreshableProfileIds: refreshableProfileIds,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selecting
              ? context.t.folders.selected.replaceAll(
                  '{count}',
                  '${_selectedFolders.length + _selectedSearches.length}',
                )
              : folder?.name ?? strings.title,
        ),
        actions: [
          if (_selecting) ...[
            IconButton(
              tooltip: context.t.folders.move,
              icon: const Icon(Icons.drive_file_move_outline),
              onPressed: () => _moveSelected(),
            ),
            IconButton(
              tooltip: context.t.generic.action.cancel,
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _selecting = false;
                _selectedFolders.clear();
                _selectedSearches.clear();
              }),
            ),
          ] else ...[
            PopupMenuButton<PinnedSearchSort>(
              tooltip: context.t.sort.sort_by,
              icon: const Icon(Symbols.sort),
              initialValue: ref.watch(pinnedSearchSortProvider),
              onSelected: (sort) =>
                  ref.read(pinnedSearchSortProvider.notifier).select(sort),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: PinnedSearchSort.manual,
                  child: Text(strings.sort_manual),
                ),
                PopupMenuItem(
                  value: PinnedSearchSort.updatesFirst,
                  child: Text(strings.sort_updates_first),
                ),
                PopupMenuItem(
                  value: PinnedSearchSort.lastPostOldest,
                  child: Text(strings.sort_last_post_oldest),
                ),
              ],
            ),
            PopupMenuButton<_PinnedSearchPageAction>(
              tooltip: context.t.generic.action.more,
              icon: const Icon(Symbols.more_vert),
              onSelected: (action) => _onPageAction(
                action,
                eligibleProfiles: eligibleProfiles,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _PinnedSearchPageAction.bulkAdd,
                  enabled: eligibleProfiles.isNotEmpty,
                  child: Text(strings.bulk_add),
                ),
                PopupMenuItem(
                  value: _PinnedSearchPageAction.createFolder,
                  child: Text(strings.create_folder),
                ),
                PopupMenuItem(
                  value: _PinnedSearchPageAction.refresh,
                  enabled: _folderId == null ? canRefreshAll : canRefreshFolder,
                  child: Text(
                    _folderId == null
                        ? strings.refresh_all
                        : strings.refresh_folder,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _allProfilesBody(refreshableProfileIds),
    );
  }

  Future<void> _onPageAction(
    _PinnedSearchPageAction action, {
    required List<String> eligibleProfiles,
  }) async {
    switch (action) {
      case _PinnedSearchPageAction.bulkAdd:
        await _bulkAdd();
      case _PinnedSearchPageAction.createFolder:
        await _createFolder();
      case _PinnedSearchPageAction.refresh:
        if (_folderId case final folderId?) {
          await _runAction(
            () => ref
                .read(searchSubscriptionsProvider.notifier)
                .refreshSharedFolder(folderId),
          );
        } else {
          await _refreshProfiles(eligibleProfiles);
        }
    }
  }

  Future<void> _createFolder() async {
    final name = await showSearchFolderNameDialog(context);
    if (name == null || !mounted) return;
    await _runAction(
      () => ref
          .read(searchSubscriptionsProvider.notifier)
          .createSharedFolder(name, parentId: _folderId),
    );
  }

  Future<void> _bulkAdd() async {
    final configs = ref.read(booruConfigProvider);
    final profiles = [
      for (final config in configs)
        if (ref.read(pinnedSearchTrackingSupportedProvider(config.auth)))
          config,
    ];
    final folder = ref
        .read(searchSubscriptionsProvider)
        .valueOrNull
        ?.organization
        .folders
        .where((item) => item.id == _folderId)
        .firstOrNull;
    final count = await showBulkSearchImportDialog(
      context,
      destination: folder?.name ?? context.t.pinned_searches.home,
      profiles: profiles,
      initialProfileId: ref.readConfig.id,
      onAdd: (profileId, queries) => ref
          .read(searchSubscriptionsProvider.notifier)
          .bulkPinToFolder(
            profileId: profileId!,
            folderId: _folderId,
            rawQueries: queries,
          ),
    );
    if (count == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t.pinned_searches.bulk_added.replaceAll('{count}', '$count'),
        ),
      ),
    );
  }

  Widget _allProfilesBody(Set<String> refreshableProfileIds) {
    final strings = context.t.pinned_searches;
    final profiles = ref.watch(booruConfigProvider);
    final activity = ref.watch(searchSubscriptionsProvider).valueOrNull;
    final profilesById = {for (final profile in profiles) profile.id: profile};
    final subscriptionsById = {
      for (final subscription
          in activity?.subscriptions ?? const <SearchSubscription>[])
        subscription.id: subscription,
    };
    final canReorder =
        ref.watch(pinnedSearchSortProvider) == PinnedSearchSort.manual;
    final folders =
        activity?.organization.folders
            .where((f) => f.parentId == _folderId)
            .toList() ??
        <SharedSearchFolder>[];
    folders.sort((a, b) => a.position.compareTo(b.position));
    return ref
        .watch(visiblePinnedSearchesProvider(_folderId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(strings.load_failed),
                TextButton(
                  onPressed: () {
                    ref.invalidate(searchSubscriptionRepositoryProvider);
                    ref.invalidate(searchSubscriptionsProvider);
                  },
                  child: Text(context.t.generic.action.retry),
                ),
              ],
            ),
          ),
          data: (items) => Column(
            children: [
              if (_folderId != null && activity != null)
                FolderBreadcrumbs(
                  tree: activity.organization.tree,
                  currentId: _folderId,
                  onOpen: _openFolder,
                ),
              Expanded(
                child: items.isEmpty && folders.isEmpty
                    ? Center(child: Text(strings.empty))
                    : ListView(
                        children: [
                          if ((activity?.batchCompleted ?? 0) <
                              (activity?.batchTotal ?? 0))
                            LinearProgressIndicator(
                              value:
                                  activity!.batchCompleted /
                                  activity.batchTotal,
                            ),
                          for (final (index, folder) in folders.indexed)
                            Builder(
                              builder: (context) {
                                final summary = SharedSearchFolder(
                                  id: folder.id,
                                  name: folder.name,
                                  searchIds: activity!.organization
                                      .recursiveIds(
                                        folder.id,
                                      ),
                                );
                                final lastPost =
                                    selectPinnedSearchFolderLastPost(
                                      folder: summary,
                                      subscriptions: subscriptionsById,
                                    );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: PinnedSearchFolderCard(
                                    selecting: _selecting,
                                    selected: _selectedFolders.contains(
                                      folder.id,
                                    ),
                                    onSelect: () =>
                                        _select(folder.id, folder: true),
                                    key: ValueKey(
                                      'pinned-search-folder-${folder.id}',
                                    ),
                                    name: folder.name,
                                    itemCount: summary.searchIds.length,
                                    hasNewPosts: activity.subscriptions.any(
                                      (subscription) =>
                                          summary.searchIds.contains(
                                            subscription.id,
                                          ) &&
                                          subscription.hasNewPosts,
                                    ),
                                    previews: selectPinnedSearchFolderPreviews(
                                      folder: summary,
                                      subscriptions: subscriptionsById,
                                      profiles: profilesById,
                                    ),
                                    lastPostAt: lastPost.lastPostAt,
                                    hasBaseline: lastPost.hasBaseline,
                                    refreshing: activity.pendingRefreshIds.any(
                                      summary.searchIds.contains,
                                    ),
                                    remainingRefreshes: activity
                                        .pendingRefreshIds
                                        .where(summary.searchIds.contains)
                                        .length,
                                    canRefresh: canRefreshPinnedSearchFolder(
                                      folder: summary,
                                      subscriptions: activity.subscriptions,
                                      refreshingIds: activity.pendingRefreshIds,
                                      refreshableProfileIds:
                                          refreshableProfileIds,
                                    ),
                                    showMoveActions: canReorder,
                                    canMoveUp: index > 0,
                                    canMoveDown: index < folders.length - 1,
                                    onOpen: _selecting
                                        ? () => _select(
                                            folder.id,
                                            folder: true,
                                          )
                                        : () => _openFolder(folder.id),
                                    onAction: (action) => _onFolderAction(
                                      action,
                                      folder,
                                      index,
                                    ),
                                  ),
                                );
                              },
                            ),
                          for (final (index, subscription) in items.indexed)
                            Builder(
                              builder: (context) {
                                final owner = profiles.singleWhere(
                                  (c) => c.id == subscription.profileId,
                                );
                                final caption = pinnedSearchProfileCaption(
                                  owner,
                                  profiles,
                                );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: PinnedSearchCard(
                                    selecting: _selecting,
                                    selected: _selectedSearches.contains(
                                      subscription.id,
                                    ),
                                    onSelect: () => _select(subscription.id),
                                    key: ValueKey(subscription.id),
                                    subscription: subscription,
                                    config: owner.auth,
                                    ownerCaption: caption,
                                    refreshing:
                                        activity?.refreshingIds.contains(
                                          subscription.id,
                                        ) ??
                                        false,
                                    onOpen: _selecting
                                        ? () => _select(subscription.id)
                                        : _openingIds.contains(
                                            subscription.id,
                                          )
                                        ? null
                                        : () => _open(subscription),
                                    showMoveActions: canReorder,
                                    canMoveUp: index > 0,
                                    canMoveDown: index < items.length - 1,
                                    onAction: (action) => _onAction(
                                      action,
                                      subscription,
                                      items,
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
  }

  Future<void> _onFolderAction(
    PinnedSearchAction action,
    SharedSearchFolder folder,
    int index,
  ) async {
    final notifier = ref.read(searchSubscriptionsProvider.notifier);
    switch (action) {
      case PinnedSearchAction.refresh:
        await _runAction(() => notifier.refreshSharedFolder(folder.id));
      case PinnedSearchAction.rename:
        final name = await showSearchFolderNameDialog(
          context,
          name: folder.name,
        );
        if (name == null || !mounted) return;
        await _runAction(() => notifier.renameSharedFolder(folder.id, name));
      case PinnedSearchAction.moveUp || PinnedSearchAction.moveDown:
        await _runAction(
          () => notifier.reorderSharedFolders(
            index,
            index + (action == PinnedSearchAction.moveUp ? -1 : 1),
            parentId: _folderId,
          ),
        );
      case PinnedSearchAction.delete:
        await _deleteFolder(folder);
      case PinnedSearchAction.moveFolder:
        await _moveSelected(folderIds: {folder.id}, searchIds: {});
      case PinnedSearchAction.info || PinnedSearchAction.edit:
        return;
    }
  }

  Future<void> _deleteFolder(SharedSearchFolder folder) async {
    var expected = ref
        .read(searchSubscriptionsProvider)
        .requireValue
        .organization;
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
            .read(searchSubscriptionsProvider.notifier)
            .deleteSharedFolderAndPins(
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
            context.t.pinned_searches.operation_failed,
          );
        }
        return;
      }
    }
  }

  Future<void> _open(SearchSubscription subscription) async {
    setState(() => _openingIds.add(subscription.id));
    try {
      await ref
          .read(searchSubscriptionsProvider.notifier)
          .markRead(subscription.id);
      if (!mounted) return;
      final owner = ref
          .read(booruConfigProvider)
          .where((c) => c.id == subscription.profileId)
          .firstOrNull;
      if (owner == null) return;
      if (ref.readConfig.id != owner.id) {
        await ref.read(currentBooruConfigProvider.notifier).update(owner);
        if (!mounted) return;
      }
      switch (subscription.queryStructure) {
        case final structure?:
          goToSearchPage(
            ref,
            tags: SearchTagSet.fromList(structure.typedTags),
            queryType: QueryType.list,
          );
        case null:
          goToSearchPage(
            ref,
            tag: subscription.query,
            queryType: QueryType.simple,
          );
      }
    } catch (_) {
      if (mounted) {
        Kurumi.showErrorToast(
          context,
          context.t.pinned_searches.mark_read_failed,
        );
      }
    } finally {
      if (mounted) setState(() => _openingIds.remove(subscription.id));
    }
  }

  Future<void> _refreshProfiles(List<String> profileIds) async {
    setState(() => _refreshingAllProfiles = true);
    SearchRefreshProgress? progress;
    try {
      progress = await ref
          .read(searchSubscriptionsProvider.notifier)
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
          .read(searchSubscriptionsProvider.notifier)
          .refreshAll(profileId, progress: progress),
    );
  }

  Future<void> _onAction(
    PinnedSearchAction action,
    SearchSubscription subscription,
    List<SearchSubscription> group,
  ) async {
    switch (action) {
      case PinnedSearchAction.rename:
        return;
      case PinnedSearchAction.info:
        await showDialog<void>(
          context: context,
          builder: (_) =>
              PinnedSearchInfoDialog(subscriptionId: subscription.id),
        );
      case PinnedSearchAction.refresh:
        await _runAction(
          () => ref
              .read(searchSubscriptionsProvider.notifier)
              .refresh(subscription.id),
        );
      case PinnedSearchAction.edit:
        final profiles = ref.read(booruConfigProvider);
        final result = await showEditPinnedSearchDialog(
          context,
          subscription: subscription,
          profiles: profiles,
          trackingSupported: (auth) =>
              ref.read(pinnedSearchTrackingSupportedProvider(auth)),
          onSave: (profileId, query, name) => ref
              .read(searchSubscriptionsProvider.notifier)
              .edit(
                subscription.id,
                profileId: profileId,
                query: query,
                name: name,
              ),
        );
        if (!mounted || result == null) return;
        if (result.refresh case SearchRefreshFailed(
          :final kind,
        ) when kind != SearchRefreshErrorKind.unsupported) {
          Kurumi.showErrorToast(
            context,
            context.t.pinned_searches.edit_baseline_failed,
          );
        }
      case PinnedSearchAction.moveUp || PinnedSearchAction.moveDown:
        await _runAction(
          () => ref
              .read(searchSubscriptionsProvider.notifier)
              .reorderSharedPins(
                _folderId,
                group.indexOf(subscription),
                group.indexOf(subscription) +
                    (action == PinnedSearchAction.moveUp ? -1 : 1),
              ),
        );
      case PinnedSearchAction.moveFolder:
        final folders = ref
            .read(searchSubscriptionsProvider)
            .requireValue
            .organization
            .folders;
        final choice = await showMovePinToFolderDialog(context, folders);
        if (choice == null || !mounted) return;
        final notifier = ref.read(searchSubscriptionsProvider.notifier);
        await _runAction(() {
          if (choice.createName case final name?) {
            return notifier.createSharedFolderAndMovePin(
              subscription.id,
              name,
              parentId: choice.parentId,
            );
          }
          return notifier.movePinToSharedFolder(
            subscription.id,
            choice.folderId,
          );
        });
      case PinnedSearchAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              context.t.pinned_searches.delete_title.replaceAll(
                '{name}',
                subscription.displayName,
              ),
            ),
            content: Text(context.t.pinned_searches.delete_message),
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
        await _runAction(
          () => ref
              .read(searchSubscriptionsProvider.notifier)
              .delete(subscription.id),
        );
    }
  }

  Future<void> _runAction(Future<Object?> Function() action) async {
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
    } catch (_) {
      if (mounted) {
        Kurumi.showErrorToast(
          context,
          context.t.pinned_searches.operation_failed,
        );
      }
    }
  }
}
