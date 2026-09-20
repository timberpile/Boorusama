import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../images/booru_image.dart';
import '../../../../posts/details/routes.dart';
import '../../../../posts/listing/widgets.dart';
import '../../../../posts/listing/providers.dart';
import '../../../../posts/post/types.dart';
import '../providers/search_subscription_selectors.dart';
import '../providers/search_subscriptions_notifier.dart';
import '../types/search_following_feed.dart';
import '../types/search_subscription.dart';

class FollowingFeedsPage extends ConsumerWidget {
  const FollowingFeedsPage({required this.profileId, super.key});
  final int profileId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref
        .watch(booruConfigProvider)
        .where((c) => c.id == profileId)
        .firstOrNull;
    final strings = context.t.pinned_searches;
    final state = ref.watch(searchSubscriptionsProvider);
    final feeds =
        state.valueOrNull?.feeds
            .where((f) => f.profileId == profileId)
            .toList() ??
        [];
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.following_feeds),
        actions: [
          if (config != null &&
              ref.watch(pinnedSearchTrackingSupportedProvider(config.auth)))
            IconButton(
              tooltip: strings.create_feed,
              icon: const Icon(Symbols.add),
              onPressed: () => showFollowingFeedEditor(context, ref, profileId),
            ),
        ],
      ),
      body:
          config == null ||
              !ref.watch(pinnedSearchTrackingSupportedProvider(config.auth))
          ? Center(child: Text(strings.profile_unsupported))
          : state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(child: Text(strings.load_failed)),
              data: (state) => feeds.isEmpty
                  ? Center(child: Text(strings.feeds_empty))
                  : ListView(
                      children: [
                        for (final feed in feeds)
                          ListTile(
                            title: Text(feed.name),
                            leading:
                                state.subscriptions.any(
                                  (s) => s.feedId == feed.id && s.hasNewPosts,
                                )
                                ? const Badge(child: Icon(Symbols.rss_feed))
                                : const Icon(Symbols.rss_feed),
                            onTap: () => _feedAction(context, () async {
                              await ref
                                  .read(currentBooruConfigProvider.notifier)
                                  .update(config);
                              if (!context.mounted) return;
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => FollowingFeedPage(
                                    feedId: feed.id,
                                    profileId: profileId,
                                  ),
                                ),
                              );
                            }),
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'edit') {
                                  await showFollowingFeedEditor(
                                    context,
                                    ref,
                                    profileId,
                                    feed: feed,
                                  );
                                } else {
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
                                            searchSubscriptionsProvider
                                                .notifier,
                                          )
                                          .deleteFeed(feed.id),
                                    );
                                  }
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
                          ),
                      ],
                    ),
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

Future<void> showFollowingFeedEditor(
  BuildContext context,
  WidgetRef ref,
  int profileId, {
  SearchFollowingFeed? feed,
}) async {
  final sources =
      ref
          .read(searchSubscriptionsProvider)
          .valueOrNull
          ?.subscriptions
          .where((s) => s.feedId == feed?.id && s.feedId != null)
          .toList() ??
      [];
  final result = await showDialog<({String name, List<String> queries})>(
    context: context,
    builder: (_) => _FeedEditor(feed: feed, sources: sources),
  );
  if (result == null || !context.mounted) return;
  await _feedAction(context, () async {
    final saved = await ref
        .read(searchSubscriptionsProvider.notifier)
        .saveFeed(
          profileId: profileId,
          name: result.name,
          queries: result.queries,
          id: feed?.id,
        );
    unawaited(
      ref.read(searchSubscriptionsProvider.notifier).refreshFeed(saved.id),
    );
  });
}

class _FeedEditor extends StatefulWidget {
  const _FeedEditor({required this.feed, required this.sources});
  final SearchFollowingFeed? feed;
  final List<SearchSubscription> sources;
  @override
  State<_FeedEditor> createState() => _FeedEditorState();
}

