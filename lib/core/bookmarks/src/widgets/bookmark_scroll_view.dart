import 'dart:async';

import 'package:collection/collection.dart';

import '../../../selection/ordered_selection_controller.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:foundation/performance.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:sliver_tools/sliver_tools.dart';

// Project imports:
import '../../../../foundation/loggers.dart';
import '../../../config_widgets/website_logo.dart';
import '../../../configs/config/providers.dart';
import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../../../posts/listing/providers.dart';
import '../../../posts/listing/src/_internal/sliver_post_grid.dart';
import '../../../posts/filter/types.dart';
import '../../../posts/post/providers.dart';
import '../../../errors/providers.dart';
import '../../../blacklists/providers.dart';
import '../../../settings/providers.dart';
import '../types/bookmark_grid_entry.dart';
import '../types/pool_bookmark.dart';
import '../types/pool_bookmark_capability.dart';
import '../providers/pool_bookmark_provider.dart';
import '../services/bookmark_series_projection.dart';
import 'bookmark_pool_card.dart';
import '../../../posts/listing/widgets.dart';
import '../../../posts/post/types.dart';
import '../../../widgets/widgets.dart';
import '../../types.dart';
import '../data/bookmark_convert.dart';
import '../data/bookmark_view_refresh_gate.dart';
import '../providers/bookmark_details_mutation_notifier.dart';
import '../providers/bookmark_provider.dart';
import '../providers/bookmark_shuffle_provider.dart';
import '../providers/local_providers.dart';
import '../routes/route_utils.dart';
import 'bookmark_appbar.dart';
import 'bookmark_list_controls.dart';
import 'bookmark_search_bar.dart';
import 'bookmark_multi_selection.dart';

class BookmarkScrollView extends ConsumerStatefulWidget {
  const BookmarkScrollView({
    required this.scrollController,
    required this.searchController,
    required this.view,
    this.title,
    super.key,
  });

  final AutoScrollController scrollController;
  final TextEditingController searchController;
  final BookmarkView view;
  final String? title;

  @override
  ConsumerState<BookmarkScrollView> createState() => _BookmarkScrollViewState();
}

class _BookmarkScrollViewState extends ConsumerState<BookmarkScrollView> {
  final _selectionModeController = OrderedSelectionController<Object>(
    exitWhenSelectionRemoved: true,
  );
  final _refreshGate = BookmarkViewRefreshGate();
  var _refreshScheduled = false;
  List<BookmarkGridEntry> _fetchedEntries = const [];
  List<BookmarkGridEntry> _entries = const [];
  var _needsSeriesWarm = false;
  List<BookmarkDisplayEntry> _displayEntries = const [];
  Map<Object, int> _rawPostIndices = const {};
  final _seriesCache =
      <(Object, String, BooruConfigAuth), BookmarkSeriesMembership>{};
  var _projectionGeneration = 0;
  var _frozenUntil = 0;
  var _seriesWarmInFlight = false;
  (List<BookmarkGridEntry>, int)? _queuedSeriesWarm;

