import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../configs/manage/providers.dart';
import '../../../search/routes.dart';
import '../providers/search_subscriptions_notifier.dart';
import '../types/search_following_feed.dart';
import '../types/search_subscription.dart';

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
    final sources = [
      for (final id in feed?.sourceIds ?? const <String>[])
        if (byId[id] case final SearchSubscription source) source,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(feed?.name ?? strings.following_feeds),
        actions: [
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
                  ListTile(
                    title: Text(source.query),
                    subtitle: Text(
                      source.lastErrorKind == null
                          ? source.lastSuccessfulCheckAt
                                    ?.toLocal()
                                    .toString() ??
                                strings.never_checked
                          : strings.error_other,
                    ),
                    leading: Badge(
                      isLabelVisible: source.hasNewPosts,
                      child: const Icon(Symbols.search),
                    ),
                    onTap: () async {
                      await ref
                          .read(searchSubscriptionsProvider.notifier)
                          .markRead(source.id);
                      final config = ref
                          .read(booruConfigProvider)
                          .where((item) => item.id == feed.profileId)
                          .firstOrNull;
                      if (config == null || !context.mounted) return;
                      await ref
                          .read(currentBooruConfigProvider.notifier)
                          .update(config);
                      if (context.mounted) {
                        goToSearchPage(ref, tag: source.query);
                      }
                    },
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        final notifier = ref.read(
                          searchSubscriptionsProvider.notifier,
                        );
                        try {
                          if (action == 'refresh') {
                            await notifier.refresh(source.id);
                          } else {
                            await notifier.setFeedFollowing(
                              feedId: feed.id,
                              profileId: feed.profileId,
                              query: source.query,
                              following: false,
                            );
                            if (feed.sourceIds.length == 1 && context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(strings.operation_failed)),
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'refresh',
                          child: Text(strings.refresh),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(context.t.generic.action.delete),
                        ),
                      ],
                    ),
                  ),
              ],
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