class _FeedEditorState extends State<_FeedEditor> {
  late final _name = TextEditingController(text: widget.feed?.name);
  late final _queries = TextEditingController(
    text: widget.sources.map((s) => s.query).join('\n'),
  );
  @override
  void dispose() {
    _name.dispose();
    _queries.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.pinned_searches;
    return AlertDialog(
      title: Text(
        widget.feed == null ? strings.create_feed : strings.edit_feed,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: strings.feed_name),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _queries,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: strings.feed_queries,
                helperMaxLines: 3,
                helperText: strings.feed_queries_hint.replaceAll(
                  '{limit}',
                  '$followingFeedSourceLimit',
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t.generic.action.cancel),
        ),
        TextButton(
          onPressed: _name.text.trim().isEmpty || _queries.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (
                  name: _name.text.trim(),
                  queries: _queries.text
                      .split('\n')
                      .map((q) => q.trim())
                      .where((q) => q.isNotEmpty)
                      .toList(),
                )),
          child: Text(context.t.generic.action.save),
        ),
      ],
    );
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
    final sources =
        state?.subscriptions.where((s) => s.feedId == widget.feedId).toList() ??
        [];
    final strings = context.t.pinned_searches;
    final refreshing = sources.any(
      (s) => state?.refreshingIds.contains(s.id) ?? false,
    );
    final checked = sources
        .where((s) => s.lastSuccessfulCheckAt != null)
        .length;
    final failed = sources.where((s) => s.lastErrorKind != null).length;
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
            tooltip: strings.info,
            icon: const Icon(Symbols.info),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(strings.info),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.t.generic.action.ok),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: strings.refresh,
            icon: const Icon(Symbols.refresh),
            onPressed: refreshing
                ? null
                : () => _feedAction(
                    context,
                    () => ref
                        .read(searchSubscriptionsProvider.notifier)
                        .refreshFeed(widget.feedId),
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
                if (lastChecked.isNotEmpty)
                  Text(
                    strings.last_checked.replaceAll(
                      '{date}',
                      lastChecked.first.toLocal().toString(),
                    ),
                  ),
                Expanded(
                  child: _CachedFeedGrid(
                    key: ValueKey(feed.id),
                    feed: feed,
                    config: config,
                  ),
                ),
              ],
            ),
    );
  }
}

class _CachedFeedGrid extends ConsumerStatefulWidget {
  const _CachedFeedGrid({required this.feed, required this.config, super.key});
  final SearchFollowingFeed feed;
  final BooruConfig config;
  @override
  ConsumerState<_CachedFeedGrid> createState() => _CachedFeedGridState();
}

class _CachedFeedGridState extends ConsumerState<_CachedFeedGrid> {
  PostGridController<CachedFeedPost>? _controller;
  @override
  void didUpdateWidget(covariant _CachedFeedGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feed != widget.feed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_controller?.refresh(maintainPage: true) ?? Future.value());
        }
      });
    }
  }

  Future<void> _openPost(CachedFeedPost post) => _feedAction(context, () async {
    await ref.read(currentBooruConfigProvider.notifier).update(widget.config);
    if (!mounted) return;
    goToSinglePostDetailsPage<Post>(
      ref: ref,
      postId: NumericPostId(post.id),
      configSearch: widget.config.search,
    );
  });

  @override
  Widget build(BuildContext context) => PostScope<CachedFeedPost>(
    fetcher: (page) => TaskEither.right(
      PostResult(
        posts: page == 1 ? widget.feed.posts : const [],
        total: widget.feed.posts.length,
        hasMore: false,
      ),
    ),
    builder: (context, controller) {
      _controller = controller;
      return PostGrid<CachedFeedPost>(
        controller: controller,
        enablePullToRefresh: false,
        itemBuilder: (context, index, scroll, useHero) {
          final post = controller.items.elementAt(index);
          return InkWell(
            onTap: () => _openPost(post),
            child: BooruImage(
              imageUrl: post.thumbnailImageUrl,
              config: widget.config.auth,
              fit: BoxFit.cover,
            ),
          );
        },
      );
    },
  );
}
