import '../../../../content/groups/related_group_counts.dart';
import 'related_grid_card.dart';
import '../../../../settings/providers.dart';
import '../../../../content/types.dart';
import '../../../../content/content_access_provider.dart';
import '../../../../posts/details/src/types/viewer_entry.dart';
import '../../../../posts/details/src/routes/route_utils.dart';
import '../../../../posts/details/src/routes/post_details_live_source.dart';
import '../../../../posts/details/src/routes/viewer_navigation_scope.dart';
import '../../../../posts/listing/providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

import '../../../../bookmarks/src/types/pool_bookmark_capability.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../types/neighboring_timeline_groups.dart';
import '../../../../posts/related/related_family.dart';
import '../../../../content/groups/group_source_provider.dart';
import '../../../../posts/listing/widgets.dart';
import '../../../../posts/pools/pool_grid_item.dart';
import '../../../../posts/post/types.dart';
import '../../../../posts/listing/src/types/page_mode.dart';
import '../../../../search/following_topics/src/widgets/feed_post_thumbnail.dart';

class GroupedPostGrid extends ConsumerStatefulWidget {
  const GroupedPostGrid({
    required this.controller,
    required this.sessionKey,
    required this.configForPost,
    required this.seriesForPost,
    this.supported = true,
    this.raw = false,
    this.metadataChanges,
    this.onAdmit,
    this.canContinue,
    required this.itemBuilder,
    super.key,
  });
  final PostGridController<Post> controller;
  final Object sessionKey;
  final BooruConfig? Function(Post) configForPost;
  final List<RemoteBookmarkPool> Function(Post) seriesForPost;
  final bool supported;
  final bool raw;
  final Listenable? metadataChanges;
  final void Function(int start, List<Post> posts)? onAdmit;
  final bool Function()? canContinue;
  final IndexedWidgetBuilder itemBuilder;
  @override
  ConsumerState<GroupedPostGrid> createState() => _GroupedPostGridState();
}

class _GroupedPostGridState extends ConsumerState<GroupedPostGrid> {
  List<Post> _posts = const [];
  List<NeighboringTimelineEntry> _display = const [];
  var _lastFrozenFirstIndex = -1;
  var _wasRefreshing = false;
  var _generation = 0;
  final _admitted = <int>{};
  final _displayPools = <(int, int), RemoteBookmarkPool>{};
  var _groupingEnabled = false;
  final _relatedGeometry = <Object, RelatedGridGeometry>{};

  @override
  void initState() {
    super.initState();
    _bindGrouping();
    widget.controller.refreshingNotifier.addListener(_observeRefresh);
    _observeRefresh();
  }

  late final _representative = _representativeFor;

  int _representativeFor(int raw) {
    for (final entry in _display) {
      if (entry.indices.contains(raw)) return entry.firstIndex;
    }
    return raw;
  }

  @override
  void dispose() {
    widget.controller.refreshingNotifier.removeListener(_observeRefresh);
    if (identical(
      widget.controller.grouping.representativeIndex,
      _representative,
    )) {
      widget.controller.grouping.representativeIndex = null;
    }
    super.dispose();
  }

