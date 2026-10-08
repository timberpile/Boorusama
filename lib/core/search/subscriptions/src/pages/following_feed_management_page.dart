import '../types/search_refresh.dart';
import '../../../../errors/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../configs/manage/providers.dart';
import '../../../search/routes.dart';
import '../providers/search_subscriptions_notifier.dart';
import '../types/search_following_feed.dart';
import '../types/search_subscription.dart';
import '../widgets/bulk_search_import_dialog.dart';
import '../providers/following_feed_member_sort_provider.dart';
import '../types/following_feed_member_sort.dart';
import '../widgets/following_feed_member_card.dart';
import '../widgets/pinned_search_card.dart';
import '../widgets/edit_feed_member_name_dialog.dart';
import '../widgets/pinned_search_info_dialog.dart';
import '../widgets/pinned_search_profile_caption.dart';

class FollowingFeedManagementPage extends ConsumerWidget {
  const FollowingFeedManagementPage({required this.feedId, super.key});

  final String feedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.t.pinned_searches;
    final activity = ref.watch(searchSubscriptionsProvider).valueOrNull;
    final feed = activity?.feeds.where((item) => item.id == feedId).firstOrNull;
    final byId = {
      for (final item
          in activity?.subscriptions ?? const <SearchSubscription>[])
        item.id: item,
    };
    final sources = sortFollowingFeedMembers([
      for (final id in feed?.sourceIds ?? const <String>[])
        if (byId[id] case final SearchSubscription source) source,
    ], ref.watch(followingFeedMemberSortProvider));
    return Scaffold(
      appBar: AppBar(
        title: Text(feed?.name ?? strings.following_feeds),
        actions: [
          if (feed != null)
            PopupMenuButton<FollowingFeedMemberSort>(
              tooltip: context.t.sort.sort_by,
              icon: const Icon(Symbols.sort),
              initialValue: ref.watch(followingFeedMemberSortProvider),
              onSelected: (sort) async {
                final saved = await ref
                    .read(followingFeedMemberSortProvider.notifier)
                    .select(sort);
                if (!saved && context.mounted) _showFailure(context);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: FollowingFeedMemberSort.addedDate,
                  child: Text(strings.sort_feed_added_date),
                ),
                PopupMenuItem(
                  value: FollowingFeedMemberSort.newestFirst,
                  child: Text(strings.sort_feed_newest_first),
                ),
                PopupMenuItem(
                  value: FollowingFeedMemberSort.lastRefresh,
                  child: Text(strings.sort_feed_last_refresh),
                ),
                PopupMenuItem(
                  value: FollowingFeedMemberSort.oldestFirst,
                  child: Text(strings.sort_feed_oldest_first),
                ),
              ],
            ),
          if (feed != null)
            IconButton(
              tooltip: strings.bulk_add,
              icon: const Icon(Symbols.playlist_add),
              onPressed: () => _bulkAdd(context, ref, feed),
            ),
          if (feed != null)
            IconButton(
              tooltip: strings.rename,
              icon: const Icon(Symbols.edit),
              onPressed: () => _rename(context, ref, feed),
            ),
        ],
      ),
      body: feed == null
          ? Center(child: Text(strings.feeds_empty))
          : ListView(
              children: [
                for (final source in sources)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FollowingFeedMemberCard(
                      key: ValueKey(source.id),
                      feed: feed,
                      source: source,
                      refreshing:
                          activity?.refreshingIds.contains(source.id) ?? false,
                      onOpen: () => _open(context, ref, feed, source),
                      onAction: (action) =>
                          _memberAction(context, ref, feed, source, action),
                    ),
                  ),
              ],
            ),
    );
  }

  void _showFailure(BuildContext context) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.pinned_searches.operation_failed)),
      );

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    SearchFollowingFeed feed,
    SearchSubscription source,
  ) async {
    try {
      final owner = ref
          .read(booruConfigProvider)
          .where((p) => p.id == source.profileId && p.id == feed.profileId)
          .firstOrNull;
      if (owner == null) return;
      await ref.read(searchSubscriptionsProvider.notifier).markRead(source.id);
      if (!context.mounted ||
          !ref.read(booruConfigProvider).any((p) => p.id == owner.id)) {
        return;
      }
      await ref.read(currentBooruConfigProvider.notifier).update(owner);
      if (context.mounted) goToSearchPage(ref, tag: source.query);
    } catch (_) {
      if (context.mounted) _showFailure(context);
    }
  }

  Future<void> _memberAction(
    BuildContext context,
    WidgetRef ref,
    SearchFollowingFeed feed,
    SearchSubscription source,
    PinnedSearchAction action,
  ) async {
    final notifier = ref.read(searchSubscriptionsProvider.notifier);
    try {
      switch (action) {
        case PinnedSearchAction.refresh:
          final result = await notifier.refresh(source.id);
          if (context.mounted && result is SearchRefreshDeferred) {
            Kurumi.showErrorToast(
              context,
              rateLimitWaitText(context, result.retryAt),
            );
          }
        case PinnedSearchAction.edit:
          final profiles = ref.read(booruConfigProvider);
          final owner = profiles
              .where((p) => p.id == source.profileId && p.id == feed.profileId)
              .firstOrNull;
          if (owner == null) return;
          final shared =
              (ref
                      .read(searchSubscriptionsProvider)
                      .valueOrNull
                      ?.feeds
                      .where((f) => f.sourceIds.contains(source.id))
                      .length ??
                  0) >
              1;
          await showEditFeedMemberNameDialog(
            context,
            source: source,
            ownerCaption: pinnedSearchProfileCaption(owner, profiles),
            shared: shared,
            onSave: (name) => notifier.renameFeedMember(
              feedId: feed.id,
              source: source,
              name: name,
            ),
          );
        case PinnedSearchAction.delete:
          await notifier.setFeedFollowing(
            feedId: feed.id,
            profileId: feed.profileId,
            query: source.query,
            following: false,
          );
          if (feed.sourceIds.length == 1 && context.mounted) {
            Navigator.pop(context);
          }
        case PinnedSearchAction.info:
          await showDialog<void>(
            context: context,
            builder: (_) => PinnedSearchInfoDialog(
              subscriptionId: source.id,
              feedSource: true,
            ),
          );
          return;
        case PinnedSearchAction.rename:
        case PinnedSearchAction.moveUp:
        case PinnedSearchAction.moveDown:
        case PinnedSearchAction.moveFolder:
          return;
      }
    } catch (_) {
      if (context.mounted) _showFailure(context);
    }
  }

  Future<void> _bulkAdd(
    BuildContext context,
    WidgetRef ref,
    SearchFollowingFeed feed,
  ) async {
    final count = await showBulkSearchImportDialog(
      context,
      destination: feed.name,
      onAdd: (_, queries) => ref
          .read(searchSubscriptionsProvider.notifier)
          .bulkAddToFeed(feedId: feed.id, rawQueries: queries),
    );
    if (count == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t.pinned_searches.bulk_added.replaceAll('{count}', '$count'),
        ),
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    SearchFollowingFeed feed,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _FeedNameDialog(initialName: feed.name),
    );
    if (name == null || !context.mounted) return;
    final byId = {
      for (final search
          in ref.read(searchSubscriptionsProvider).valueOrNull?.subscriptions ??
              const <SearchSubscription>[])
        search.id: search,
    };
    try {
      await ref
          .read(searchSubscriptionsProvider.notifier)
          .saveFeed(
            profileId: feed.profileId,
            name: name,
            queries: [
              for (final id in feed.sourceIds)
                if (byId[id] case final search?) search.query,
            ],
            id: feed.id,
          );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.pinned_searches.operation_failed)),
        );
      }
    }
  }
}

class _FeedNameDialog extends StatefulWidget {
  const _FeedNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_FeedNameDialog> createState() => _FeedNameDialogState();
}

class _FeedNameDialogState extends State<_FeedNameDialog> {
  late final _name = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.t.pinned_searches.rename),
    content: TextField(
      controller: _name,
      decoration: InputDecoration(
        labelText: context.t.pinned_searches.feed_name,
      ),
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.t.generic.action.cancel),
      ),
      TextButton(
        onPressed: _name.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _name.text.trim()),
        child: Text(context.t.generic.action.save),
      ),
    ],
  );
}