  late String _selectionQuery = widget.searchController.text;
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onCommittedQueryChanged);
  }

  void _onCommittedQueryChanged() {
    final query = widget.searchController.text;
    if (query == _selectionQuery) return;
    _selectionQuery = query;
    _selectionModeController.disable();
  }

  @override
  void didUpdateWidget(BookmarkScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_onCommittedQueryChanged);
      widget.searchController.addListener(_onCommittedQueryChanged);
      _onCommittedQueryChanged();
    }
  }

  void _scheduleRefresh(PostGridController<Post> controller) {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _refreshScheduled = false;
      if (mounted) await controller.refresh(preserveSelection: true);
    });
  }

  List<String> _parseTagsFromText(String text) {
    return text.isEmpty
        ? <String>[]
        : text
              .trim()
              .replaceAll(RegExp(r'\s+'), ' ')
              .split(' ')
              .where((e) => e.isNotEmpty)
              .toList();
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onCommittedQueryChanged);
    _selectionModeController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawPostScope<Post>(
      duplicateIdentity: BookmarkIdentity.tryFromPost,
      onError: (message) {
        ref.read(loggerProvider).error('Bookmark Listing', message);
      },
      fetcher: (page) => TaskEither.Do(
        ($) => performanceRecorder.measureAsync(
          PerfOperation.bookmarkFetch,
          () async {
            final searchTags = _parseTagsFromText(widget.searchController.text);
            final sortType = ref.read(selectedBookmarkSortTypeProvider);
            final selectedBooruUrl = ref.read(selectedBooruUrlProvider);
            final shuffleState = ref.read(bookmarkShuffleProvider);
            final library = await ref.read(bookmarkProvider.future);
            final entries = selectBookmarkGridEntries(
              state: library,
              view: widget.view,
              selectedTags: searchTags,
              sortType: sortType,
              selectedBooruUrl: selectedBooruUrl,
              shuffleState: shuffleState,
            );
            final posts = performanceRecorder.measureSync(
              PerfOperation.bookmarkProject,
              () => entries
                  .whereType<BookmarkPostEntry>()
                  .map((entry) => entry.bookmark.toPost())
                  .toList(),
              items: entries.length,
            );

            if (page == 1) {
              _fetchedEntries = entries;
              _entries = entries;
              _rawPostIndices = {
                for (final (i, entry)
                    in entries.whereType<BookmarkPostEntry>().indexed)
                  entry.key: i,
              };
              _displayEntries = projectBookmarkSeries(
                entries,
                _seriesMemberships(entries),
              );
              _frozenUntil = 0;
              _projectionGeneration++;
              _needsSeriesWarm = searchTags.isEmpty && selectedBooruUrl == null;
            }
            return page == 1
                ? PostResult(
                    posts: posts,
                    total: posts.length,
                  )
                : PostResult.empty();
          },
        ),
      ),
      builder: (context, controller) => Consumer(
        builder: (context, ref, child) {
          ref
            ..listen(booruConfigProvider, (_, _) {
              _projectionGeneration++;
              _seriesCache.clear();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) controller.refresh();
              });
            })
            ..listen(selectedBooruUrlProvider, (_, _) {
              _selectionModeController.disable();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                controller.refresh();
              });
            })
            ..listen(selectedBookmarkSortTypeProvider, (_, _) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                controller.refresh();
              });
            })
            ..listen(bookmarkShuffleProvider, (_, _) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                controller.refresh();
              });
            })
            ..listen(
              bookmarkDetailsMutationProvider.select(
                (state) => state.isVisible,
              ),
              (_, visible) {
                if (_refreshGate.onDetailsVisibilityChanged(visible)) {
                  _scheduleRefresh(controller);
                }
              },
            )
            ..listen(bookmarkProvider, (previous, next) {
              if (!bookmarkViewContentsChanged(
                previous?.valueOrNull,
                next.valueOrNull,
                widget.view,
              ))
                return;
              if (_refreshGate.onLibraryChanged()) {
                _scheduleRefresh(controller);
              }
            });

          final auth = ref.watchConfigAuth;

          return PostGrid(
            selectionModeController: _selectionModeController,
            selectionScope: widget.view,
            selectionKeysBuilder: (posts) => controller.refreshing
                ? _entries.map((e) => e.key).toList()
                : _synchronizeEntries(posts),
            body: _mixedGrid(controller),
            scrollController: widget.scrollController,
            controller: controller,
            enablePullToRefresh: true,
            multiSelectActions: DefaultMultiSelectionActions(
              postController: controller,
              bookmark: false,
              selectedPostsBuilder: (_) => [
                for (final entry in _entries.whereType<BookmarkPostEntry>())
                  if (_selectionModeController.selectedKeys.contains(entry.key))
                    controller.items.toList()[_rawPostIndices[entry.key]!],
              ],
              // Shared actions resolve each post's source profile and use the
              // ordinary quality, filename, duplicate and sidecar policy.
              extraActions: (selectedPosts) => [
                MultiSelectPopupButton(
                  enabled:
                      !controller.refreshing &&
                      (selectedPosts.isNotEmpty || _selectedPools().isNotEmpty),
                  icon: const Icon(Symbols.bookmarks),
                  name: context.t.bookmark.bulk.title,
                  items: [
                    BookmarkMultiSelectionMenu(
                      posts: selectedPosts,
                      pools: _selectedPools(),
                      config: auth,
                      currentGroupId: widget.view.groupId,
                      onCompleted: () async {},
                    ),
                  ],
                ),
              ],
            ),
            header: const SizedBox.shrink(),
            itemBuilder: (context, index, autoScrollController, useHero) =>
                _buildItem(
                  index,
                  controller,
                ),
            sliverHeaders: [
              KurumiSliverAppBar(
                floating: true,
                snap: true,
                pinned: true,
                automaticallyImplyLeading: false,
                titleSpacing: 0,
                backgroundColor: Kurumi.themeOf(context).colorScheme.surface,
                title: BookmarkAppBar(
                  title: widget.title,
                  // Restore only scaling; restoring the full MediaQuery here
                  // reapplies the status inset inside the outer toolbar.
                  textScaler: MediaQuery.textScalerOf(context),
                ),
              ),
              SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: BookmarkSearchBar(
                        controller: widget.searchController,
                        postController: controller,
                        view: widget.view,
                      ),
                    ),
                    if (ref
                            .watch(bookmarkProvider)
                            .valueOrNull
                            ?.pools
                            .isNotEmpty ??
                        false)
                      IconButton(
                        tooltip: context.t.bookmark.pool_filter_help,
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            content: SingleChildScrollView(
                              child: Text(context.t.bookmark.pool_filter_help),
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
                  ],
                ),
              ),
              SliverPinnedHeader(
                child: ValueListenableBuilder(
                  valueListenable: controller.itemsNotifier,
                  builder: (_, posts, _) => BookmarkListControls(
                    count: _entries.length,
                    gridConfig: PostGridConfigIconButton(
                      postController: controller,
                      showBlacklist: false,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Object> _synchronizeEntries(List<Post> posts) {
    final visible = visibleBookmarkGridEntries(_fetchedEntries, posts);
    if (!const ListEquality<BookmarkGridEntry>().equals(
      _entries,
      visible.entries,
    )) {
      _entries = visible.entries;
      _displayEntries = projectBookmarkSeries(
        _entries,
        _seriesMemberships(_entries),
      );
      _frozenUntil = 0;
      _projectionGeneration++;
    }
    _rawPostIndices = visible.postIndices;
    if (_needsSeriesWarm) {
      _needsSeriesWarm = false;
      final entries = _entries;
      final generation = _projectionGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _projectionGeneration)
          unawaited(_warmSeries(entries, generation));
      });
    }
    return _entries.map((e) => e.key).toList();
  }

  List<PoolBookmark> _selectedPools() => [
    for (final entry in _entries.whereType<BookmarkPoolEntry>())
      if (_selectionModeController.selectedKeys.contains(entry.key)) entry.pool,
  ];

  Map<Object, BookmarkSeriesMembership> _seriesMemberships(
    List<BookmarkGridEntry> entries,
  ) {
    final configs = ref.read(booruConfigProvider);
    return {
      for (final entry in entries.whereType<BookmarkPostEntry>())
        if (resolveBookmarkOriginProfile(entry.bookmark.post.origin, configs)
            case final config?)
          if (_validSeriesCache(entry.key, config) case final membership?)
            entry.key: membership,
    };
  }

  BookmarkSeriesMembership? _validSeriesCache(Object key, BooruConfig config) {
    final cached = _seriesCache[(key, config.id, config.auth)];
    final observed = cached?.observedAt;
    return observed != null &&
            DateTime.now().toUtc().difference(observed) <
                const Duration(minutes: 10)
        ? cached
        : null;
  }

  Future<void> _warmSeries(
    List<BookmarkGridEntry> entries,
    int generation,
  ) async {
    if (!mounted) return;
    if (_seriesWarmInFlight) {
      _queuedSeriesWarm = (entries, generation);
      return;
    }
    _seriesWarmInFlight = true;
    try {
      final configs = ref.read(booruConfigProvider);
      final batches = <BooruConfig, List<BookmarkPostEntry>>{};
      for (final entry in entries.whereType<BookmarkPostEntry>().take(
        PoolBookmarkCapability.membershipBudget,
      )) {
        final config = resolveBookmarkOriginProfile(
          entry.bookmark.post.origin,
          configs,
        );
        if (config != null) {
          if (_validSeriesCache(entry.key, config) != null) continue;
          if (!batches.containsKey(config) && batches.length >= 4) continue;
          (batches[config] ??= []).add(entry);
        }
      }
      final requests = [
        for (final batch in batches.entries)
          if (ref.read(poolBookmarkCapabilityProvider(batch.key))
              case final capability?)
            (
              config: batch.key,
              posts: batch.value,
              capability: capability,
              blacklist: ref.read(
                blacklistTagsProvider(batch.key.filter).future,
              ),
            ),
      ];
      if (requests.isEmpty && _seriesMemberships(entries).isEmpty) return;
      await Future.wait(
        requests.map((request) async {
          try {
            final metadata = await request.capability.getBookmarkSeries(
              request.config,
              request.posts.map((e) => e.bookmark.post).toList(),
            );
            final blacklist = await request.blacklist;
            if (!mounted ||
                !ref.read(booruConfigProvider).contains(request.config))
              return;
            final policy = poolCoverPolicy(request.config, blacklist);
            final now = DateTime.now().toUtc();
            for (final entry in request.posts) {
              final post = entry.bookmark.post;
              final visible =
                  poolCoverAllowsRating(request.config, post.rating) &&
                  filterTags([post], blacklist).isNotEmpty &&
                  !(post.status?.matches('deleted') ?? false) &&
                  !(post.status?.matches('banned') ?? false);
              final cover =
                  visible &&
                      RegExp(
                        r'\.(jpe?g|png|webp)$',
                        caseSensitive: false,
                      ).hasMatch(
                        Uri.tryParse(post.thumbnailImageUrl)?.path ?? '',
                      )
                  ? post.thumbnailImageUrl
                  : null;
              _seriesCache[(
                entry.key,
                request.config.id,
                request.config.auth,
              )] = BookmarkSeriesMembership(
                scope: (request.config.id, request.config.auth),
                observedAt: now,
                pools: {
                  for (final pool
                      in metadata[post.id] ?? <RemoteBookmarkPool>[])
                    if (pool.category == BookmarkedPoolCategory.series &&
                        pool.id > 0)
                      pool.id: PoolBookmark(
                        localId:
                            'projected:${post.origin.sourceHost}:${pool.id}',
                        origin: postOriginFromConfig(request.config),
                        poolId: pool.id,
                        category: BookmarkedPoolCategory.series,
                        title: pool.title,
                        total: pool.total,
                        createdAt: entry.savedAt,
                        observedAt: now,
                        groupIds: {},
                        tags: {},
                        coverage: PoolTagCoverage.unknown,
                        coverUrl: cover,
                        coverPolicy: policy,
                      ),
                },
              );
            }
          } catch (_) {
            // Failed or inaccessible metadata leaves individual Posts visible.
          }
        }),
      );
      if (!mounted || generation != _projectionGeneration) return;
      while (_seriesCache.length > 512) {
        _seriesCache.remove(_seriesCache.keys.first);
      }
      setState(() {
        _displayEntries = updateUnseenBookmarkSeries(
          entries: entries,
          displayed: _displayEntries,
          memberships: _seriesMemberships(entries),
          frozenUntil: _frozenUntil,
        );
      });
    } finally {
      _seriesWarmInFlight = false;
      final queued = _queuedSeriesWarm;
      _queuedSeriesWarm = null;
      if (mounted && queued != null && queued.$2 == _projectionGeneration) {
        unawaited(_warmSeries(queued.$1, queued.$2));
      }
    }
  }

  Widget _mixedGrid(PostGridController<Post> controller) => ListenableBuilder(
    listenable: _selectionModeController,
    builder: (_, _) => ValueListenableBuilder(
      valueListenable: controller.itemsNotifier,
      builder: (context, posts, _) {
        final selecting = _selectionModeController.isActive;
        final display = selecting
            ? projectBookmarkSeries(_entries, {}, enabled: false)
            : _displayEntries;
        final settings = ref.watch(imageListingSettingsProvider);
        return SliverPostGrid<Post>(
          postController: controller,
          displayItemCount: display.length,
          errorTranslator: ref.watch(
            appErrorTranslatorProvider(ref.watchConfigAuth),
          ),
          padding: EdgeInsets.symmetric(horizontal: settings.imageGridPadding),
          listType: settings.imageListType,
          spacing: settings.imageGridSpacing,
          aspectRatio: settings.imageGridAspectRatio,
          borderRadius: BorderRadius.circular(settings.imageBorderRadius),
          itemBuilder: (context, index) {
            final item = display[index];
            if (!selecting && item.endIndex > _frozenUntil)
              _frozenUntil = item.endIndex;
            final pool =
                item.series ??
                switch (item.entry) {
                  BookmarkPoolEntry(:final pool) => pool,
                  _ => null,
                };
            final Widget child = pool != null
                ? BookmarkPoolCard(
                    pool: pool,
                    index: item.firstIndex,
                    groupId: widget.view.groupId,
                    projected: item.series != null,
                  )
                : _buildItem(
                    _rawPostIndices[item.entry.key]!,
                    controller,
                    selectionIndex: item.firstIndex,
                  );
            return KeyedSubtree(key: ValueKey(item.key), child: child);
          },
        );
      },
    ),
  );

  Widget _buildItem(
    int index,
    PostGridController<Post> controller, {
    int? selectionIndex,
  }) {
    return ValueListenableBuilder(
      valueListenable: controller.itemsNotifier,
      builder: (_, posts, _) {
        final post = posts[index];
        final config = switch (const PostOriginResolver().resolve(
          post.origin,
          ref.watch(booruConfigProvider),
        )) {
          ResolvedPostOrigin(:final config) => config,
          _ => null,
        };
        final presentation = config == null
            ? const GenericPostPresentation()
            : null;
        final effectiveAuth = config?.auth ?? BooruConfig.empty.auth;

        return PostGridContextMenu(
          index: index,
          selectionIndex: selectionIndex,
          controller: controller,
          child: DefaultImageGridItem(
            index: index,
            selectionIndex: selectionIndex,
            autoScrollController: widget.scrollController,
            controller: controller,
            useHero: false,
            config: effectiveAuth,
            imageConfig: config?.auth,
            presentation: presentation,
            leadingIcons: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: config == null
                    ? ConfigAwareWebsiteLogo.fromBooruType(
                        post.origin.booruType,
                        post.origin.sourceHost,
                        fit: BoxFit.contain,
                      )
                    : ConfigAwareWebsiteLogo.fromConfig(
                        config.auth,
                        customIconUrl: config.profileIcon?.url,
                        fit: BoxFit.contain,
                      ),
              ),
            ],
            onTap: () {
              goToBookmarkDetailsPage(
                ref,
                index,
                sourceView: widget.view,
                initialThumbnailUrl: ref
                    .read(
                      gridThumbnailUrlGeneratorProvider(effectiveAuth),
                    )
                    .resolve(
                      post,
                      settings: ref.read(
                        gridThumbnailSettingsProvider(effectiveAuth),
                      ),
                    )
                    .url,
                controller: controller,
              );
            },
          ),
        );
      },
    );
  }
}