  void _bindGrouping() {
    final grouping = widget.controller.grouping;
    grouping.representativeIndex = _representative;
    if (grouping.bind(
      widget.sessionKey,
      supported: widget.supported && !widget.raw,
      enabled: ref.read(settingsNotifierProvider).groupRelatedPosts,
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(grouping, widget.controller.grouping)) {
          grouping.notifySessionChanged();
        }
      });
    }
  }

  List<NeighboringTimelineEntry> _project(
    List<Post> posts, {
    bool enabled = true,
    List<NeighboringTimelineEntry> frozen = const [],
  }) => groupNeighboringTimeline(
    posts,
    enabled: enabled && widget.supported && !widget.raw,
    relatedEnabled: widget.controller.grouping.value,
    frozen: frozen,
    scopeKey: (p) => switch (widget.configForPost(p)) {
      final config? => (p.origin, config.id, config.auth),
      null => null,
    },
    seriesIds: (p) => widget.seriesForPost(p).map((pool) => pool.id),
  );

  @override
  void didUpdateWidget(covariant GroupedPostGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.refreshingNotifier.removeListener(_observeRefresh);
      widget.controller.refreshingNotifier.addListener(_observeRefresh);
      _wasRefreshing = false;
    }
    if (oldWidget.controller != widget.controller &&
        identical(
          oldWidget.controller.grouping.representativeIndex,
          _representative,
        )) {
      oldWidget.controller.grouping.representativeIndex = null;
    }
    _bindGrouping();
    if (widget.sessionKey != oldWidget.sessionKey ||
        widget.controller != oldWidget.controller) {
      _relatedGeometry.clear();
      _posts = const [];
      _display = const [];
      _lastFrozenFirstIndex = -1;
      _generation++;
      _admitted.clear();
      _displayPools.clear();
    }
  }

  void _admit(int start) {
    final window = start ~/ (PoolBookmarkCapability.membershipBudget ~/ 2);
    if (!_admitted.add(window)) return;
    final session = widget.sessionKey;
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.sessionKey != session ||
          generation != _generation ||
          widget.raw) {
        return;
      }
      widget.onAdmit?.call(
        window * (PoolBookmarkCapability.membershipBudget ~/ 2),
        _posts,
      );
    });
  }

  void _observeRefresh() {
    final controller = widget.controller;
    if (controller.refreshing && !_wasRefreshing) {
      _generation++;
      _lastFrozenFirstIndex = -1;
      _display = const [];
      _admitted.clear();
      _displayPools.clear();
    }
    _wasRefreshing = controller.refreshing;
  }

  void _syncProjection() {
    final controller = widget.controller;
    if (_groupingEnabled != controller.grouping.value) {
      _groupingEnabled = controller.grouping.value;
      _generation++;
      // Changing Related never rearranges already displayed Series cards.
      _display = _display.where((entry) => entry.seriesId != null).toList();
    }
    _observeRefresh();
    final posts = controller.items.toList();
    final samePrefix =
        _posts.length <= posts.length &&
        _posts.indexed.every((entry) => entry.$2 == posts[entry.$1]);
    if (!samePrefix) {
      _lastFrozenFirstIndex = -1;
      _generation++;
      _admitted.clear();
      _display = const [];
      _displayPools.clear();
    }
    _posts = posts;
    // Preserve built entries by their original indices, never by a range
    // inferred from member count. A retained group can extend across pages.
    _display = _project(
      posts,
      frozen: [
        for (final entry in _display)
          if (entry.firstIndex <= _lastFrozenFirstIndex) entry,
      ],
    );
    for (final entry in _display) {
      if (entry.seriesId case final id?) {
        final pool = widget
            .seriesForPost(entry.posts.first)
            .where((pool) => pool.id == id)
            .firstOrNull;
        if (pool != null) _displayPools[(entry.firstIndex, id)] = pool;
      }
    }
  }

  int? _knownRelatedCount(
    RelatedFamilyReference family,
    BooruConfig config, {
    WidgetRef? observer,
  }) {
    final counts = observer == null
        ? ref.read(relatedGroupCountsProvider)
        : observer.watch(relatedGroupCountsProvider);
    // Observe metadata only when the same actor already has it cached. A
    // timeline never starts a family crawl just to obtain a count.
    final public = config.anonymousReadScope;
    final profileProvider = contentProfileAccessProvider(config.id);
    final access = public != null
        ? (public.isCurrent
              ? (observer == null
                    ? ref.read(contentAccessContextProvider(public.key))
                    : observer.watch(contentAccessContextProvider(public.key)))
              : null)
        : (ref.exists(profileProvider)
              ? (observer == null
                    ? ref.read(profileProvider)
                    : observer.watch(profileProvider))
              : null);
    if (access == null || access.config?.auth != config.auth) {
      return null;
    }
    final reference = referenceForBoundGroup(
      origin: family.origin,
      sourceKey: 'related:${family.anchorId}',
      source: ViewerSourceBinding(config),
    );
    if (reference == null) return null;
    final key = GroupMetadataKey(reference: reference, access: access.key);
    final summary = groupSummaryProvider(key);
    final cached = ref.exists(summary) ? ref.read(summary) : null;
    return relatedGroupTotal(
      counts,
      key,
      fallback: cached?.isLoading == false
          ? cached?.asData?.value.memberCount
          : null,
    );
  }

  List<ViewerEntry> _viewerEntries() {
    _syncProjection();
    if (_display.isNotEmpty) _lastFrozenFirstIndex = _display.last.firstIndex;
    return [
      for (final entry in _display) ..._entryViewerEntries(entry),
    ];
  }

  List<ViewerEntry> _entryViewerEntries(NeighboringTimelineEntry entry) {
    final config = widget.configForPost(entry.posts.first);
    final source = config == null
        ? const ViewerSourceBinding(BooruConfig.empty)
        : config.anonymousReadScope == null
        ? ViewerSourceBinding(config)
        : ViewerSourceBinding.publicRead(entry.posts.first.origin);
    if (config == null) {
      return [
        PostViewerEntry(
          post: entry.posts.first,
          source: source,
          occurrenceId: (_generation, entry.firstIndex, 'post'),
        ),
      ];
    }
    return [
      if (entry.family case final family?)
        GroupViewerEntry(
          summary: ContentGroupSummary(
            reference: const ContentReferenceCodec().parse(
              engine: family.origin.booruType,
              site: Uri.parse(config.url),
              kind: ContentKind.group,
              sourceKey: 'related:${family.anchorId}',
            ),
            memberCount: _knownRelatedCount(family, config),
          ),
          occurrenceId: (
            _generation,
            entry.firstIndex,
            'related',
            family.anchorId,
          ),
          source: source,
        )
      else if (_displayPools[(entry.firstIndex, entry.seriesId)]
          case final pool?)
        GroupViewerEntry(
          summary:
              pool.loadedDetails?.summary ??
              ContentGroupSummary(
                reference: const ContentReferenceCodec().parse(
                  engine: config.auth.booruType,
                  site: Uri.parse(config.url),
                  kind: ContentKind.group,
                  sourceKey: 'pool:${pool.id}',
                ),
                title: pool.title,
                memberCount: pool.total,
                displayCategory: pool.category.name,
              ),
          occurrenceId: (_generation, entry.firstIndex, 'pool', pool.id),
          source: source,
        )
      else
        PostViewerEntry(
          post: entry.posts.first,
          occurrenceId: (_generation, entry.firstIndex, 'post'),
          source: source,
        ),
    ];
  }

  void _openViewer(int displayIndex, String? thumbnail) {
    final entries = _viewerEntries();
    final generation = _generation;
    final controller = widget.controller;
    final config = widget.configForPost(_display[displayIndex].posts.first);
    if (config == null) return;
    final session = widget.sessionKey;
    bool sourceCurrent() {
      final public = config.anonymousReadScope;
      if (public == null) return ref.read(booruConfigProvider).contains(config);
      return public.isCurrent &&
          identical(
            ref.read(contentAccessContextProvider(public.key))?.config,
            config,
          );
    }

    bool valid() =>
        mounted &&
        generation == _generation &&
        controller == widget.controller &&
        session == widget.sessionKey &&
        sourceCurrent();
    final pagination = PostDetailsLiveSource(
      changes: controller,
      posts: () => controller.items,
      hasMore: () =>
          valid() &&
          (widget.canContinue?.call() ?? true) &&
          controller.pageMode == PageMode.infinite &&
          controller.hasMore,
      loading: () => valid() && controller.loadingMore,
      failed: () => valid() && controller.errors.value != null,
      fetchMore: () async {
        if (valid() && (widget.canContinue?.call() ?? true)) {
          await controller.fetchMore(
            canStart: () => valid() && (widget.canContinue?.call() ?? true),
          );
        }
      },
    );
    goToPostDetailsPageCore(
      ref: ref,
      posts: controller.items.toList(),
      initialIndex: displayIndex,
      hero: false,
      initialThumbnailUrl: thumbnail,
      entries: entries,
      config: config,
      entrySource: ViewerEntryLiveSource(
        changes: Listenable.merge([controller, widget.metadataChanges]),
        entries: () {
          if (!valid()) return const [];
          final entries = _viewerEntries();
          // Refresh/query replacement can invalidate the projection during
          // synchronization itself. Do not append the replacement generation.
          return valid() ? entries : const [];
        },
        pagination: pagination,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
      settingsNotifierProvider.select((settings) => settings.groupRelatedPosts),
    );
    ref.listen(
      settingsNotifierProvider.select((settings) => settings.groupRelatedPosts),
      (_, enabled) {
        if (SelectionMode.of(context).isActive ||
            widget.raw ||
            !widget.supported) {
          setState(_bindGrouping);
          return;
        }
        final controller = widget.controller;
        final grouping = controller.grouping;
        final session = widget.sessionKey;
        final posts = controller.items;
        PostGridScrollAnchor.preservePosition(
          context,
          () => setState(_bindGrouping),
          grouping: grouping,
          isCurrent: () =>
              mounted &&
              widget.controller == controller &&
              widget.sessionKey == session &&
              grouping.value == enabled &&
              !controller.refreshing &&
              identical(controller.items, posts),
        );
      },
    );
    _bindGrouping();
    final selection = SelectionMode.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.metadataChanges,
        widget.controller.grouping,
        selection,
        widget.controller,
      ]),
      builder: (_, _) {
        _syncProjection();
        final posts = _posts;
        final display = selection.isActive || widget.raw
            ? _project(posts, enabled: false)
            : _display;
        final grid = PostGridSliver<Post>(
          postController: widget.controller,
          displayItemCount: display.length,
          itemBuilder: (context, i) {
            final entry = display[i];
            final config = widget.configForPost(entry.posts.first);
            if (!selection.isActive && !widget.raw) {
              // Slivers may build a cache prefix in one layout pass. Freeze all
              // preceding display entries so a late response cannot move them.
              if (entry.firstIndex > _lastFrozenFirstIndex) {
                _lastFrozenFirstIndex = entry.firstIndex;
              }
              _admit(entry.lastIndex + 1);
            }
            if (config == null) {
              return widget.itemBuilder(context, entry.firstIndex);
            }
            if (entry.family case final family?) {
              return KeyedSubtree(
                key: ValueKey((
                  config,
                  family.identity,
                  entry.posts.first.id,
                )),
                child: PostGridScrollAnchor(
                  indices: entry.indices,
                  child: GestureDetector(
                    onLongPress: () =>
                        selection.enable(initialSelected: [entry.firstIndex]),
                    child: Consumer(
                      builder: (context, ref, _) {
                        final post = entry.posts.first;
                        final media = ref
                            .watch(
                              gridThumbnailUrlGeneratorProvider(
                                config.auth,
                              ),
                            )
                            .resolve(
                              post,
                              settings: ref.watch(
                                gridThumbnailSettingsProvider(
                                  config.auth,
                                ),
                              ),
                            );
                        final geometry = _relatedGeometry.putIfAbsent(
                          (config, family.identity),
                          RelatedGridGeometry.new,
                        );
                        return RelatedGridCard(
                          listType: ref.watch(
                            imageListingSettingsProvider.select(
                              (s) => s.imageListType,
                            ),
                          ),
                          geometry: geometry,
                          aspectRatio:
                              RelatedGridGeometry.validRatio(
                                media.aspectRatio,
                              ) ??
                              RelatedGridGeometry.validRatio(
                                post.effectiveThumbnailAspectRatio,
                              ) ??
                              post.aspectRatio,
                          builder: (fit) => PoolGridItem(
                            padding: EdgeInsets.zero,
                            name: null,
                            total: _knownRelatedCount(
                              family,
                              config,
                              observer: ref,
                            ),
                            kind: PoolGridItemKind.related,
                            image: PostGridImage(
                              post: entry.posts.first,
                              media: media,
                              config: config.auth,
                              fit: fit,
                            ),
                            onTap: () => _openViewer(i, null),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            }
            if (entry.seriesId == null) {
              return KeyedSubtree(
                key: ValueKey((entry.posts.first.origin, entry.posts.first.id)),
                child: widget.raw || !widget.supported
                    ? widget.itemBuilder(context, entry.firstIndex)
                    : ViewerNavigationScope(
                        open: (raw, thumbnail) => _openViewer(
                          display.indexWhere(
                            (entry) => entry.indices.contains(raw),
                          ),
                          thumbnail,
                        ),
                        child: Builder(
                          builder: (context) =>
                              widget.itemBuilder(context, entry.firstIndex),
                        ),
                      ),
              );
            }
            final pool = _displayPools[(entry.firstIndex, entry.seriesId!)];
            if (pool == null) {
              return KeyedSubtree(
                key: ValueKey((entry.posts.first.origin, entry.posts.first.id)),
                child: widget.raw || !widget.supported
                    ? widget.itemBuilder(context, entry.firstIndex)
                    : ViewerNavigationScope(
                        open: (raw, thumbnail) => _openViewer(
                          display.indexWhere(
                            (entry) => entry.indices.contains(raw),
                          ),
                          thumbnail,
                        ),
                        child: Builder(
                          builder: (context) =>
                              widget.itemBuilder(context, entry.firstIndex),
                        ),
                      ),
              );
            }
            return KeyedSubtree(
              key: ValueKey((config, pool.id, entry.posts.first.id)),
              child: PostGridScrollAnchor(
                indices: entry.indices,
                child: GestureDetector(
                  onLongPress: () =>
                      selection.enable(initialSelected: [entry.firstIndex]),
                  child: AspectRatio(
                    aspectRatio: .6,
                    child: PoolGridItem(
                      name: pool.title,
                      total: pool.total,
                      displayedCount: entry.posts.length,
                      kind: PoolGridItemKind.series,
                      category: context.t.pool.category.series,
                      image: FeedPostThumbnail(
                        post: entry.posts.first,
                        config: config.auth,
                      ),
                      onTap: () => _openViewer(i, null),
                    ),
                  ),
                ),
              ),
            );
          },
        );
        // The enclosing PostGrid owns the shared bounded continuation cycle,
        // including when series grouping collapses an entire page to one tile.
        return grid;
      },
    );
  }
}
