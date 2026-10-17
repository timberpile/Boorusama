import 'package:foundation/performance.dart';

import '../../../../../foundation/performance/performance_navigation.dart';

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:selection_mode/selection_mode.dart';

import '../../../../configs/config/types.dart';
import '../../../../downloads/downloader/providers.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../configs/manage/widgets.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../../boorus/booru/types.dart';
import '../../../../errors/types.dart';
import '../../../../posts/details/routes.dart';
import '../../../../posts/listing/widgets.dart';
import '../../../../posts/listing/providers.dart';
import '../../../../posts/listing/src/types/page_mode.dart';
import '../../../../posts/post/types.dart';
import '../../../../posts/post/providers.dart';
import '../../../../router.dart';
import '../refresh/search_refresh_query_adapter.dart';
import '../services/feed_history_session.dart';
import '../providers/following_topics_notifier.dart';
import '../providers/search_refresh_coordinator.dart';
import '../types/topic_feed.dart';
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
  FeedInitializationInterest? _feedInterest;

  @override
  void initState() {
    super.initState();
    _coordinator = ref.read(searchRefreshCoordinatorProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _activate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  void _activate() {
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
    routeObserver.unsubscribe(this);
    _deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(booruConfigProvider);
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
                                child: Text(strings.refresh),
                              ),
                              PopupMenuItem(
                                value: 'info',
                                child: Text(strings.feed_info),
                              ),
                              PopupMenuItem(
                                value: 'up',
                                enabled: index > 0,
                                child: Text(strings.move_up),
                              ),
                              PopupMenuItem(
                                value: 'down',
                                enabled: index < siblings.length - 1,
                                child: Text(strings.move_down),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(context.t.generic.action.edit),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(context.t.generic.action.delete),
                              ),
                            ],
                          );
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _feedAction(context, () async {
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
                                            feed.name,
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
  FeedInitializationInterest? _feedInterest;

  @override
  void initState() {
    super.initState();
    _coordinator = ref.read(searchRefreshCoordinatorProvider.notifier);
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
    if (route != null) routeObserver.subscribe(this, route);
  }

  void _activate() {
    _feedInterest ??= _coordinator.acquireFeedInitializationInterest(
      feedId: widget.feedId,
    );
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
    routeObserver.unsubscribe(this);
    _deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(followingTopicsProvider);
    final state = asyncState.valueOrNull;
    final feed = state?.feeds.where((f) => f.id == widget.feedId).firstOrNull;
    final config = ref
        .watch(booruConfigProvider)
        .where((c) => c.id == (feed?.profileId ?? widget.profileId))
        .firstOrNull;
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
    final sourceIds = feed?.sourceIds.toSet() ?? const <String>{};
    final sources =
        state?.topics.where((s) => sourceIds.contains(s.id)).toList() ?? [];
    final strings = context.t.following_topics;
    final refreshing = state?.refreshingFeedId == widget.feedId;
    final refreshChecked = refreshing ? state?.feedRefreshChecked ?? 0 : 0;
    final refreshTotal = refreshing ? state?.feedRefreshTotal ?? 0 : 0;
    return PerformanceScreenScope(
      screen: PerfScreen.topicFeed,
      priority: 2,
      child: Scaffold(
        appBar: KurumiAppBar(
          title: Text(feed?.name ?? strings.topic_feeds),
          actions: [
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'refresh') {
                  await _refreshFeed(context, ref, widget.feedId);
                } else if (action == 'settings' && folder != null) {
                  await _editFolderSettings(folder);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'refresh',
                  enabled:
                      feedEnabled &&
                      feed != null &&
                      state?.refreshingFeedId == null,
                  child: Text(strings.refresh),
                ),
                if (isFolderFeed)
                  PopupMenuItem(
                    value: 'settings',
                    child: Text(strings.feed_settings),
                  ),
              ],
            ),
          ],
        ),
        body: asyncState.isLoading && feed == null
            ? const Center(child: CircularProgressIndicator())
            : asyncState.hasError && feed == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(strings.load_failed),
                    TextButton(
                      onPressed: () => ref.invalidate(followingTopicsProvider),
                      child: Text(context.t.generic.action.retry),
                    ),
                  ],
                ),
              )
            : feed == null || config == null
            ? Center(child: Text(strings.feeds_empty))
            : feed.posts.isEmpty
            ? CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _FeedStatusHeader(
                      sources: sources,
                      refreshChecked: refreshChecked,
                      refreshTotal: refreshTotal,
                      unavailable: false,
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text(strings.feed_posts_empty)),
                  ),
                ],
              )
            : _CachedFeedGrid(
                key: ValueKey(feed.id),
                feed: feed,
                config: config,
                sources: sources,
                refreshChecked: refreshChecked,
                refreshTotal: refreshTotal,
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
    required this.config,
    required this.sources,
    required this.refreshChecked,
    required this.refreshTotal,
    super.key,
  });
  final TopicFeed feed;
  final BooruConfig config;
  final List<FollowingTopic> sources;
  final int refreshChecked;
  final int refreshTotal;
  @override
  ConsumerState<_CachedFeedGrid> createState() => _CachedFeedGridState();
}

