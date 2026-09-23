import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../../errors/types.dart';
import '../../../../posts/details/routes.dart';
import '../../../../posts/listing/widgets.dart';
import '../../../../posts/listing/providers.dart';
import '../../../../posts/listing/src/types/page_mode.dart';
import '../../../../posts/post/types.dart';
import '../../../../posts/post/providers.dart';
import '../refresh/search_refresh_query_adapter.dart';
import '../services/feed_history_session.dart';
import '../providers/search_subscriptions_notifier.dart';
import '../types/search_following_feed.dart';
import '../types/search_subscription.dart';
import '../types/search_refresh.dart';
import '../widgets/feed_post_thumbnail.dart';
import 'following_feed_management_page.dart';

class FollowingFeedsPage extends ConsumerWidget {
  const FollowingFeedsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(booruConfigProvider);
    final byProfileId = {for (final profile in profiles) profile.id: profile};
    final strings = context.t.pinned_searches;
    return Scaffold(
      appBar: AppBar(title: Text(strings.following_feeds)),
      body: ref
          .watch(searchSubscriptionsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text(strings.load_failed)),
            data: (state) {
              final feeds = state.feeds
                  .where((feed) => byProfileId.containsKey(feed.profileId))
                  .toList();
              final newSearchIds = {
                for (final search in state.subscriptions)
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
                        final rateLimited = state.subscriptions.any(
                          (search) =>
                              feed.sourceIds.contains(search.id) &&
                              search.lastErrorKind ==
                                  SearchRefreshErrorKind.rateLimited,
                        );
                        return ListTile(
                          title: Text(feed.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (feed.posts.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      for (final post in feed.posts.take(4))
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(2),
                                            child: AspectRatio(
                                              aspectRatio: 1,
                                              child: FeedPostThumbnail(
                                                post: _decodeFeedPost(
                                                  ref,
                                                  post,
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
                              Text(caption),
                              if (rateLimited)
                                Text(
                                  strings.error_rate_limited,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                            ],
                          ),
                          leading: Badge(
                            isLabelVisible: hasNew,
                            child: const Icon(Symbols.rss_feed),
                          ),
                          onTap: () => _feedAction(context, () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => FollowingFeedPage(
                                  feedId: feed.id,
                                  profileId: feed.profileId,
                                ),
                              ),
                            );
                          }),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) async {
                              if (action == 'edit') {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => FollowingFeedManagementPage(
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
                                        searchSubscriptionsProvider.notifier,
                                      )
                                      .deleteFeed(feed.id),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(strings.edit_feed),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(context.t.generic.action.delete),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
    );
  }
}

Future<void> _feedAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.pinned_searches.operation_failed)),
      );
    }
  }
}

class FollowingFeedPage extends ConsumerStatefulWidget {
  const FollowingFeedPage({
    required this.feedId,
    required this.profileId,
    super.key,
  });
  final String feedId;
  final int profileId;
  @override
  ConsumerState<FollowingFeedPage> createState() => _FollowingFeedPageState();
}

class _FollowingFeedPageState extends ConsumerState<FollowingFeedPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          ref
              .read(searchSubscriptionsProvider.notifier)
              .markFeedRead(widget.feedId),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchSubscriptionsProvider).valueOrNull;
    final feed = state?.feeds.where((f) => f.id == widget.feedId).firstOrNull;
    final config = ref
        .watch(booruConfigProvider)
        .where((c) => c.id == widget.profileId)
        .firstOrNull;
    final sourceIds = feed?.sourceIds.toSet() ?? const <String>{};
    final sources =
        state?.subscriptions.where((s) => sourceIds.contains(s.id)).toList() ??
        [];
    final strings = context.t.pinned_searches;
    final refreshing = sources.any(
      (s) => state?.refreshingIds.contains(s.id) ?? false,
    );
    final checked = sources
        .where((s) => s.lastSuccessfulCheckAt != null)
        .length;
    final failed = sources.where((s) => s.lastErrorKind != null).length;
    final rateLimited = sources.any(
      (s) => s.lastErrorKind == SearchRefreshErrorKind.rateLimited,
    );
    final lastChecked =
        sources
            .map((s) => s.lastSuccessfulCheckAt)
            .whereType<DateTime>()
            .toList()
          ..sort();
    return Scaffold(
      appBar: AppBar(
        title: Text(feed?.name ?? strings.following_feeds),
        actions: [
          IconButton(
            tooltip: strings.edit_feed,
            icon: const Icon(Symbols.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    FollowingFeedManagementPage(feedId: widget.feedId),
              ),
            ),
          ),
        ],
      ),
      body: feed == null || config == null
          ? Center(child: Text(strings.feeds_empty))
          : Column(
              children: [
                if (refreshing) const LinearProgressIndicator(),
                Text(
                  strings.feed_freshness
                      .replaceAll('{checked}', '$checked')
                      .replaceAll('{total}', '${sources.length}')
                      .replaceAll('{failed}', '$failed'),
                ),
                if (rateLimited)
                  Text(
                    strings.error_rate_limited,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (lastChecked.isNotEmpty)
                  Text(
                    strings.last_checked.replaceAll(
                      '{date}',
                      lastChecked.first.toLocal().toString(),
                    ),
                  ),
                Expanded(
                  child: feed.posts.isEmpty
                      ? Center(child: Text(strings.feed_posts_empty))
                      : _CachedFeedGrid(
                          key: ValueKey(feed.id),
                          feed: feed,
                          config: config,
                          sources: sources,
                        ),
                ),
              ],
            ),
    );
  }
}

