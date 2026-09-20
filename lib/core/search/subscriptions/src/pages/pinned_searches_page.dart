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
import '../types/search_subscription.dart';
import '../widgets/move_pin_to_folder_dialog.dart';
import '../widgets/search_refresh_settings_dialog.dart';
import '../widgets/pin_search_dialog.dart';
import '../widgets/pinned_search_card.dart';
import 'search_folder_management_page.dart';

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
    final activity = ref.watch(searchSubscriptionsProvider).valueOrNull;
    final strings = context.t.pinned_searches;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          activity?.organization.folders
                  .where((f) => f.id == widget.folderId)
                  .firstOrNull
                  ?.name ??
              strings.title,
        ),
        actions: [
          if (widget.folderId == null)
            IconButton(
              tooltip: strings.refresh_settings,
              icon: const Icon(Symbols.settings),
              onPressed: () => showSearchRefreshSettingsDialog(context),
            ),
          if (widget.folderId == null)
            IconButton(
              tooltip: strings.manage_folders,
              icon: const Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Symbols.folder),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Icon(Symbols.build, size: 14, fill: 1),
                  ),
                ],
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SearchFolderManagementPage(),
                ),
              ),
            ),
          IconButton(
            tooltip: widget.folderId == null
                ? strings.refresh_all
                : strings.refresh_folder,
            icon: const Icon(Symbols.refresh),
            onPressed: widget.folderId != null
                ? () => _runAction(
                    () => ref
                        .read(searchSubscriptionsProvider.notifier)
                        .refreshSharedFolder(widget.folderId!),
                  )
                : (_refreshingAllProfiles ||
                          (activity?.batchCompleted ?? 0) <
                              (activity?.batchTotal ?? 0) ||
                          !(activity?.subscriptions.any(
                                (s) =>
                                    !activity.feeds.any(
                                      (feed) => feed.sourceIds.contains(s.id),
                                    ) &&
                                    eligibleProfiles.contains(s.profileId),
                              ) ??
                              false)
                      ? null
                      : () => _refreshProfiles(eligibleProfiles)),
          ),
        ],
      ),
      body: _allProfilesBody(),
    );
  }

  Widget _allProfilesBody() {
    final strings = context.t.pinned_searches;
    final profiles = ref.watch(booruConfigProvider);
    final activity = ref.watch(searchSubscriptionsProvider).valueOrNull;
    final folders = widget.folderId == null
        ? activity?.organization.folders ?? []
        : [];
    return ref
        .watch(organizedPinnedSearchesProvider(widget.folderId))
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
                    for (final folder in folders)
                      ListTile(
                        leading: Badge(
                          isLabelVisible: activity!.subscriptions.any(
                            (s) =>
                                folder.searchIds.contains(s.id) &&
                                s.hasNewPosts,
                          ),
                          child: const Icon(Symbols.folder),
                        ),
                        title: Text(folder.name),
                        subtitle: Text(
                          strings.folder_item_count.replaceAll(
                            '{count}',
                            '${folder.searchIds.length}',
                          ),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PinnedSearchesPage(folderId: folder.id),
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: strings.refresh_folder,
                          icon: const Icon(Symbols.refresh),
                          onPressed: () => _runAction(
                            () => ref
                                .read(searchSubscriptionsProvider.notifier)
                                .refreshSharedFolder(folder.id),
                          ),
                        ),
                      ),
                    for (final (index, subscription) in items.indexed)
                      Builder(
                        builder: (context) {
                          final owner = profiles.singleWhere(
                            (c) => c.id == subscription.profileId,
                          );
                          final caption = owner.name.isEmpty
                              ? owner.url
                              : profiles
                                        .where((c) => c.name == owner.name)
                                        .length ==
                                    1
                              ? owner.name
                              : '${owner.name} · ${owner.url}';
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
      goToSearchPage(ref, tag: subscription.query, queryType: QueryType.simple);
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

  Future<void> _refreshProfiles(List<int> profileIds) async {
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

  Future<void> _refreshAll(int profileId) async {
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
      case PinnedSearchAction.rename:
        final name = await showPinSearchDialog(
          context,
          query: subscription.query,
          initialName: subscription.name,
          isPinned: true,
        );
        if (name == null || !mounted) return;
        await _runAction(
          () => ref
              .read(searchSubscriptionsProvider.notifier)
              .rename(subscription.id, name),
        );
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
