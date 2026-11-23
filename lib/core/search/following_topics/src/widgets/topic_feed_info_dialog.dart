import '../providers/search_refresh_coordinator.dart';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';

import '../providers/following_topics_notifier.dart';
import '../providers/following_topic_config_provider.dart';
import 'search_refresh_error_text.dart';
import 'feed_last_checked.dart';

typedef _FeedProgress = ({int checked, int total})?;

_FeedProgress _progressForFeed(FollowingTopicsState? state, String feedId) {
  if (state == null) return null;
  final feed = state.feeds.firstWhereOrNull((feed) => feed.id == feedId);
  if (feed == null) return null;
  if (state.refreshingFeedId == feedId) {
    return (checked: state.feedRefreshChecked, total: state.feedRefreshTotal);
  }
  for (final pass in state.refreshPasses) {
    final planned = feed.sourceIds.where(pass.planned.contains).toList();
    if (planned.isEmpty) continue;
    final waiting = planned.where(pass.pending.contains).length;
    if (waiting > 0) {
      return (checked: planned.length - waiting, total: planned.length);
    }
  }
  return null;
}

String _progressLabel(BuildContext context, int checked, int total) => context
    .t
    .following_topics
    .feed_refresh_progress
    .replaceAll('{checked}', '$checked')
    .replaceAll('{total}', '$total')
    .replaceAll('{remaining}', '${total - checked}');

class FeedStatusAction extends ConsumerWidget {
  const FeedStatusAction({
    required this.feedId,
    required this.allowRefresh,
    this.incompleteHistory = false,
    super.key,
  });

  final String feedId;
  final bool allowRefresh;
  final bool incompleteHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(
      followingTopicsProvider.select(
        (state) => _progressForFeed(state.valueOrNull, feedId),
      ),
    );
    final entries = ref.watch(
      followingTopicsProvider.select((value) {
        final state = value.valueOrNull;
        final feed = state?.feeds.firstWhereOrNull((feed) => feed.id == feedId);
        return (
          ids: feed?.sourceIds ?? const <String>[],
          errors:
              state?.topics.any(
                (topic) =>
                    (feed?.sourceIds.contains(topic.id) ?? false) &&
                    topic.lastErrorKind != null,
              ) ??
              false,
        );
      }),
    );
    final unavailable = entries.ids
        .map(
          (id) => ref.watch(followingTopicConfigProvider(id)),
        )
        .any((config) => config == null);
    final deferred = ref.watch(
      searchRefreshStatusProvider.select(
        (status) => entries.ids.any(status.deferredUntilById.containsKey),
      ),
    );
    final warning =
        entries.errors || unavailable || deferred || incompleteHistory;
    final strings = context.t.following_topics;
    return IconButton(
      key: const ValueKey('feed-status-action'),
      tooltip: progress == null
          ? (warning ? strings.some_topics_unavailable : strings.feed_info)
          : progress.total > 0
          ? _progressLabel(context, progress.checked, progress.total)
          : strings.refresh,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => TopicFeedInfoDialog(
          feedId: feedId,
          allowRefresh: allowRefresh,
          incompleteHistory: incompleteHistory,
        ),
      ),
      icon: SizedBox.square(
        dimension: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (progress != null)
              Positioned.fill(
                child: CircularProgressIndicator(
                  key: const ValueKey('feed-refresh-ring'),
                  strokeWidth: 2,
                  value: progress.total > 0
                      ? (progress.checked / progress.total)
                            .clamp(0, 1)
                            .toDouble()
                      : null,
                ),
              ),
            if (warning || progress == null)
              Icon(
                warning ? Icons.warning_amber_rounded : Icons.info_outline,
                size: progress == null ? 22 : 14,
                color: warning ? Theme.of(context).colorScheme.error : null,
              ),
          ],
        ),
      ),
    );
  }
}

class TopicFeedInfoDialog extends ConsumerWidget {
  const TopicFeedInfoDialog({
    required this.feedId,
    this.allowRefresh = false,
    this.incompleteHistory = false,
    super.key,
  });

  final String feedId;
  final bool allowRefresh;
  final bool incompleteHistory;

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
    final progress = _progressForFeed(state, feedId);
    final deferred = ref.watch(searchRefreshStatusProvider).deferredUntilById;
    final unavailableIds = ids
        .where(
          (id) => ref.watch(followingTopicConfigProvider(id)) == null,
        )
        .toSet();
    final enabled =
        state?.organization.folders
            .firstWhereOrNull((folder) => folder.id == feedId)
            ?.feedEnabled ??
        true;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final availableHeight =
        (viewportHeight - MediaQuery.viewInsetsOf(context).vertical - 32)
            .clamp(120, 800)
            .toDouble();
    return KurumiDialog(
      height: availableHeight,
      width: 460,
      screenInset: 16,
      semanticLabel: strings.feed_info,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.feed_info,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (feed == null)
                    Text(strings.feeds_empty)
                  else ...[
                    const SizedBox(height: 12),
                    Text(feed.name),
                    Text(
                      strings.feed_freshness
                          .replaceAll('{checked}', '$checked')
                          .replaceAll('{total}', '${ids.length}')
                          .replaceAll('{failed}', '$failed'),
                    ),
                    if (progress case (checked: final done, total: final total)
                        when total > 0)
                      Text(_progressLabel(context, done, total)),
                    if (incompleteHistory || unavailableIds.isNotEmpty)
                      Text(strings.some_topics_unavailable),
                    for (final source in sources)
                      if (unavailableIds.contains(source.id) ||
                          source.lastErrorKind != null ||
                          deferred.containsKey(source.id))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(source.name ?? source.query),
                          subtitle: Text(
                            unavailableIds.contains(source.id)
                                ? strings.some_topics_unavailable
                                : deferred.containsKey(source.id)
                                ? strings.error_rate_limited
                                : searchRefreshErrorText(
                                    context,
                                    source.lastErrorKind!,
                                  ),
                          ),
                        ),
                    FeedLastChecked(checkedAt: dates.firstOrNull),
                  ],
                ],
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              if (allowRefresh &&
                  enabled &&
                  progress == null &&
                  sources.any(
                    (source) =>
                        !unavailableIds.contains(source.id) &&
                        !deferred.containsKey(source.id) &&
                        source.lastErrorKind != null,
                  ))
                TextButton(
                  onPressed: () async {
                    final notifier = ref.read(
                      followingTopicsProvider.notifier,
                    );
                    for (final source in sources) {
                      if (source.lastErrorKind == null ||
                          unavailableIds.contains(source.id) ||
                          deferred.containsKey(source.id))
                        continue;
                      if (!context.mounted) return;
                      await notifier.refresh(
                        source.id,
                        canStart: () {
                          if (!context.mounted) return false;
                          final current = ref
                              .read(followingTopicsProvider)
                              .valueOrNull;
                          return current?.feeds.any(
                                    (f) =>
                                        f.id == feedId &&
                                        f.sourceIds.contains(source.id),
                                  ) ==
                                  true &&
                              (current?.organization.folders
                                      .firstWhereOrNull((f) => f.id == feedId)
                                      ?.feedEnabled ??
                                  true) &&
                              ref.read(
                                    followingTopicConfigProvider(source.id),
                                  ) !=
                                  null;
                        },
                      );
                    }
                  },
                  child: Text(context.t.generic.action.retry),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.t.generic.action.ok),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