class _CachedFeedGrid extends ConsumerStatefulWidget {
  const _CachedFeedGrid({
    required this.feed,
    required this.config,
    required this.sources,
    super.key,
  });
  final SearchFollowingFeed feed;
  final BooruConfig config;
  final List<SearchSubscription> sources;
  @override
  ConsumerState<_CachedFeedGrid> createState() => _CachedFeedGridState();
}

class _CachedFeedGridState extends ConsumerState<_CachedFeedGrid> {
  PostGridController<Post>? _controller;
  late FeedHistorySession _history;
  var _prefetchedAtLength = -1;
  var _historyStarted = false;
  var _hasUpdates = false;
  var _historyError = false;

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
      for (final post in widget.feed.posts) _decodeFeedPost(ref, post),
    ],
    fetchPage: (source, page) async {
      final adapter = ref
          .read(booruRepoProvider(widget.config.auth))
          ?.searchRefreshQueryAdapter(widget.config.auth);
      final plan = adapter?.plan(source.query, after: null);
      if (plan case SupportedSearchRefreshQueryPlan(:final query)) {
        final result = await ref
            .read(originAwarePostRepoProvider(widget.config))
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
    final sourcesChanged = !const ListEquality<String>().equals(
      oldWidget.feed.sourceIds,
      widget.feed.sourceIds,
    );
    final postsChanged = !const ListEquality<StoredPostSnapshot>().equals(
      oldWidget.feed.posts,
      widget.feed.posts,
    );
    if (postsChanged && _historyStarted && !sourcesChanged) {
      _hasUpdates = true;
      return;
    }
    if (sourcesChanged || postsChanged) {
      _history.dispose();
      _history = _createHistory();
      _prefetchedAtLength = -1;
      _historyStarted = false;
      _hasUpdates = false;
      _historyError = false;
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
      _historyError = false;
    });
    unawaited(_controller?.refresh() ?? Future.value());
  }

  void _retryHistory() {
    setState(() => _historyError = false);
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
  Widget build(BuildContext context) => PostScope<Post>(
    pageMode: PageMode.infinite,
    fetcher: (page) {
      final history = _history;
      return TaskEither.tryCatch(
        () => history.load(page),
        (error, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && identical(history, _history)) {
              setState(() => _historyError = true);
            }
          });
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
            enablePullToRefresh: false,
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
              _historyError ||
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
                        context.t.pinned_searches.feed_updates_available,
                      ),
                    ),
                  if (_historyError)
                    FilledButton(
                      onPressed: _retryHistory,
                      child: Text(context.t.generic.action.retry),
                    ),
                  if (widget.feed.posts.length < 12 &&
                      !_historyStarted &&
                      !_historyError &&
                      !controller.refreshing &&
                      controller.hasMore)
                    FilledButton(
                      onPressed: _loadOlderPosts,
                      child: Text(context.t.pinned_searches.load_older_posts),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

Post _decodeFeedPost(WidgetRef ref, StoredPostSnapshot snapshot) {
  final codec = ref
      .read(
        booruPostCapabilityProvider(
          PostOrigin.fromSnapshot(snapshot.origin).booruType,
        ),
      )
      ?.codec;
  return decodeFeedPost(snapshot, dataCodec: codec);
}