class _CachedFeedGridState extends ConsumerState<_CachedFeedGrid> {
  PostGridController<Post>? _controller;
  late FeedHistorySession _history;
  var _prefetchedAtLength = -1;
  var _historyStarted = false;
  var _hasUpdates = false;
  var _historyCoverageIncomplete = false;

  @override
  void initState() {
    super.initState();
    _history = _createHistory();
  }

  @override
  void dispose() {
    _history.dispose();
    super.dispose();
  }

  FeedHistorySession _createHistory() => FeedHistorySession(
    sources: widget.sources,
    recent: [
      for (final post in widget.feed.posts)
        _decodeFeedPost(ref, post, widget.config),
    ],
    fetchPage: (source, page) async {
      final owner = ref
          .read(booruConfigProvider)
          .where((config) => config.id == source.profileId)
          .firstOrNull;
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
        return result.fold(
          (error) => throw StateError('$error'),
          (posts) => posts,
        );
      }
      throw StateError('Unsupported feed source');
    },
  );
  @override
  void didUpdateWidget(covariant _CachedFeedGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    if (postsChanged && _historyStarted && !sourceDefinitionsChanged) {
      _hasUpdates = true;
      if (sourceStatusChanged && _history.coverageIncomplete) {
        _history.allowRecovery();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(
              _controller?.refresh(maintainPage: true) ?? Future.value(),
            );
          }
        });
      }
      return;
    }
    if (sourceDefinitionsChanged || postsChanged) {
      _history.dispose();
      _history = _createHistory();
      _prefetchedAtLength = -1;
      _historyStarted = false;
      _hasUpdates = false;
      _historyCoverageIncomplete = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_controller?.refresh(maintainPage: true) ?? Future.value());
        }
      });
    }
  }

  void _showLatestPosts() {
    _history.dispose();
    _history = _createHistory();
    _prefetchedAtLength = -1;
    setState(() {
      _historyStarted = false;
      _hasUpdates = false;
      _historyCoverageIncomplete = false;
    });
    unawaited(_controller?.refresh() ?? Future.value());
  }

  Future<void> _openPost(
    int index,
    AutoScrollController scrollController,
    Post post,
  ) => _feedAction(context, () async {
    final controller = _controller;
    if (controller == null) return;
    goToPostDetailsPageFromController(
      ref: ref,
      initialIndex: index,
      controller: controller,
      scrollController: scrollController,
      initialThumbnailUrl: post.thumbnailImageUrl,
      config: widget.config,
    );
  });

  void _loadOlderPosts() {
    final controller = _controller;
    if (controller == null || !controller.hasMore) return;
    _prefetchedAtLength = controller.items.length;
    setState(() => _historyStarted = true);
    unawaited(controller.fetchMore());
  }

  @override
  Widget build(BuildContext context) => CurrentBooruConfigScope(
    config: widget.config,
    child: PostScope<Post>(
      duplicateCheckMode: DuplicateCheckMode.originAndId,
      pageMode: PageMode.infinite,
      fetcher: (page) {
        final history = _history;
        return TaskEither.tryCatch(
          () async {
            final result = await history.load(page);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && identical(history, _history)) {
                setState(
                  () => _historyCoverageIncomplete = history.coverageIncomplete,
                );
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
        _controller = controller;
        return Stack(
          children: [
            PostGrid<Post>(
              controller: controller,
              sliverHeaders: [
                SliverToBoxAdapter(
                  child: _FeedStatusHeader(
                    sources: widget.sources,
                    refreshChecked: widget.refreshChecked,
                    refreshTotal: widget.refreshTotal,
                    unavailable: _historyCoverageIncomplete,
                  ),
                ),
              ],
              enablePullToRefresh: false,
              multiSelectActions: _FeedSelectionActions(controller: controller),
              itemBuilder: (context, index, scroll, useHero) {
                if (scroll.hasClients &&
                    scroll.offset > 0 &&
                    controller.hasMore &&
                    index >= controller.items.length - 100 &&
                    _prefetchedAtLength != controller.items.length) {
                  _prefetchedAtLength = controller.items.length;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _historyStarted = true);
                      unawaited(controller.fetchMore());
                    }
                  });
                }
                final post = controller.items.elementAt(index);
                final config = switch (const PostOriginResolver().resolve(
                  post.origin,
                  ref.watch(booruConfigProvider),
                )) {
                  ResolvedPostOrigin(:final config) => config,
                  _ => null,
                };
                return PostGridContextMenu(
                  controller: controller,
                  index: index,
                  child: DefaultImageGridItem(
                    index: index,
                    autoScrollController: scroll,
                    controller: controller,
                    useHero: useHero,
                    config: config?.auth ?? BooruConfig.empty.auth,
                    imageConfig: config?.auth,
                    presentation: config == null
                        ? const GenericPostPresentation()
                        : null,
                    onTap: () => _openPost(index, scroll, post),
                  ),
                );
              },
            ),
            if (_hasUpdates ||
                _historyCoverageIncomplete ||
                (widget.feed.posts.length < 12 &&
                    !_historyStarted &&
                    !controller.refreshing &&
                    controller.hasMore))
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasUpdates)
                      FilledButton(
                        onPressed: _showLatestPosts,
                        child: Text(
                          context.t.following_topics.feed_updates_available,
                        ),
                      ),
                    if (widget.feed.posts.length < 12 &&
                        !_historyStarted &&
                        !_historyCoverageIncomplete &&
                        !controller.refreshing &&
                        controller.hasMore)
                      FilledButton(
                        onPressed: _loadOlderPosts,
                        child: Text(
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

class _FeedStatusHeader extends StatelessWidget {
  const _FeedStatusHeader({
    required this.sources,
    required this.refreshChecked,
    required this.refreshTotal,
    required this.unavailable,
  });

  final List<FollowingTopic> sources;
  final int refreshChecked;
  final int refreshTotal;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final refreshing = refreshTotal > 0;
    final remaining = (refreshTotal - refreshChecked).clamp(0, refreshTotal);
    final checkedAt = sources
        .map((source) => source.lastSuccessfulCheckAt)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (latest, value) =>
              latest == null || value.isAfter(latest) ? value : latest,
        );
    return Semantics(
      liveRegion: refreshing,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FeedLastChecked(checkedAt: checkedAt),
            if (refreshing) ...[
              const SizedBox(height: 8),
              Text(
                context.t.following_topics.feed_refresh_progress
                    .replaceAll('{checked}', '$refreshChecked')
                    .replaceAll('{total}', '$refreshTotal')
                    .replaceAll('{remaining}', '$remaining'),
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: refreshChecked / refreshTotal),
            ],
            if (unavailable) ...[
              const SizedBox(height: 8),
              Text(
                context.t.following_topics.some_topics_unavailable,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
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
    final selection = SelectionMode.of(context);
    final profiles = ref.watch(booruConfigProvider);
    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) {
        final selected = selection
            .selectedFrom(controller.items.toList())
            .toList();
        final groups = <BooruConfig, List<Post>>{};
        for (final post in selected) {
          final config = switch (const PostOriginResolver().resolve(
            post.origin,
            profiles,
          )) {
            ResolvedPostOrigin(:final config) => config,
            _ => null,
          };
          // Unavailable origins and future payload versions remain viewable;
          // authenticated mutations require a resolved, supported payload.
          if (config == null || post.booruData is UnknownPostData) {
            return const SizedBox.shrink();
          }
          groups.putIfAbsent(config, () => []).add(post);
        }
        if (groups.isEmpty) return const SizedBox.shrink();
        if (groups.length == 1) {
          return CurrentBooruConfigScope(
            config: groups.keys.single,
            child: Consumer(
              builder: (context, ref, _) {
                final builder = ref
                    .watch(booruBuilderProvider(groups.keys.single.auth))
                    ?.multiSelectionActionsBuilder;
                return builder?.call(context, selection, controller) ??
                    DefaultMultiSelectionActions(postController: controller);
              },
            ),
          );
        }
        return DefaultMultiSelectionActions<Post>(
          postController: controller,
          onBulkDownload: (_) => unawaited(
            _feedAction(context, () async {
              for (final entry in groups.entries) {
                final params = ref.read(
                  downloadNotifierParamsProvider((
                    entry.key.auth,
                    entry.key.download,
                  )),
                );
                await ref
                    .read(downloadNotifierProvider(params).notifier)
                    .bulkDownload(entry.value);
              }
            }),
          ),
        );
      },
    );
  }
}

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
