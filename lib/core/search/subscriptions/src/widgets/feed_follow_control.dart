import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../providers/search_subscription_selectors.dart';
import '../providers/search_subscriptions_notifier.dart';
import '../types/search_following_feed.dart';
import '../types/search_subscription.dart';

List<SearchFollowingFeed> followedFeedsForQuery(
  SearchSubscriptionsState state,
  int profileId,
  String query,
) {
  final identity = normalizeSearchIdentity(query);
  final matchingIds = {
    for (final search in state.subscriptions)
      if (search.profileId == profileId &&
          normalizeSearchIdentity(search.query) == identity)
        search.id,
  };
  return [
    for (final feed in state.feeds)
      if (feed.profileId == profileId &&
          feed.sourceIds.any(matchingIds.contains))
        feed,
  ];
}

class FeedFollowButton extends ConsumerWidget {
  const FeedFollowButton({
    required this.query,
    super.key,
  });

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.trim().isEmpty) return const SizedBox.shrink();
    final config = ref.watchConfig;
    final supported = ref.watch(
      pinnedSearchTrackingSupportedProvider(config.auth),
    );
    final state = ref.watch(searchSubscriptionsProvider).valueOrNull;
    final count = state == null
        ? 0
        : followedFeedsForQuery(state, config.id, query).length;
    final strings = context.t.pinned_searches;
    final icon = Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: Icon(Symbols.rss_feed, fill: count > 0 ? 1 : 0),
    );
    final action = supported && state != null
        ? () => showFeedMembershipPicker(
            context,
            profileId: config.id,
            query: query,
          )
        : null;
    return TextButton.icon(
      onPressed: action,
      icon: icon,
      label: Text(count > 0 ? strings.following : strings.follow),
    );
  }
}

Future<void> showFeedMembershipPicker(
  BuildContext context, {
  required int profileId,
  required String query,
}) => showDialog<void>(
  context: context,
  builder: (_) => _FeedMembershipDialog(profileId: profileId, query: query),
);

class _FeedMembershipDialog extends ConsumerStatefulWidget {
  const _FeedMembershipDialog({required this.profileId, required this.query});

  final int profileId;
  final String query;

  @override
  ConsumerState<_FeedMembershipDialog> createState() =>
      _FeedMembershipDialogState();
}

class _FeedMembershipDialogState extends ConsumerState<_FeedMembershipDialog> {
  final _name = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _setFollowed(SearchFollowingFeed feed, bool following) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notifier = ref.read(searchSubscriptionsProvider.notifier);
      final updated = await notifier.setFeedFollowing(
        feedId: feed.id,
        profileId: widget.profileId,
        query: widget.query,
        following: following,
      );
      if (following && updated != null) {
        final existingIds = feed.sourceIds.toSet();
        for (final id in updated.sourceIds.where(
          (id) => !existingIds.contains(id),
        )) {
          unawaited(notifier.refresh(id));
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.t.pinned_searches.operation_failed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notifier = ref.read(searchSubscriptionsProvider.notifier);
      final feed = await notifier.saveFeed(
        profileId: widget.profileId,
        name: _name.text,
        queries: [widget.query],
      );
      _name.clear();
      for (final id in feed.sourceIds) {
        unawaited(notifier.refresh(id));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.t.pinned_searches.operation_failed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.pinned_searches;
    final state = ref.watch(searchSubscriptionsProvider).valueOrNull;
    final feeds =
        state?.feeds
            .where((feed) => feed.profileId == widget.profileId)
            .toList() ??
        const <SearchFollowingFeed>[];
    final followed = state == null
        ? const <SearchFollowingFeed>[]
        : followedFeedsForQuery(state, widget.profileId, widget.query);
    return AlertDialog(
      title: Text(strings.add_to_feed),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final feed in feeds)
                CheckboxListTile(
                  title: Text(feed.name),
                  value: followed.any((item) => item.id == feed.id),
                  onChanged: _busy
                      ? null
                      : (value) => _setFollowed(feed, value ?? false),
                ),
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: strings.feed_name),
                onChanged: (_) => setState(() {}),
              ),
              if (_error case final error?)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy || _name.text.trim().isEmpty ? null : _create,
          child: Text(strings.create_feed),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(context.t.generic.done),
        ),
      ],
    );
  }
}
