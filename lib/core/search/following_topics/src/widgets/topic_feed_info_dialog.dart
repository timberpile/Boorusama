import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../providers/following_topics_notifier.dart';
import '../types/search_refresh.dart';
import 'feed_last_checked.dart';

class TopicFeedInfoDialog extends ConsumerWidget {
  const TopicFeedInfoDialog({required this.feedId, super.key});

  final String feedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.t.following_topics;
    final state = ref.watch(followingTopicsProvider).valueOrNull;
    final feed = state?.feeds.firstWhereOrNull((feed) => feed.id == feedId);
    final ids = feed?.sourceIds.toSet() ?? const <String>{};
    final sources =
        state?.topics.where((s) => ids.contains(s.id)).toList() ?? [];
    final checked = sources.where((s) => s.hasBaseline).length;
    final failed = sources.where((s) => s.lastErrorKind != null).length;
    final dates =
        sources
            .map((s) => s.lastSuccessfulCheckAt)
            .whereType<DateTime>()
            .toList()
          ..sort();
    return AlertDialog(
      title: Text(strings.feed_info),
      scrollable: true,
      content: feed == null
          ? Text(strings.feeds_empty)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feed.name),
                const SizedBox(height: 16),
                Text(
                  strings.feed_freshness
                      .replaceAll('{checked}', '$checked')
                      .replaceAll('{total}', '${ids.length}')
                      .replaceAll('{failed}', '$failed'),
                ),
                if (sources.any(
                  (s) => s.lastErrorKind == SearchRefreshErrorKind.rateLimited,
                ))
                  Text(
                    strings.error_rate_limited,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FeedLastChecked(checkedAt: dates.firstOrNull),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t.generic.action.ok),
        ),
      ],
    );
  }
}
