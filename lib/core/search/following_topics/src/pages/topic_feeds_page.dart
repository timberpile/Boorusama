import '../../../../configs/config/providers.dart';
import '../../../../content/content_access.dart';
import '../../../../content/content_access_provider.dart';
import '../widgets/following_definition_entry.dart';
import '../types/following_mirror_state.dart';
import '../providers/following_topic_config_provider.dart';
import '../../../../backups/mitemite/protocol.dart' show SyncCollectionId;
import '../../../../backups/mitemite/collection_alias_ui.dart';
import '../../../../backups/mitemite/following_actions.dart';
import '../../../../backups/mitemite/providers.dart';

import 'package:foundation/performance.dart';

import '../../../../../foundation/performance/performance_navigation.dart';

import 'dart:async';
import 'dart:developer' show Timeline;

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:selection_mode/selection_mode.dart';

import '../../../../configs/config/types.dart';
import '../../../../widgets/popup_menu_action_label.dart';
import '../../../../configs/manage/widgets.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../../boorus/booru/types.dart';
import '../../../../errors/types.dart';
import '../../../../posts/details/routes.dart';
import '../../../../posts/listing/widgets.dart';
import '../../../../posts/listing/src/widgets/timeline_header_sliver.dart';
import '../../../../posts/listing/providers.dart';
import '../../../../posts/listing/src/types/page_mode.dart';
import '../../../../posts/post/types.dart';
import '../../../../posts/post/providers.dart';
import '../../../../router.dart';
import '../../../../navigation/destination_activity.dart';
import '../../../../navigation/destination_profile_scope.dart';
import '../refresh/search_refresh_query_adapter.dart';
import '../services/feed_history_session.dart';
import '../services/feed_display_snapshot.dart';
import '../services/feed_history_end_policy.dart';
import '../providers/following_topics_notifier.dart';
import '../providers/search_refresh_coordinator.dart';
import '../types/topic_feed.dart';
import '../types/feed_series_membership.dart';
import '../services/feed_series_enrichment.dart';
import '../../../../bookmarks/src/providers/pool_bookmark_provider.dart';
import '../../../../bookmarks/src/types/pool_bookmark_capability.dart';
import '../../../../posts/listing/src/widgets/grouped_post_grid.dart';
import '../../../../posts/details/src/routes/viewer_navigation_scope.dart';
import '../types/cached_topic_feed_filter.dart';
import '../widgets/cached_feed_filter_bar.dart';
import '../types/topic_organization.dart';
import '../types/following_topic.dart';
import '../types/following_topic_sort.dart';
import '../types/search_refresh.dart';
import '../widgets/feed_post_thumbnail.dart';
import '../widgets/feed_last_checked.dart';
import '../widgets/topic_feed_info_dialog.dart';
import '../widgets/following_topic_card.dart';
import '../widgets/search_folder_dialog.dart';
import 'topic_feed_management_page.dart';

class TopicFeedsPage extends ConsumerStatefulWidget {
  const TopicFeedsPage({super.key});

  @override
  ConsumerState<TopicFeedsPage> createState() => _TopicFeedsPageState();
}

