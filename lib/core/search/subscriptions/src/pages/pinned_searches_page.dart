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
import '../types/search_subscription.dart';
import '../types/search_refresh.dart';
import '../widgets/bulk_search_import_dialog.dart';
import '../widgets/move_pin_to_folder_dialog.dart';
import '../widgets/edit_pinned_search_dialog.dart';
import '../widgets/pinned_search_card.dart';
import '../widgets/pinned_search_profile_caption.dart';
import '../widgets/pinned_search_folder_card.dart';
import '../widgets/search_folder_dialog.dart';

enum _PinnedSearchPageAction {
  bulkAdd,
  createFolder,
  refresh,
}

class PinnedSearchesPage extends ConsumerStatefulWidget {
  const PinnedSearchesPage({this.folderId, super.key});

  final String? folderId;

  @override
  ConsumerState<PinnedSearchesPage> createState() => _PinnedSearchesPageState();
}

class _PinnedSearchesPageState extends ConsumerState<PinnedSearchesPage> {
  final _openingIds = <String>{};
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
    final folder = activity?.organization.folders
        .where((folder) => folder.id == widget.folderId)
        .firstOrNull;
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
      refreshingIds: activity?.refreshingIds ?? const <String>{},
      refreshableProfileIds: refreshableProfileIds,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          folder?.name ?? strings.title,
        ),
        actions: [
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
              if (widget.folderId == null)
                PopupMenuItem(
                  value: _PinnedSearchPageAction.createFolder,
                  child: Text(strings.create_folder),
                ),
              PopupMenuItem(
                value: _PinnedSearchPageAction.refresh,
                enabled: widget.folderId == null
                    ? canRefreshAll
                    : canRefreshFolder,
                child: Text(
                  widget.folderId == null
                      ? strings.refresh_all
                      : strings.refresh_folder,
                ),
              ),
            ],
          ),
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
        if (widget.folderId case final folderId?) {
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
          .createSharedFolder(name),
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
        .where((item) => item.id == widget.folderId)
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
            folderId: widget.folderId,
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
    final folders = widget.folderId == null
        ? activity?.organization.folders ?? []
        : [];
    return ref
        .watch(visiblePinnedSearchesProvider(widget.folderId))
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
          data: (items) => items.isEmpty && folders.isEmpty
              ? Center(child: Text(strings.empty))
              : ListView(
                  children: [
                    if ((activity?.batchCompleted ?? 0) <
                        (activity?.batchTotal ?? 0))
                      LinearProgressIndicator(
                        value: activity!.batchCompleted / activity.batchTotal,
                      ),
                    for (final (index, folder) in folders.indexed)
                      Builder(
                        builder: (context) {
                          final lastPost = selectPinnedSearchFolderLastPost(
                            folder: folder,
                            subscriptions: subscriptionsById,
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: PinnedSearchFolderCard(
                              key: ValueKey(
                                'pinned-search-folder-${folder.id}',
                              ),
                              name: folder.name,
                              itemCount: folder.searchIds.length,
                              hasNewPosts: activity!.subscriptions.any(
                                (subscription) =>
                                    folder.searchIds.contains(
                                      subscription.id,
                                    ) &&
                                    subscription.hasNewPosts,
                              ),
                              previews: selectPinnedSearchFolderPreviews(
                                folder: folder,
                                subscriptions: subscriptionsById,
                                profiles: profilesById,
                              ),
                              lastPostAt: lastPost.lastPostAt,
                              hasBaseline: lastPost.hasBaseline,
                              refreshing: activity.refreshingIds.any(
                                folder.searchIds.contains,
                              ),
                              canRefresh: canRefreshPinnedSearchFolder(
                                folder: folder,
                                subscriptions: activity.subscriptions,
                                refreshingIds: activity.refreshingIds,
                                refreshableProfileIds: refreshableProfileIds,
                              ),
                              showMoveActions: canReorder,
                              canMoveUp: index > 0,
                              canMoveDown: index < folders.length - 1,
                              onOpen: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      PinnedSearchesPage(folderId: folder.id),
                                ),
                              ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: PinnedSearchCard(
                              key: ValueKey(subscription.id),
                              subscription: subscription,
                              config: owner.auth,
                              ownerCaption: caption,
                              refreshing:
                                  activity?.refreshingIds.contains(
                                    subscription.id,
                                  ) ??
                                  false,
                              onOpen: _openingIds.contains(subscription.id)
                                  ? null
                                  : () => _open(subscription),
                              showMoveActions: canReorder,
                              canMoveUp: index > 0,
                              canMoveDown: index < items.length - 1,
                              onAction: (action) =>
                                  _onAction(action, subscription, items),
                            ),
                          );
                        },
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
          ),
        );
      case PinnedSearchAction.delete:
        await _deleteFolder(folder);
      case PinnedSearchAction.info ||
          PinnedSearchAction.moveFolder ||
          PinnedSearchAction.edit:
        return;
    }
  }

  Future<void> _deleteFolder(SharedSearchFolder folder) async {
    final strings = context.t.pinned_searches;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.delete_title.replaceAll('{name}', folder.name)),
        content: folder.searchIds.isEmpty
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.delete_shared_folder_message.replaceAll(
                      '{count}',
                      '${folder.searchIds.length}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(strings.unpinning_cannot_be_undone),
                ],
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
    await _runAction(
      () => ref
          .read(searchSubscriptionsProvider.notifier)
          .deleteSharedFolderAndPins(folder.id),
    );
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
    try {
      for (final id in profileIds) {
        if (!mounted) return;
        await _refreshAll(id);
      }
    } finally {
      if (mounted) setState(() => _refreshingAllProfiles = false);
    }
  }

  Future<void> _refreshAll(String profileId) async {
    await _runAction(
      () =>
          ref.read(searchSubscriptionsProvider.notifier).refreshAll(profileId),
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
          builder: (context) {
            final strings = context.t.pinned_searches;
            final localizations = MaterialLocalizations.of(context);
            String date(DateTime value) {
              final local = value.toLocal();
              return '${localizations.formatMediumDate(local)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
            }

            return AlertDialog(
              title: Text(strings.info),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subscription.displayName),
                  Text(subscription.query),
                  const SizedBox(height: 16),
                  Text(switch (subscription.lastSuccessfulCheckAt) {
                    null => strings.never_checked,
                    final checked => strings.last_checked.replaceAll(
                      '{date}',
                      date(checked),
                    ),
                  }),
                  if (subscription.lastAttemptAt case final attempted?)
                    Text(
                      strings.last_attempt.replaceAll(
                        '{date}',
                        date(attempted),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.t.generic.action.ok),
                ),
              ],
            );
          },
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
                widget.folderId,
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
            return notifier.createSharedFolderAndMovePin(subscription.id, name);
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
      await action();
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
