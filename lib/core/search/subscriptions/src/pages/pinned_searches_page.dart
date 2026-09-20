// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../search/routes.dart';
import '../../../selected_tags/types.dart';
import '../data/providers.dart';
import '../providers/search_subscription_selectors.dart';
import '../providers/search_subscriptions_notifier.dart';
import '../types/search_subscription.dart';
import '../widgets/pin_search_dialog.dart';
import '../widgets/pinned_search_card.dart';

class PinnedSearchesPage extends ConsumerStatefulWidget {
  const PinnedSearchesPage({super.key});

  @override
  ConsumerState<PinnedSearchesPage> createState() => _PinnedSearchesPageState();
}

class _PinnedSearchesPageState extends ConsumerState<PinnedSearchesPage> {
  final _openingIds = <String>{};
  final _pendingBatchProfiles = <int>{};

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfig;
    final supported = ref.watch(
      pinnedSearchTrackingSupportedProvider(config.auth),
    );
    final searches = ref.watch(profilePinnedSearchesProvider(config.id));
    final activity = ref.watch(searchSubscriptionsProvider).valueOrNull;
    final batchRunning =
        activity?.batchProfileId == config.id &&
        activity!.batchCompleted < activity.batchTotal;
    final strings = context.t.pinned_searches;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.title),
        actions: [
          IconButton(
            tooltip: strings.refresh_all,
            icon: const Icon(Symbols.refresh),
            onPressed:
                !supported ||
                    batchRunning ||
                    _pendingBatchProfiles.contains(config.id) ||
                    (searches.valueOrNull?.isEmpty ?? true)
                ? null
                : () => _refreshAll(config.id),
          ),
        ],
      ),
      body: !supported
          ? Center(child: Text(strings.profile_unsupported))
          : searches.when(
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
              data: (items) => items.isEmpty
                  ? Center(child: Text(strings.empty))
                  : Column(
                      children: [
                        if (batchRunning) ...[
                          LinearProgressIndicator(
                            value:
                                activity.batchCompleted / activity.batchTotal,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              strings.refreshing_progress
                                  .replaceAll(
                                    '{completed}',
                                    '${activity.batchCompleted}',
                                  )
                                  .replaceAll(
                                    '{total}',
                                    '${activity.batchTotal}',
                                  ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: ReorderableListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: items.length,
                            onReorderItem: (oldIndex, newIndex) => _runAction(
                              () => ref
                                  .read(searchSubscriptionsProvider.notifier)
                                  .reorder(
                                    config.id,
                                    oldIndex,
                                    newIndex,
                                  ),
                            ),
                            itemBuilder: (context, index) {
                              final subscription = items[index];
                              return PinnedSearchCard(
                                key: ValueKey(subscription.id),
                                subscription: subscription,
                                config: config.auth,
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
                                    _onAction(action, subscription, index),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }

  Future<void> _open(SearchSubscription subscription) async {
    setState(() => _openingIds.add(subscription.id));
    try {
      await ref
          .read(searchSubscriptionsProvider.notifier)
          .markRead(subscription.id);
      if (!mounted || ref.readConfig.id != subscription.profileId) return;
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

  Future<void> _refreshAll(int profileId) async {
    setState(() => _pendingBatchProfiles.add(profileId));
    try {
      await _runAction(
        () => ref
            .read(searchSubscriptionsProvider.notifier)
            .refreshAll(profileId),
      );
    } finally {
      if (mounted) setState(() => _pendingBatchProfiles.remove(profileId));
    }
  }

  Future<void> _onAction(
    PinnedSearchAction action,
    SearchSubscription subscription,
    int index,
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
              .reorder(
                subscription.profileId,
                index,
                index + (action == PinnedSearchAction.moveUp ? -1 : 1),
              ),
        );
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
