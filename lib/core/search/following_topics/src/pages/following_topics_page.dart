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
import '../../../search/routes.dart';
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
import 'topic_feeds_page.dart';

enum _FollowingTopicPageAction {
  bulkAdd,
  createFolder,
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
    final choice = await showFolderDestinationPicker(
      context,
      folders: ref
          .read(followingTopicsProvider)
          .requireValue
          .organization
          .folders,
      movingFolderIds: folderIds ?? _selectedFolders,
    );
    if (choice == null || !mounted) return;
    await _runAction(
      () => ref
          .read(followingTopicsProvider.notifier)
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
        .where(
          (c) => ref.watch(followingTopicTrackingSupportedProvider(c.auth)),
        )
        .map((c) => c.id)
        .toList();
    final refreshableProfileIds = eligibleProfiles.toSet();
    final activity = ref.watch(followingTopicsProvider).valueOrNull;
    final strings = context.t.following_topics;
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
    return Scaffold(
      appBar: KurumiAppBar(
        title: Text(
          _selecting
              ? context.t.folders.selected.replaceAll(
                  '{count}',
                  '${_selectedFolders.length + _selectedSearches.length}',
                )
              : folder?.name ?? strings.page_title,
        ),
        actions: [
          if (_selecting) ...[
            if (_selectedSearches.isNotEmpty)
              PopupMenuButton<bool>(
                tooltip: strings.auto_update_topic,
                icon: const Icon(Icons.autorenew),
                onSelected: (enabled) => _runAction(
                  () => ref
                      .read(followingTopicsProvider.notifier)
                      .setAutoUpdate(_selectedSearches, enabled),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: true,
                    child: Text(strings.auto_update_enable),
                  ),
                  PopupMenuItem(
                    value: false,
                    child: Text(strings.auto_update_disable),
                  ),
                ],
              ),
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
            if (directFolder?.feedEnabled ?? false)
              IconButton(
                tooltip: strings.open_feed,
                icon: const Icon(Symbols.rss_feed),
                onPressed: () => _openFolderFeed(directFolder!.id),
              ),
            PopupMenuButton<FollowingTopicSort>(
              tooltip: context.t.sort.sort_by,
              icon: const Icon(Symbols.sort),
              initialValue: ref.watch(followingTopicSortProvider),
              onSelected: (sort) =>
                  ref.read(followingTopicSortProvider.notifier).select(sort),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: FollowingTopicSort.manual,
                  child: Text(strings.sort_manual),
                ),
                PopupMenuItem(
                  value: FollowingTopicSort.nameAsc,
                  child: Text(context.t.sort.name_asc),
                ),
                PopupMenuItem(
                  value: FollowingTopicSort.updatesFirst,
                  child: Text(strings.sort_updates_first),
                ),
                PopupMenuItem(
                  value: FollowingTopicSort.lastPostOldest,
                  child: Text(strings.sort_last_post_oldest),
                ),
              ],
            ),
            PopupMenuButton<_FollowingTopicPageAction>(
              tooltip: context.t.generic.action.more,
              icon: const Icon(Symbols.more_vert),
              onSelected: (action) => _onPageAction(
                action,
                eligibleProfiles: eligibleProfiles,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _FollowingTopicPageAction.bulkAdd,
                  enabled: eligibleProfiles.isNotEmpty,
                  child: Text(strings.bulk_add),
                ),
                PopupMenuItem(
                  value: _FollowingTopicPageAction.createFolder,
                  child: Text(strings.create_folder),
                ),
                PopupMenuItem(
                  value: _FollowingTopicPageAction.refresh,
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
    _FollowingTopicPageAction action, {
    required List<String> eligibleProfiles,
  }) async {
    switch (action) {
      case _FollowingTopicPageAction.bulkAdd:
        await _bulkAdd();
      case _FollowingTopicPageAction.createFolder:
        await _createFolder();
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
    final options = await showSearchFolderSettingsDialog(context);
    if (options == null || !mounted) return;
    await _runAction(
      () => ref
          .read(followingTopicsProvider.notifier)
          .createSharedFolder(
            options.name,
            parentId: _folderId,
            feedEnabled: options.feedEnabled,
            feedMaxPosts: options.maxPosts,
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
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TopicFeedPage(
            feedId: feed.id,
            profileId: feed.profileId,
          ),
        ),
      );
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
    final profiles = [
      for (final config in configs)
        if (ref.read(followingTopicTrackingSupportedProvider(config.auth)))
          config,
    ];
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
    final profiles = ref.watch(booruConfigProvider);
    final activity = ref.watch(followingTopicsProvider).valueOrNull;
    final profilesById = {for (final profile in profiles) profile.id: profile};
    final topicsById = {
      for (final topic in activity?.topics ?? const <FollowingTopic>[])
        topic.id: topic,
    };
    final canReorder =
        ref.watch(followingTopicSortProvider) == FollowingTopicSort.manual;
    final folders =
        activity?.organization.folders
            .where((f) => f.parentId == _folderId)
            .toList() ??
        <TopicFolder>[];
    folders.sort((a, b) {
      if (ref.read(followingTopicSortProvider) == FollowingTopicSort.nameAsc) {
        final order = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (order != 0) return order;
      }
      return a.position.compareTo(b.position);
    });
    return ref
        .watch(visibleFollowingTopicsProvider(_folderId))
        .when(
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
                                final summary = TopicFolder(
                                  id: folder.id,
                                  name: folder.name,
                                  searchIds: activity!.organization
                                      .recursiveIds(
                                        folder.id,
                                      ),
                                );
                                final lastPost =
                                    selectFollowingTopicFolderLastPost(
                                      folder: summary,
                                      topics: topicsById,
                                    );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: FollowingTopicFolderCard(
                                    selecting: _selecting,
                                    selected: _selectedFolders.contains(
                                      folder.id,
                                    ),
                                    onSelect: () =>
                                        _select(folder.id, folder: true),
                                    key: ValueKey(
                                      'following-topic-folder-${folder.id}',
                                    ),
                                    name: folder.name,
                                    onOpenFeed: folder.feedEnabled
                                        ? () => _openFolderFeed(folder.id)
                                        : null,
                                    itemCount: summary.searchIds.length,
                                    hasNewPosts: activity.topics.any(
                                      (topic) =>
                                          summary.searchIds.contains(
                                            topic.id,
                                          ) &&
                                          topic.hasNewPosts,
                                    ),
                                    previews:
                                        selectFollowingTopicFolderPreviews(
                                          folder: summary,
                                          topics: topicsById,
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
                                    canRefresh: canRefreshFollowingTopicFolder(
                                      folder: summary,
                                      topics: activity.topics,
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
                          for (final (index, topic) in items.indexed)
                            Builder(
                              builder: (context) {
                                final owner = profiles.singleWhere(
                                  (c) => c.id == topic.profileId,
                                );
                                final caption = followingTopicProfileCaption(
                                  owner,
                                  profiles,
                                );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: FollowingTopicCard(
                                    selecting: _selecting,
                                    selected: _selectedSearches.contains(
                                      topic.id,
                                    ),
                                    onSelect: () => _select(topic.id),
                                    key: ValueKey(topic.id),
                                    topic: topic,
                                    config: owner.auth,
                                    ownerCaption: caption,
                                    refreshing:
                                        activity?.refreshingIds.contains(
                                          topic.id,
                                        ) ??
                                        false,
                                    onOpen: _selecting
                                        ? () => _select(topic.id)
                                        : _openingIds.contains(
                                            topic.id,
                                          )
                                        ? null
                                        : () => _open(topic),
                                    showMoveActions: canReorder,
                                    canMoveUp: index > 0,
                                    canMoveDown: index < items.length - 1,
                                    onAction: (action) => _onAction(
                                      action,
                                      topic,
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
    FollowingTopicAction action,
    TopicFolder folder,
    int index,
  ) async {
    final notifier = ref.read(followingTopicsProvider.notifier);
    switch (action) {
      case FollowingTopicAction.refresh:
        await _runAction(() => notifier.refreshSharedFolder(folder.id));
      case FollowingTopicAction.rename || FollowingTopicAction.edit:
        final options = await showSearchFolderSettingsDialog(
          context,
          name: folder.name,
          feedEnabled: folder.feedEnabled,
          maxPosts: folder.feedMaxPosts,
        );
        if (options == null || !mounted) return;
        await _runAction(
          () => notifier.renameSharedFolder(
            folder.id,
            options.name,
            feedEnabled: options.feedEnabled,
            maxPosts: options.maxPosts,
          ),
        );
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

  Future<void> _open(FollowingTopic topic) async {
    setState(() => _openingIds.add(topic.id));
    try {
      await ref.read(followingTopicsProvider.notifier).markRead(topic.id);
      if (!mounted) return;
      final owner = ref
          .read(booruConfigProvider)
          .where((c) => c.id == topic.profileId)
          .firstOrNull;
      if (owner == null) return;
      if (ref.readConfig.id != owner.id) {
        await ref.read(currentBooruConfigProvider.notifier).update(owner);
        if (!mounted) return;
      }
      switch (topic.queryStructure) {
        case final structure?:
          goToSearchPage(
            ref,
            tags: SearchTagSet.fromList(structure.typedTags),
            queryType: QueryType.list,
          );
        case null:
          goToSearchPage(
            ref,
            tag: topic.query,
            queryType: QueryType.simple,
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
    List<FollowingTopic> group,
  ) async {
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
        final result = await showEditFollowingTopicDialog(
          context,
          topic: topic,
          profiles: profiles,
          trackingSupported: (auth) =>
              ref.read(followingTopicTrackingSupportedProvider(auth)),
          onSave: (profileId, query, name) => ref
              .read(followingTopicsProvider.notifier)
              .edit(
                topic.id,
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
            context.t.following_topics.edit_baseline_failed,
          );
        }
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
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t.following_topics.remove_confirmation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.t.generic.action.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.t.following_topics.remove),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        await _runAction(
          () => ref.read(followingTopicsProvider.notifier).delete(topic.id),
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
          context.t.following_topics.operation_failed,
        );
      }
    }
  }
}