class _TopicFeedsPageState extends ConsumerState<TopicFeedsPage>
    with RouteAware {
  late final SearchRefreshCoordinator _coordinator;
  late final RouteObserver<ModalRoute<dynamic>> _routeObserver;
  FeedInitializationInterest? _feedInterest;

  @override
  void initState() {
    super.initState();
    _coordinator = ref.read(searchRefreshCoordinatorProvider.notifier);
    _routeObserver = ref.read(currentDestinationRouteObserverProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _activate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) _routeObserver.subscribe(this, route);
    final active = NavigationActivity.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (active && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _activate();
      } else {
        _deactivate();
      }
    });
  }

  void _activate() {
    if (!NavigationActivity.of(context) ||
        !(ModalRoute.of(context)?.isCurrent ?? true))
      return;
    _feedInterest ??= _coordinator.acquireFeedInitializationInterest();
  }

  void _deactivate() {
    _feedInterest?.close();
    _feedInterest = null;
  }

  @override
  void didPush() => _activate();

  @override
  void didPopNext() => _activate();

  @override
  void didPushNext() => _deactivate();

  @override
  void didPop() => _deactivate();

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    _deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(orderedProfileConfigsProvider);
    final byProfileId = {for (final profile in profiles) profile.id: profile};
    final strings = context.t.following_topics;
    return PerformanceScreenScope(
      screen: PerfScreen.topicFeeds,
      priority: 2,
      child: Scaffold(
        appBar: KurumiAppBar(
          title: Text(strings.topic_feeds),
        ),
        body: ref
            .watch(followingTopicsProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(child: Text(strings.load_failed)),
              data: (state) {
                final aliases = state.mirrors.owners.isEmpty
                    ? const <SyncCollectionId, String>{}
                    : ref.watch(syncCollectionAliasesProvider);
                final feeds = state.feeds
                    .where((feed) => byProfileId.containsKey(feed.profileId))
                    .toList();
                final newSearchIds = {
                  for (final search in state.topics)
                    if (search.hasNewPosts) search.id,
                };
                if (feeds.isEmpty) {
                  return Center(child: Text(strings.feeds_empty));
                }
                return ListView(
                  children: [
                    for (final feed in feeds)
                      Builder(
                        builder: (context) {
                          final config = byProfileId[feed.profileId]!;
                          final caption = config.name.isEmpty
                              ? config.url
                              : profiles
                                        .where(
                                          (profile) =>
                                              profile.name == config.name,
                                        )
                                        .length ==
                                    1
                              ? config.name
                              : '${config.name} · ${config.url}';
                          final hasNew = feed.sourceIds.any(
                            newSearchIds.contains,
                          );
                          final rateLimited = state.topics.any(
                            (search) =>
                                feed.sourceIds.contains(search.id) &&
                                search.lastErrorKind ==
                                    SearchRefreshErrorKind.rateLimited,
                          );
                          final siblings = feeds
                              .where((f) => f.profileId == feed.profileId)
                              .toList();
                          final index = siblings.indexWhere(
                            (f) => f.id == feed.id,
                          );
                          final sources = state.topics
                              .where((s) => feed.sourceIds.contains(s.id))
                              .toList();
                          final dates = <DateTime>[
                            ...feed.posts
                                .map(feedPostCreatedAt)
                                .whereType<DateTime>(),
                            ...sources
                                .map((s) => s.lastPostAt)
                                .whereType<DateTime>(),
                          ]..sort();
                          final overflow = PopupMenuButton<String>(
                            icon: const Icon(Symbols.more_vert),
                            tooltip: context.t.generic.action.more,
                            onSelected: (action) async {
                              if (action == 'refresh') {
                                await _refreshFeed(context, ref, feed.id);
                                return;
                              }
                              if (action == 'info') {
                                await showDialog<void>(
                                  context: context,
                                  builder: (_) =>
                                      TopicFeedInfoDialog(feedId: feed.id),
                                );
                                return;
                              }
                              if (action == 'up' || action == 'down') {
                                await _feedAction(
                                  context,
                                  () => ref
                                      .read(
                                        followingTopicsProvider.notifier,
                                      )
                                      .moveFeed(feed.id, up: action == 'up'),
                                );
                                return;
                              }
                              if (action == 'edit') {
                                if (DestinationScope.maybeOf(context) != null) {
                                  await ref.pushNamedRoute<void>(
                                    '/following-topics/feed/edit',
                                    pathParameters: {'feedId': feed.id},
                                    queryParameters: {
                                      '_profile': feed.profileId,
                                    },
                                  );
                                  return;
                                }
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => TopicFeedManagementPage(
                                      feedId: feed.id,
                                    ),
                                  ),
                                );
                                return;
                              }
                              final accepted = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(strings.delete_feed),
                                  content: Text(
                                    strings.delete_feed_confirmation,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(
                                        context.t.generic.action.cancel,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(
                                        context.t.generic.action.delete,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if ((accepted ?? false) && context.mounted) {
                                await _feedAction(
                                  context,
                                  () => ref
                                      .read(
                                        followingTopicsProvider.notifier,
                                      )
                                      .deleteFeed(feed.id),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'refresh',
                                enabled: state.refreshingFeedId == null,
                                child: PopupMenuActionLabel(
                                  icon: Icons.refresh,
                                  label: strings.refresh,
                                ),
                              ),
                              PopupMenuItem(
                                value: 'info',
                                child: PopupMenuActionLabel(
                                  icon: Icons.info_outline,
                                  label: strings.feed_info,
                                ),
                              ),
                              if (!state.mirrors.isReceived(feed.id))
                                PopupMenuItem(
                                  value: 'up',
                                  enabled: index > 0,
                                  child: PopupMenuActionLabel(
                                    icon: Icons.arrow_upward,
                                    label: strings.move_up,
                                  ),
                                ),
                              if (!state.mirrors.isReceived(feed.id))
                                PopupMenuItem(
                                  value: 'down',
                                  enabled: index < siblings.length - 1,
                                  child: PopupMenuActionLabel(
                                    icon: Icons.arrow_downward,
                                    label: strings.move_down,
                                  ),
                                ),
                              if (!state.mirrors.isReceived(feed.id))
                                PopupMenuItem(
                                  value: 'edit',
                                  child: PopupMenuActionLabel(
                                    icon: Icons.edit_outlined,
                                    label: context.t.generic.action.edit,
                                  ),
                                ),
                              if (!state.mirrors.isReceived(feed.id))
                                PopupMenuItem(
                                  value: 'delete',
                                  child: PopupMenuActionLabel(
                                    icon: Icons.delete_outline,
                                    label: context.t.generic.action.delete,
                                  ),
                                ),
                            ],
                          );
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _feedAction(context, () async {
                                if (DestinationScope.maybeOf(context) != null) {
                                  await ref.pushNamedRoute<void>(
                                    '/following-topics/feed',
                                    pathParameters: {'feedId': feed.id},
                                    queryParameters: {
                                      '_profile': feed.profileId,
                                    },
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
                              }),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            followingAliasLabel(
                                              feed.name,
                                              feed.id,
                                              state.mirrors,
                                              aliases,
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                        ),
                                        if (hasNew)
                                          Semantics(
                                            label: strings.new_posts,
                                            excludeSemantics: true,
                                            child: Badge(
                                              label: Text(strings.new_badge),
                                            ),
                                          ),
                                        overflow,
                                      ],
                                    ),
                                    if (feed.posts.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            for (final post in feed.posts.take(
                                              4,
                                            ))
                                              Expanded(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    2,
                                                  ),
                                                  child: AspectRatio(
                                                    aspectRatio: 1,
                                                    child: FeedPostThumbnail(
                                                      post: _decodeFeedPost(
                                                        ref,
                                                        post,
                                                        config,
                                                      ),
                                                      config: config.auth,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            for (
                                              var i = feed.posts.length;
                                              i < 4;
                                              i++
                                            )
                                              const Spacer(),
                                          ],
                                        ),
                                      ),
                                    FollowingTopicCardMetadata(
                                      leading: caption,
                                      lastPostAt: dates.lastOrNull,
                                      hasBaseline:
                                          sources.isEmpty ||
                                          sources.every((s) => s.hasBaseline),
                                    ),
                                    if (state.refreshingFeedId == feed.id)
                                      const LinearProgressIndicator(),
                                    if (rateLimited)
                                      Text(
                                        strings.error_rate_limited,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
      ),
    );
  }
}

Future<void> _refreshFeed(BuildContext context, WidgetRef ref, String id) =>
    _feedAction(context, () async {
      final results = await ref
          .read(followingTopicsProvider.notifier)
          .refreshFeed(id);
      final deferred = results.whereType<SearchRefreshDeferred>().firstOrNull;
      if (context.mounted && deferred != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(rateLimitWaitText(context, deferred.retryAt))),
        );
      }
    });

Future<void> _feedAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.following_topics.operation_failed)),
      );
    }
  }
}

class TopicFeedPage extends ConsumerStatefulWidget {
  const TopicFeedPage({
    required this.feedId,
    required this.profileId,
    super.key,
  });
  final String feedId;
  final String profileId;
  @override
  ConsumerState<TopicFeedPage> createState() => _TopicFeedPageState();
}

class _TopicFeedPageState extends ConsumerState<TopicFeedPage> with RouteAware {
  late final SearchRefreshCoordinator _coordinator;
  late final RouteObserver<ModalRoute<dynamic>> _routeObserver;
  FeedInitializationInterest? _feedInterest;
  final _gridKey = GlobalKey<_CachedFeedGridState>();
  var _filter = const CachedTopicFeedFilter();
  final _filterBarKey = GlobalKey();
  final _display = FeedDisplaySnapshot();
  final _incompleteHistory = ValueNotifier(false);
  Object? _initialSettlementOwner;
  int? _interestGeneration;

  @override
  void initState() {
    super.initState();
    _coordinator = ref.read(searchRefreshCoordinatorProvider.notifier);
    _routeObserver = ref.read(currentDestinationRouteObserverProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _activate();
      unawaited(
        ref.read(followingTopicsProvider.notifier).markFeedRead(widget.feedId),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) _routeObserver.subscribe(this, route);
    final active = NavigationActivity.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (active && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _activate();
      } else {
        _deactivate();
      }
    });
  }

  void _activate() {
    if (_filter.isActive ||
        !NavigationActivity.of(context) ||
        !(ModalRoute.of(context)?.isCurrent ?? true))
      return;
    final generation = _display.generation;
    if (generation == 0 ||
        _interestGeneration == generation && _feedInterest != null) {
      return;
    }
    _deactivate();
    final interest = _feedInterest = _coordinator
        .acquireFeedInitializationInterest(
          feedId: widget.feedId,
        );
    _interestGeneration = generation;
    final owner = _initialSettlementOwner = Object();
    void settle() {
      if (!mounted ||
          !identical(owner, _initialSettlementOwner) ||
          _display.generation != generation) {
        return;
      }
      setState(() => _display.settleInitialization(generation));
    }

    unawaited(
      interest.initialSettlement.then(
        (_) => settle(),
        onError: (Object _) => settle(),
      ),
    );
  }

  void _filterChanged(CachedTopicFeedFilter filter) {
    if (_filter == filter) return;
    // Stop dispatch immediately, before the next frame can rebuild the grid.
    _gridKey.currentState?.stopHistory();
    if (filter.isActive) _deactivate();
    setState(() => _filter = filter);
    if (!filter.isActive) _activate();
  }

  void _deactivate() {
    _feedInterest?.close();
    _feedInterest = null;
  }

  @override
  void didPush() => _activate();

  @override
  void didPopNext() => _activate();

  @override
  void didPushNext() => _deactivate();

  @override
  void didPop() => _deactivate();

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    _deactivate();
    _incompleteHistory.dispose();
    super.dispose();
  }

  Object _definition(
    TopicFeed? feed,
    FollowingTopicsState state,
  ) {
    final folder = state.organization.folders
        .where((f) => f.id == widget.feedId)
        .firstOrNull;
    final ids = feed?.sourceIds ?? const <String>[];
    return [
      widget.feedId,
      feed?.profileId,
      feed?.cacheGeneration,
      folder?.feedEnabled,
      ids,
      for (final source in state.topics.where((s) => ids.contains(s.id))) ...[
        source.id,
        source.createdAt,
        source.runtimeRevision,
        source.query,
        source.profileId,
        source.localSource,
        source.autoUpdateEnabled,
      ],
    ];
  }

  TopicFeed? _authorizedFeed(
    TopicFeed? feed,
    FollowingTopicsState state, {
    bool watch = true,
  }) {
    if (feed == null) return null;
    return Timeline.timeSync('Following authorize feed rows', () {
      final enabled =
          state.organization.folders
              .where((f) => f.id == feed.id)
              .firstOrNull
              ?.feedEnabled ??
          true;
      final active = <String, BooruConfig>{};
      for (final source in state.topics.where(
        (s) => feed.sourceIds.contains(s.id),
      )) {
        final provider = followingTopicConfigProvider(source.id);
        final config = watch ? ref.watch(provider) : ref.read(provider);
        if (config != null) active[source.id] = config;
      }
      final rows = <StoredPostSnapshot>[];
      for (final snapshot in feed.posts) {
        final provenance = feed.postSources[feedPostIdentity(snapshot)];
        final owners = provenance == null
            ? active.values
            : provenance.map((id) => active[id]).whereType<BooruConfig>();
        if (!enabled || owners.isEmpty) continue;
        final decode = _feedDecodedPostProvider((
          snapshot: snapshot,
          fallback: owners.first,
        ));
        final post = watch ? ref.watch(decode) : ref.read(decode);
        final access = _feedAccessForPost(ref, post, owners, watch: watch);
        if (access == null) continue;
        final visibility = contentPostVisibilityProvider((
          access: access.key,
          post: post,
        ));
        if ((watch ? ref.watch(visibility) : ref.read(visibility))
                .asData
                ?.value ==
            true)
          rows.add(snapshot);
      }
      return feed.copyWith(posts: rows);
    });
  }

  TopicFeed _withCurrentProvenance(TopicFeed accepted, TopicFeed? latest) {
    if (latest == null || identical(accepted, latest)) return accepted;
    final liveIds = latest.posts.map(feedPostIdentity).toSet();
    // A live row whose retained Series facts have been revoked must drop
    // those facts immediately. Rows aged out of the cache keep their snapshot.
    final liveSeriesKeys =
        accepted.seriesMemberships.keys.any(
          (key) => !latest.seriesMemberships.containsKey(key),
        )
        ? {
            for (final row in latest.posts)
              feedSeriesPostKey(
                PostOrigin.fromSnapshot(row.origin),
                feedPostId(row),
              ),
          }
        : const <String>{};
    return accepted.copyWith(
      seriesMemberships: {
        for (final entry in accepted.seriesMemberships.entries)
          if (!liveSeriesKeys.contains(entry.key) ||
              latest.seriesMemberships.containsKey(entry.key))
            entry.key: entry.value,
      },
      postSources: {
        ...accepted.postSources,
        for (final entry in latest.postSources.entries)
          if (liveIds.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  void _showUpdates(Object definition, int generation) {
    final current = ref.read(followingTopicsProvider).valueOrNull;
    if (current == null) return;
    final latest = current.feeds
        .where((feed) => feed.id == widget.feedId)
        .firstOrNull;
    if (latest == null ||
        !const DeepCollectionEquality().equals(
          definition,
          _definition(latest, current),
        ))
      return;
    setState(() {
      final authorized = _authorizedFeed(latest, current, watch: false)!;
      _display.apply(
        authorized,
        expectedGeneration: generation,
        stored: latest,
      );
      if (_filter.sourceHost case final source?
          when !cachedTopicFeedSourceHosts(_display.accepted!.posts)
              .contains(source)) {
        _filter = CachedTopicFeedFilter(
          query: _filter.query,
          sort: _filter.sort,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(
      followingTopicsProvider.select(
        (async) => async.whenData((state) {
          final feed = state.feeds.firstWhereOrNull(
            (feed) => feed.id == widget.feedId,
          );
          final ids = feed?.sourceIds.toSet() ?? const <String>{};
          return FollowingTopicsState(
            topics: state.topics
                .where((topic) => ids.contains(topic.id))
                .toList(),
            feeds: [?feed],
            organization: state.organization,
            mirrors: state.mirrors,
            refreshingIds: const {},
            batchCompleted: 0,
            batchTotal: 0,
          );
        }),
      ),
    );
    final state = asyncState.valueOrNull;
    final latest = state?.feeds.where((f) => f.id == widget.feedId).firstOrNull;
    final config = [
      for (final id in latest?.sourceIds ?? const <String>[])
        ref.watch(followingTopicConfigProvider(id)),
      ...ref
          .watch(orderedProfileConfigsProvider)
          .where((c) => c.id == (latest?.profileId ?? widget.profileId)),
    ].whereType<BooruConfig>().firstOrNull;
    final feedEnabled =
        state?.organization.folders
            .where((folder) => folder.id == widget.feedId)
            .firstOrNull
            ?.feedEnabled ??
        true;
    final folder = state?.organization.folders
        .where((folder) => folder.id == widget.feedId)
        .firstOrNull;
    final isFolderFeed = folder != null;
    final sourceIds = latest?.sourceIds.toSet() ?? const <String>{};
    final sources =
        state?.topics.where((s) => sourceIds.contains(s.id)).toList() ?? [];
    final definition = state == null ? null : _definition(latest, state);
    if (state != null) {
      final previousGeneration = _display.generation;
      final authorized = _authorizedFeed(latest, state);
      _display.observe(authorized, definition: definition!, stored: latest);
      _display.revalidateAccepted(
        (stored) => _authorizedFeed(
          _withCurrentProvenance(stored, latest),
          state,
        )!,
      );
      if (previousGeneration != _display.generation) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _activate();
        });
      }
    }
    final feed = _display.accepted;
    final strings = context.t.following_topics;
    final filterBar = feed != null && config != null
        ? CachedFeedFilterBar(
            key: _filterBarKey,
            snapshots: feed.posts,
            filter: _filter,
            onChanged: _filterChanged,
          )
        : null;
    return FollowingDefinitionEntry(
      ready: feed != null && config != null,
      receipts: {
        for (final source in sources)
          if (ref.watch(followingTopicConfigProvider(source.id)) != null)
            if (state?.mirrors.owners[source.id] case final owner?)
              if (owner.hasDefinitionChange) source.id: owner.definitionDigest,
      },
      child: PerformanceScreenScope(
        screen: PerfScreen.topicFeed,
        priority: 2,
        child: Scaffold(
          appBar: KurumiAppBar(
            backgroundColor: TimelineHeaderSliver.backgroundColorOf(context),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    folder != null && state != null
                        ? followingAliasLabel(
                            folder.name,
                            folder.id,
                            state.mirrors,
                            followingAliasSource(state.mirrors, folder.id) ==
                                    null
                                ? const {}
                                : ref.watch(syncCollectionAliasesProvider),
                          )
                        : feed?.name ?? strings.topic_feeds,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FollowingSyncStatus(
                  readOnly: state?.mirrors.isReceived(widget.feedId) ?? false,
                  published:
                      isFolderFeed &&
                      ref
                          .watch(publishedFollowingRootsProvider)
                          .contains(widget.feedId),
                  changed:
                      state != null &&
                      unseenFollowingTopicDefinitions(
                        state.mirrors,
                        state.organization,
                        widget.feedId,
                      ).isNotEmpty,
                ),
              ],
            ),
            actions: [
              ValueListenableBuilder(
                valueListenable: _incompleteHistory,
                builder: (context, incomplete, _) => FeedStatusAction(
                  feedId: widget.feedId,
                  allowRefresh: !_filter.isActive && feedEnabled,
                  incompleteHistory: incomplete,
                ),
              ),
              if (_latestSuccessfulCheck(sources) case final checkedAt?)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 112),
                    child: Align(
                      alignment: Alignment.centerRight,
                      widthFactor: 1,
                      child: FeedLastChecked(
                        checkedAt: checkedAt,
                        compact: true,
                      ),
                    ),
                  ),
                ),
              Consumer(
                builder: (context, ref, _) {
                  final refreshing = ref.watch(
                    followingTopicsProvider.select(
                      (state) => state.valueOrNull?.refreshingFeedId != null,
                    ),
                  );
                  return KurumiPopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    semanticLabel: context.t.generic.action.more,
                    iconPadding: const EdgeInsets.all(12),
                    items: [
                      if (folder != null && state != null)
                        ...followingSyncMenu(context, ref, state, folder.id),
                      KurumiPopupMenuItem(
                        title: Text(strings.refresh),
                        icon: const Icon(Icons.refresh),
                        onTap:
                            !_filter.isActive &&
                                feedEnabled &&
                                feed != null &&
                                !refreshing
                            ? () => _refreshFeed(context, ref, widget.feedId)
                            : null,
                      ),
                      if (isFolderFeed &&
                          !(state?.mirrors.isReceived(folder.id) ?? false))
                        KurumiPopupMenuItem(
                          title: Text(strings.feed_settings),
                          icon: const Icon(Icons.tune),
                          onTap: () => _editFolderSettings(folder),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: asyncState.isLoading && feed == null
                        ? const Center(child: CircularProgressIndicator())
                        : asyncState.hasError && feed == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(strings.load_failed),
                                TextButton(
                                  onPressed: () =>
                                      ref.invalidate(followingTopicsProvider),
                                  child: Text(context.t.generic.action.retry),
                                ),
                              ],
                            ),
                          )
                        : feed == null || config == null
                        ? Center(
                            child: Text(
                              state?.mirrors.isReceived(widget.feedId) ?? false
                                  ? context.t.mitemite.following_paused
                                  : strings.feeds_empty,
                            ),
                          )
                        : feed.posts.isEmpty
                        ? CustomScrollView(
                            slivers: [
                              if (filterBar != null)
                                TimelineHeaderSliver(child: filterBar),
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Text(
                                    _filter.isActive
                                        ? strings.feed_filter_empty
                                        : strings.feed_posts_empty,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _CachedFeedGrid(
                            key: _gridKey,
                            filter: _filter,
                            filterHeader: filterBar!,
                            feed: feed,
                            config: config,
                            sources: sources,
                            onHistoryIncomplete: (value) {
                              if (mounted) _incompleteHistory.value = value;
                            },
                          ),
                  ),
                ],
              ),
              if (_display.pending != null && config != null && feedEnabled)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 72 + MediaQuery.paddingOf(context).bottom,
                  child: Center(
                    child: FilledButton.icon(
                      key: const ValueKey('feed-show-updates'),
                      onPressed: () =>
                          _showUpdates(definition!, _display.generation),
                      icon: const Icon(Icons.update),
                      label: Text(strings.feed_updates_available),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editFolderSettings(TopicFolder folder) async {
    final organization = ref
        .read(followingTopicsProvider)
        .requireValue
        .organization;
    final settings = await showSearchFolderSettingsDialog(
      context,
      name: folder.name,
      folders: organization.folders,
      parentId: folder.parentId,
      editingFolderId: folder.id,
      feedEnabled: folder.feedEnabled,
      maxPosts: folder.feedMaxPosts,
    );
    if (settings == null || !mounted) return;
    await ref
        .read(followingTopicsProvider.notifier)
        .renameSharedFolder(
          folder.id,
          settings.name,
          parentId: settings.parentId,
          feedEnabled: settings.feedEnabled,
          maxPosts: settings.maxPosts,
        );
  }
}

class _CachedFeedGrid extends ConsumerStatefulWidget {
  const _CachedFeedGrid({
    required this.feed,
    required this.filter,
    required this.filterHeader,
    required this.config,
    required this.sources,
    required this.onHistoryIncomplete,
    super.key,
  });
  final TopicFeed feed;
  final CachedTopicFeedFilter filter;
  final Widget filterHeader;
  final BooruConfig config;
  final List<FollowingTopic> sources;
  final ValueChanged<bool> onHistoryIncomplete;
  @override
  ConsumerState<_CachedFeedGrid> createState() => _CachedFeedGridState();
}

class _CachedFeedGridState extends ConsumerState<_CachedFeedGrid> {
  final _feedScrollController = AutoScrollController();
  PostGridController<Post>? _controller;
  late FeedHistorySession _history;
  late List<StoredPostSnapshot> _filteredSnapshots;
  var _historyGeneration = 0;
  var _groupingSession = Object();
  List<BooruConfig?>? _actors;
  Map<String, FeedSeriesMembership> _series = {};
  var _historyStarted = false;
  var _historyCoverageIncomplete = false;
  var _feedAtEnd = false;
  var _endCheckScheduled = false;
  var _selectionActive = false;
  var _historyReorderScheduled = false;
  var _historyReorderPending = false;

  void _scheduleHistoryReorder() {
    if (_history.recoveryRevision == 0 || _historyReorderScheduled || !mounted)
      return;
    _historyReorderPending = true;
    _historyReorderScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _historyReorderScheduled = false;
      if (!mounted ||
          !_historyReorderPending ||
          _selectionActive ||
          !NavigationActivity.of(context) ||
          !(ModalRoute.of(context)?.isCurrent ?? true))
        return;
      final controller = _controller;
      if (controller == null || controller.loadingMore || controller.refreshing)
        return;
      Post? anchor;
      double? anchorTop;
      final indices = _feedScrollController.tagMap.keys.toList()..sort();
      final rows = controller.items.toList();
      for (final index in indices) {
        final box = _feedScrollController.tagMap[index]?.context
            .findRenderObject();
        if (index >= rows.length || box is! RenderBox || !box.hasSize) continue;
        final top = box.localToGlobal(Offset.zero).dy;
        if (top >= MediaQuery.paddingOf(context).top + kToolbarHeight &&
            top < MediaQuery.sizeOf(context).height) {
          anchor = rows[index];
          anchorTop = top;
          break;
        }
      }
      _historyReorderPending = false;
      final recent = {
        for (final (index, snapshot) in widget.feed.posts.indexed)
          (
            snapshot.origin.booruTypeId,
            snapshot.origin.sourceHost,
            feedPostId(snapshot),
          ): index,
      };
      int compare(Post left, Post right) {
        final a =
            recent[(left.origin.booruType.id, left.origin.sourceHost, left.id)];
        final b =
            recent[(
              right.origin.booruType.id,
              right.origin.sourceHost,
              right.id,
            )];
        if (a != null || b != null)
          return a == null
              ? 1
              : b == null
              ? -1
              : a.compareTo(b);
        return compareFeedHistoryPosts(left, right);
      }

      if (!controller.reorderLoadedItems(compare) ||
          anchor == null ||
          anchorTop == null)
        return;
      final index = controller.items.toList().indexOf(anchor);
      if (index < 0) return;
      final expected = anchor;
      unawaited(() async {
        await _feedScrollController.scrollToIndex(
          index,
          preferPosition: AutoScrollPosition.begin,
          duration: const Duration(milliseconds: 1),
        );
        if (!mounted ||
            _selectionActive ||
            !(ModalRoute.of(context)?.isCurrent ?? true) ||
            !_feedScrollController.hasClients ||
            controller.items.elementAtOrNull(index) != expected)
          return;
        final box = _feedScrollController.tagMap[index]?.context
            .findRenderObject();
        if (box is RenderBox && box.hasSize) {
          final delta = box.localToGlobal(Offset.zero).dy - anchorTop!;
          final position = _feedScrollController.position;
          position.jumpTo(
            (position.pixels + delta).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            ),
          );
        }
      }());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_historyReorderPending) _scheduleHistoryReorder();
  }

  void _scheduleFeedEndCheck() {
    if (_endCheckScheduled) return;
    _endCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _endCheckScheduled = false;
      if (!mounted) return;
      final atEnd =
          _feedScrollController.positions.length == 1 &&
          _feedScrollController.position.hasContentDimensions &&
          _feedScrollController.position.extentAfter <= 48;
      if (atEnd != _feedAtEnd) setState(() => _feedAtEnd = atEnd);
    });
  }

  @override
  void initState() {
    super.initState();
    _feedScrollController.addListener(_scheduleFeedEndCheck);
    _scheduleFeedEndCheck();
    _history = _createHistory();
    _filteredSnapshots = widget.filter.apply(widget.feed.posts);
  }

  @override
  void dispose() {
    _controller?.removeListener(_scheduleHistoryReorder);
    _feedScrollController.dispose();
    _history.dispose();
    super.dispose();
  }

  void stopHistory() {
    _historyGeneration++;
    _history.dispose();
  }

  FeedHistorySession _createHistory() {
    final generation = ++_historyGeneration;
    _series = {...widget.feed.seriesMemberships};
    return FeedHistorySession(
      sources: widget.sources,
      confirmExhaustion: (source, page, result) {
        final owner = ref.read(followingTopicConfigProvider(source.id));
        return owner != null &&
            confirmsFeedHistoryEnd(
              result,
              booruType: owner.auth.booruType,
              siteUrl: owner.url,
              page: page,
              limit: 20,
            );
      },
      onExhausted: (source, end) async {
        await ref
            .read(followingTopicsProvider.notifier)
            .recordHistoryEnd(source, end);
      },
      recent: [
        for (final post in widget.feed.posts)
          _decodeFeedPost(ref, post, widget.config),
      ],
      fetchPage: (source, page) async {
        final owner = ref.read(followingTopicConfigProvider(source.id));
        if (owner == null) throw StateError('Feed source profile unavailable');
        final adapter = ref
            .read(booruRepoProvider(owner.auth))
            ?.searchRefreshQueryAdapter(owner.auth);
        final plan = adapter?.plan(source.query, after: null);
        if (plan case SupportedSearchRefreshQueryPlan(:final query)) {
          final result = await ref
              .read(originAwarePostRepoProvider(owner))
              .getPosts(
                query,
                page,
                limit: 20,
                options: PostFetchOptions.raw,
              )
              .run();
          final posts = result.fold(
            (error) => throw StateError('$error'),
            (posts) => posts,
          );
          bool current() =>
              mounted &&
              generation == _historyGeneration &&
              _historyStarted &&
              !widget.filter.isActive &&
              feedSeriesSameActor(
                ref.read(followingTopicConfigProvider(source.id)),
                owner,
              ) &&
              (ref
                      .read(followingTopicsProvider)
                      .valueOrNull
                      ?.topics
                      .any(
                        (latest) =>
                            latest.id == source.id &&
                            latest.runtimeRevision == source.runtimeRevision,
                      ) ??
                  false);
          var metadata = <String, FeedSeriesMembership>{};
          try {
            metadata = await enrichFeedSeries(
              config: owner,
              source: source,
              posts: posts.posts,
              capability: ref.read(poolBookmarkCapabilityProvider(owner)),
              isCurrent: current,
            );
          } on Object {
            // Metadata resolution is optional; the fetched Post page is valid.
          }
          if (!current()) throw StateError('Feed history source changed');
          _series.addAll(metadata);
          return posts;
        }
        throw StateError('Unsupported feed source');
      },
    );
  }

  @override
  void didUpdateWidget(covariant _CachedFeedGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final filterChanged = oldWidget.filter != widget.filter;
    final sourceDefinitionsChanged = !const DeepCollectionEquality().equals(
      [
        for (final source in oldWidget.sources)
          (
            source.id,
            source.runtimeRevision,
            source.profileId,
            source.query,
            source.createdAt,
          ),
      ],
      [
        for (final source in widget.sources)
          (
            source.id,
            source.runtimeRevision,
            source.profileId,
            source.query,
            source.createdAt,
          ),
      ],
    );
    final sourceStatusChanged = !const DeepCollectionEquality().equals(
      [
        for (final source in oldWidget.sources)
          (
            source.id,
            source.lastAttemptAt,
            source.lastSuccessfulCheckAt,
            source.lastErrorKind,
          ),
      ],
      [
        for (final source in widget.sources)
          (
            source.id,
            source.lastAttemptAt,
            source.lastSuccessfulCheckAt,
            source.lastErrorKind,
          ),
      ],
    );
    final postsChanged = !const ListEquality<StoredPostSnapshot>().equals(
      oldWidget.feed.posts,
      widget.feed.posts,
    );
    final metadataChanged = !const MapEquality<String, FeedSeriesMembership>()
        .equals(
          oldWidget.feed.seriesMemberships,
          widget.feed.seriesMemberships,
        );
    if (filterChanged || postsChanged) {
      _filteredSnapshots = widget.filter.apply(widget.feed.posts);
    }
    if (sourceStatusChanged &&
        _history.coverageIncomplete &&
        !filterChanged &&
        !sourceDefinitionsChanged) {
      _history.allowRecovery();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller?.resumeContinuation();
      });
    }
    if (filterChanged || sourceDefinitionsChanged) _groupingSession = Object();
    if (filterChanged ||
        sourceDefinitionsChanged ||
        postsChanged ||
        metadataChanged) {
      final anchor =
          (postsChanged || metadataChanged) &&
              !filterChanged &&
              !sourceDefinitionsChanged
          ? _feedAnchor()
          : null;
      if (_historyCoverageIncomplete) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onHistoryIncomplete(false);
        });
      }
      _history.dispose();
      _history = _createHistory();
      _historyStarted = false;
      _historyCoverageIncomplete = false;
      if (!filterChanged) {
        final history = _history;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted || !identical(_history, history)) return;
          final controller = _controller;
          await controller?.refresh(
            maintainPage: true,
            preserveSelection: true,
          );
          if (!mounted ||
              !identical(_history, history) ||
              anchor == null ||
              controller == null)
            return;
          final index = controller.items.toList().indexWhere(
            (post) =>
                post.id == anchor.$1.id && post.origin == anchor.$1.origin,
          );
          if (index < 0 || !_feedScrollController.hasClients) return;
          await _feedScrollController.scrollToIndex(
            index,
            preferPosition: AutoScrollPosition.begin,
            duration: const Duration(milliseconds: 1),
          );
          if (!mounted ||
              !identical(_history, history) ||
              !_feedScrollController.hasClients)
            return;
          final box = _feedScrollController.tagMap[index]?.context
              .findRenderObject();
          if (box is RenderBox && box.hasSize) {
            final position = _feedScrollController.position;
            final delta = box.localToGlobal(Offset.zero).dy - anchor.$2;
            position.jumpTo(
              (position.pixels + delta).clamp(
                position.minScrollExtent,
                position.maxScrollExtent,
              ),
            );
          }
        });
      }
    }
  }

  (Post, double)? _feedAnchor() {
    final controller = _controller;
    if (controller == null ||
        !_feedScrollController.hasClients ||
        _feedScrollController.offset <= 0)
      return null;
    final rows = controller.items.toList();
    final indices = _feedScrollController.tagMap.keys.toList()..sort();
    for (final index in indices) {
      final box = _feedScrollController.tagMap[index]?.context
          .findRenderObject();
      if (index >= rows.length || box is! RenderBox || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top >= MediaQuery.paddingOf(context).top + kToolbarHeight &&
          top < MediaQuery.sizeOf(context).height)
        return (rows[index], top);
    }
    return null;
  }

  Future<void> _openPost(
    BuildContext tileContext,
    int index,
    AutoScrollController scrollController,
    Post post,
  ) => _feedAction(context, () async {
    final controller = _controller;
    if (controller == null) return;
    final projected = ViewerNavigationScope.maybeOf(tileContext);
    if (projected != null) {
      projected.open(index, post.thumbnailImageUrl);
      return;
    }
    final access = _feedPostAccess(ref, post, widget.sources);
    final config = access?.config;
    if (config == null) return;
    goToPostDetailsPageFromController(
      ref: ref,
      initialIndex: index,
      controller: controller,
      scrollController: scrollController,
      initialThumbnailUrl: post.thumbnailImageUrl,
      config: config,
      canContinue: () => mounted && _historyStarted && !widget.filter.isActive,
    );
  });

  void _loadOlderPosts() {
    if (widget.filter.isActive) return;
    final controller = _controller;
    if (controller == null || !controller.hasMore) return;
    setState(() => _historyStarted = true);
    unawaited(controller.fetchMore());
  }

  List<RemoteBookmarkPool> _seriesForPost(
    Post post,
    Map<String, int> revisions,
  ) {
    final config = _feedPostAccess(ref, post, widget.sources)?.config;
    final cached = _series[feedSeriesPostKey(post.origin, post.id)];
    if (config == null ||
        cached == null ||
        !feedSeriesMatchesConfig(post.origin, config) ||
        revisions[cached.sourceId] != cached.sourceRevision) {
      return const [];
    }
    return [for (final series in cached.series) series.toPool()];
  }

  @override
  Widget build(BuildContext context) {
    final actors = [
      for (final source in widget.sources)
        ref.watch(followingTopicConfigProvider(source.id)),
    ];
    if (_actors != null &&
        !const ListEquality<BooruConfig?>().equals(_actors, actors)) {
      _groupingSession = Object();
      _history.dispose();
      _history = _createHistory();
      final changed = <String>{
        for (var i = 0; i < actors.length; i++)
          if (i >= _actors!.length ||
              !feedSeriesSameActor(_actors![i], actors[i]))
            widget.sources[i].id,
      };
      _series.removeWhere((_, value) => changed.contains(value.sourceId));
      _historyStarted = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_controller?.refresh() ?? Future.value());
      });
    }
    _actors = actors;
    return _buildFeed(context, actors, {
      for (final source in widget.sources) source.id: source.runtimeRevision,
    });
  }

  Widget _buildFeed(
    BuildContext context,
    List<BooruConfig?> actors,
    Map<String, int> sourceRevisions,
  ) => CurrentBooruConfigScope(
    config: widget.config,
    child: PostScope<Post>(
      key: ValueKey(widget.filter),
      duplicateCheckMode: DuplicateCheckMode.originAndId,
      pageMode: PageMode.infinite,
      fetcher: (page) {
        final history = _history;
        return TaskEither.tryCatch(
          () async {
            if (widget.filter.isActive) {
              final snapshots = _filteredSnapshots;
              return PostResult<Post>(
                // PostGridController uses an empty page as the end marker.
                // Keep the entire local result on page one, like Bookmarks.
                posts: page == 1
                    ? [
                        for (final snapshot in snapshots)
                          _decodeFeedPost(ref, snapshot, widget.config),
                      ]
                    : const [],
                total: snapshots.length,
                hasMore: false,
              );
            }
            if (page > 1 && !_historyStarted) {
              throw StateError('Feed history requires explicit continuation');
            }
            final result = await history.load(page);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && identical(history, _history)) {
                final incomplete = history.coverageIncomplete;
                if (_historyCoverageIncomplete == incomplete) return;
                setState(() => _historyCoverageIncomplete = incomplete);
                widget.onHistoryIncomplete(incomplete);
              }
            });
            return result;
          },
          (error, _) {
            return AppError(
              type: AppErrorType.loadDataFromServerFailed,
              message: '$error',
            );
          },
        );
      },
      builder: (context, controller) {
        if (!identical(_controller, controller)) {
          _controller?.removeListener(_scheduleHistoryReorder);
          _controller = controller;
          controller.addListener(_scheduleHistoryReorder);
        }
        return Stack(
          children: [
            NotificationListener<ScrollMetricsNotification>(
              onNotification: (notification) {
                if (notification.depth == 0 &&
                    notification.metrics.axis == Axis.vertical) {
                  _scheduleFeedEndCheck();
                }
                return false;
              },
              child: PostGrid<Post>(
                scrollController: _feedScrollController,
                // The normal footer is available only after explicit history
                // start, including when bounded auto-fill leaves a short feed.
                showLoadMoreButton: _historyStarted,
                automaticContinuationEnabled:
                    _historyStarted && !widget.filter.isActive,
                controller: controller,
                body: widget.filter.isActive && _filteredSnapshots.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            context.t.following_topics.feed_filter_empty,
                          ),
                        ),
                      )
                    : null,
                gridBuilder: (context, itemBuilder) => SliverMainAxisGroup(
                  slivers: [
                    GroupedPostGrid(
                      controller: controller,
                      sessionKey: _groupingSession,
                      supported: actors.any(
                        (config) =>
                            config?.auth.booruType == BooruType.danbooru,
                      ),
                      configForPost: (post) =>
                          _feedPostAccess(ref, post, widget.sources)?.config,
                      seriesForPost: (post) =>
                          _seriesForPost(post, sourceRevisions),
                      canContinue: () =>
                          mounted && _historyStarted && !widget.filter.isActive,
                      itemBuilder: itemBuilder,
                    ),
                    if (_historyStarted && !widget.filter.isActive)
                      SliverToBoxAdapter(
                        child: _FeedHistoryStatus(
                          sources: widget.sources,
                          unavailable: _historyCoverageIncomplete,
                          completedSourceIds: _history.exhaustedSourceIds,
                          historyComplete: _history.exhausted,
                        ),
                      ),
                  ],
                ),
                header: const SizedBox.shrink(),
                sliverHeaders: [
                  SliverToBoxAdapter(
                    child: _FeedSelectionGuard(
                      onChanged: (active) {
                        _selectionActive = active;
                        if (!active && _historyReorderPending)
                          _scheduleHistoryReorder();
                      },
                    ),
                  ),
                  TimelineHeaderSliver(child: widget.filterHeader),
                ],
                enablePullToRefresh: false,
                multiSelectActions: _FeedSelectionActions(
                  controller: controller,
                ),
                itemBuilder: (context, index, scroll, useHero) {
                  final post = controller.items.elementAt(index);
                  final access = _feedPostAccess(ref, post, widget.sources);
                  final config = access?.config;
                  if (config == null)
                    return AspectRatio(
                      aspectRatio: post.aspectRatio ?? 1,
                      child: const KurumiImagePlaceholder(),
                    );
                  return CurrentBooruConfigScope(
                    config: config,
                    accessKey: access!.key,
                    requireAccess: true,
                    child: PostGridContextMenu(
                      controller: controller,
                      index: index,
                      child: DefaultImageGridItem(
                        index: index,
                        autoScrollController: scroll,
                        controller: controller,
                        useHero: useHero,
                        config: config.auth,
                        imageConfig: config.auth,
                        onTap: () => _openPost(context, index, scroll, post),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (!widget.filter.isActive &&
                (_historyCoverageIncomplete ||
                    (!_historyStarted &&
                        _feedAtEnd &&
                        !controller.refreshing &&
                        controller.hasMore)))
              Positioned(
                left: 0,
                right: 0,
                // The destination padding includes the main navigation bar.
                bottom: 16 + MediaQuery.paddingOf(context).bottom,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_historyStarted &&
                        _feedAtEnd &&
                        !_historyCoverageIncomplete &&
                        !controller.refreshing &&
                        controller.hasMore)
                      FilledButton.icon(
                        key: const ValueKey('cached-feed-load-older'),
                        onPressed: _loadOlderPosts,
                        icon: const Icon(Icons.expand_more),
                        label: Text(
                          context.t.following_topics.load_older_posts,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _FeedHistoryStatus extends StatelessWidget {
  const _FeedHistoryStatus({
    required this.sources,
    required this.unavailable,
    required this.completedSourceIds,
    required this.historyComplete,
  });
  final List<FollowingTopic> sources;
  final bool unavailable;
  final Set<String> completedSourceIds;
  final bool historyComplete;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.following_topics;
    final completed = sources
        .where(
          (source) =>
              source.historyEnd != null ||
              completedSourceIds.contains(source.id),
        )
        .length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (historyComplete)
          Text(strings.history_complete)
        else if (completed > 0)
          Text(
            strings.history_sources_complete
                .replaceAll('{complete}', '$completed')
                .replaceAll('{total}', '${sources.length}'),
          ),
        if (unavailable) Text(strings.some_topics_unavailable),
      ],
    );
  }
}

// Use native actions when the selection belongs to one profile, and the
// shared actions for a mixed selection. Every download retains its own account.
class _FeedSelectionActions extends ConsumerWidget {
  const _FeedSelectionActions({required this.controller});
  final PostGridController<Post> controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PostSelectionActions(
      selectionModeController: SelectionMode.of(context),
      postController: controller,
    );
  }
}

// An explicitly public received Feed keeps its public grant when duplicate
// saved accounts make the general origin resolver ambiguous. Never choose one
// of those accounts or grant access to a source absent from this Feed.
ContentAccessContext? _feedPostAccess(
  WidgetRef ref,
  Post post,
  List<FollowingTopic> sources,
) => _feedAccessForPost(
  ref,
  post,
  sources
      .map((source) => ref.watch(followingTopicConfigProvider(source.id)))
      .whereType<BooruConfig>(),
);

ContentAccessContext? _feedAccessForPost(
  WidgetRef ref,
  Post post,
  Iterable<BooruConfig> owners, {
  bool watch = true,
}) {
  if (post.origin.profileIdHint == null) {
    for (final config in owners) {
      final scope = config.anonymousReadScope;
      if (scope != null &&
          scope.isCurrent &&
          scope.source.engine == post.origin.booruType &&
          scope.source.site.host == post.origin.sourceHost) {
        final provider = contentAccessContextProvider(scope.key);
        return watch ? ref.watch(provider) : ref.read(provider);
      }
    }
  }
  final provider = contentAccessForOriginProvider(post.origin);
  final ordinary = watch ? ref.watch(provider) : ref.read(provider);
  final hint = post.origin.profileIdHint;
  if (hint != null && ordinary?.key.profileId != hint) return null;
  return ordinary;
}

final _feedDecodedPostProvider = Provider.autoDispose
    .family<Post, ({StoredPostSnapshot snapshot, BooruConfig fallback})>((
      ref,
      request,
    ) {
      final codec = ref
          .watch(
            booruPostCapabilityProvider(
              PostOrigin.fromSnapshot(request.snapshot.origin).booruType,
            ),
          )
          ?.codec;
      return _decodeFeedRow(request.snapshot, request.fallback, codec);
    });

Post _decodeFeedPost(
  WidgetRef ref,
  StoredPostSnapshot snapshot,
  BooruConfig fallbackConfig,
) {
  final codec = ref
      .read(
        booruPostCapabilityProvider(
          PostOrigin.fromSnapshot(snapshot.origin).booruType,
        ),
      )
      ?.codec;
  return _decodeFeedRow(snapshot, fallbackConfig, codec);
}

Post _decodeFeedRow(
  StoredPostSnapshot snapshot,
  BooruConfig fallbackConfig,
  BooruPostDataCodec? codec,
) {
  final post = decodeFeedPost(snapshot, dataCodec: codec);
  final origin = post.origin;
  final needsFallbackOrigin =
      origin.booruType == BooruType.unknown &&
      origin.sourceHost.isEmpty &&
      (origin.profileIdHint == null ||
          origin.profileIdHint == fallbackConfig.id);
  return needsFallbackOrigin
      ? post.copyWith(origin: postOriginFromConfig(fallbackConfig))
      : post;
}

DateTime? _latestSuccessfulCheck(Iterable<FollowingTopic> sources) => sources
    .map((source) => source.lastSuccessfulCheckAt)
    .whereType<DateTime>()
    .fold<DateTime?>(
      null,
      (latest, value) =>
          latest == null || value.isAfter(latest) ? value : latest,
    );

class _FeedSelectionGuard extends StatefulWidget {
  const _FeedSelectionGuard({required this.onChanged});
  final ValueChanged<bool> onChanged;
  @override
  State<_FeedSelectionGuard> createState() => _FeedSelectionGuardState();
}

class _FeedSelectionGuardState extends State<_FeedSelectionGuard> {
  SelectionModeController? _selection;
  void _changed() => widget.onChanged(_selection!.isActive);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = SelectionMode.of(context);
    if (_selection == next) return;
    _selection?.removeListener(_changed);
    _selection = next..addListener(_changed);
  }

  @override
  void dispose() {
    _selection?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
