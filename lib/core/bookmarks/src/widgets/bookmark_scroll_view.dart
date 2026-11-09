import 'bookmark_access_placeholder.dart';
import 'bookmark_group_viewer_entry.dart';
import '../providers/pool_bookmark_provider.dart';
import '../../../posts/details/src/types/viewer_entry.dart';

import 'package:collection/collection.dart';

import '../../../posts/listing/src/widgets/timeline_header_sliver.dart';

import '../../../selection/ordered_selection_controller.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:foundation/performance.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:selection_mode/selection_mode.dart';

// Project imports:
import '../../../../foundation/loggers.dart';
import '../../../config_widgets/website_logo.dart';
import '../../../configs/config/providers.dart';
import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../../../configs/manage/widgets.dart';
import '../../../content/content_access_provider.dart';
import '../../../content/content_media_failures.dart';
import '../../../content/anonymous_access_provider.dart';
import '../../../posts/details/src/providers/viewer_source_access_provider.dart';
import '../../../posts/details/src/types/post_presentation_fallback_reason.dart';
import '../../../posts/listing/providers.dart';
import '../../../posts/listing/src/_internal/sliver_post_grid.dart';
import '../../../errors/providers.dart';
import '../../../settings/providers.dart';
import '../types/bookmark_grid_entry.dart';
import '../providers/bookmark_profile_availability.dart';
import '../services/bookmark_series_projection.dart';
import 'bookmark_pool_card.dart';
import 'bookmark_native_group_card.dart';
import '../types/content_group_bookmark.dart';
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
import 'bookmark_list_controls.dart';
import 'bookmark_unavailable_indicator.dart';
import 'bookmark_search_bar.dart';
import 'bookmark_multi_selection.dart';

class BookmarkScrollView extends ConsumerStatefulWidget {
  const BookmarkScrollView({
    required this.scrollController,
    required this.searchController,
    required this.view,
    this.title,
    this.leadingSlivers = const [],
    this.localGroupSelectionController,
    super.key,
  });

  final AutoScrollController scrollController;
  final TextEditingController searchController;
  final BookmarkView view;
  final String? title;
  final List<Widget> leadingSlivers;
  final SelectionModeController? localGroupSelectionController;

  @override
  ConsumerState<BookmarkScrollView> createState() => _BookmarkScrollViewState();
}

class _BookmarkScrollViewState extends ConsumerState<BookmarkScrollView> {
  final _selectionModeController = OrderedSelectionController<Object>(
    exitWhenSelectionRemoved: true,
  );
  final _refreshGate = BookmarkViewRefreshGate();
  var _refreshScheduled = false;
  var _mediaRetryRevision = 0;
  List<BookmarkGridEntry> _fetchedEntries = const [];
  List<BookmarkGridEntry> _entries = const [];
  Object? _unavailableInputs;
  List<BookmarkGridEntry> _unavailableEntries = const [];
  Map<Object, int> _rawPostIndices = const {};

  late String _selectionQuery = widget.searchController.text;
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onCommittedQueryChanged);
    _selectionModeController.addListener(_onBookmarkSelectionChanged);
    widget.localGroupSelectionController?.addListener(
      _onLocalGroupSelectionChanged,
    );
  }

  void _onBookmarkSelectionChanged() {
    final groups = widget.localGroupSelectionController;
    if (_selectionModeController.isActive && (groups?.isActive ?? false)) {
      groups!.disable();
    }
  }

  void _onLocalGroupSelectionChanged() {
    if ((widget.localGroupSelectionController?.isActive ?? false) &&
        _selectionModeController.isActive) {
      _selectionModeController.disable();
    }
  }

  void _endLocalGroupSelection() {
    final groups = widget.localGroupSelectionController;
    if (groups?.isActive ?? false) groups!.disable();
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
    if (oldWidget.localGroupSelectionController !=
        widget.localGroupSelectionController) {
      oldWidget.localGroupSelectionController?.removeListener(
        _onLocalGroupSelectionChanged,
      );
      widget.localGroupSelectionController?.addListener(
        _onLocalGroupSelectionChanged,
      );
      _selectionModeController.synchronizeDuringBuild(
        _onLocalGroupSelectionChanged,
      );
    }
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
    widget.localGroupSelectionController?.removeListener(
      _onLocalGroupSelectionChanged,
    );
    _selectionModeController.removeListener(_onBookmarkSelectionChanged);
    _selectionModeController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawPostScope<Post>(
      // Canonical entries already deduplicate local record IDs. A retained
      // snapshot may share inferred source facts with a different saved Post.
      duplicateIdentity: (_) => null,
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
            final availability =
                ref.read(bookmarkProfileAvailabilityProvider) ??
                BookmarkProfileAvailability(
                  library,
                  ref.read(booruConfigProvider),
                );
            final entries = selectBookmarkGridEntries(
              state: library,
              view: widget.view,
              selectedTags: searchTags,
              sortType: sortType,
              selectedBooruUrl: selectedBooruUrl,
              shuffleState: shuffleState,
              availablePostIds: availability.postIds,
              availableCollectionIds: availability.collectionIds,
              availableNativeGroupIds: availability.nativeGroupIds,
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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) controller.refresh();
              });
            })
            ..listen(anonymousSourcePolicyProvider, (_, _) {
              _scheduleRefresh(controller);
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
                  if (_entryAvailable(entry, ref.read(booruConfigProvider)) &&
                      _selectionModeController.selectedKeys.contains(entry.key))
                    controller.items.toList()[_rawPostIndices[entry.key]!],
              ],
              // Shared actions resolve each post's source profile and use the
              // ordinary quality, filename, duplicate and sidecar policy.
              extraActions: (selectedPosts) => [
                MultiSelectPopupButton(
                  enabled:
                      !controller.refreshing &&
                      (selectedPosts.isNotEmpty ||
                          _selectedPools().isNotEmpty ||
                          _selectedNativeGroups().isNotEmpty),
                  icon: const Icon(Symbols.bookmarks),
                  name: context.t.bookmark.bulk.title,
                  items: [
                    BookmarkMultiSelectionMenu(
                      posts: selectedPosts,
                      pools: _selectedPools(),
                      records: _selectedNativeGroups(),
                      config: auth,
                      currentGroupId: widget.view.kind == BookmarkViewKind.group
                          ? widget.view.groupId
                          : null,
                      sourceGroupIds:
                          widget.view.kind == BookmarkViewKind.subtree
                          ? (ref
                                    .read(bookmarkProvider)
                                    .valueOrNull
                                    ?.groupIdsForView(widget.view) ??
                                const <String>{})
                          : null,
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
              ...widget.leadingSlivers,
              TimelineHeaderSliver(
                keepVisible: ref.watch(
                  imageListingSettingsProvider.select(
                    (settings) => settings.keepTimelineToolbarVisible,
                  ),
                ),
                reduceMotion: ref.watch(
                  settingsProvider.select(
                    (settings) => settings.reduceAnimations,
                  ),
                ),
                backgroundColor: Kurumi.themeOf(context).colorScheme.surface,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BookmarkSearchBar(
                      controller: widget.searchController,
                      postController: controller,
                      view: widget.view,
                    ),
                    ValueListenableBuilder(
                      valueListenable: controller.itemsNotifier,
                      builder: (_, posts, _) => BookmarkListControls(
                        count: _entries.length,
                        unavailableIndicator: BookmarkUnavailableIndicator(
                          counts: _unavailableCounts(),
                          onRetry: _retryObservedMedia,
                        ),
                        gridConfig: PostGridConfigIconButton(
                          postController: controller,
                          showBlacklist: false,
                        ),
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

  List<Object> _synchronizeEntries(List<Post> posts) {
    final visible = visibleBookmarkGridEntries(_fetchedEntries, posts);
    if (!const ListEquality<BookmarkGridEntry>().equals(
      _entries,
      visible.entries,
    )) {
      _entries = visible.entries;
    }
    _rawPostIndices = visible.postIndices;
    return _entries.map((e) => e.key).toList();
  }

  Map<PostPresentationFallbackReason, int> _unavailableCounts() {
    final library = ref.watch(bookmarkProvider).valueOrNull;
    final availability = ref.watch(bookmarkProfileAvailabilityProvider);
    if (library == null || availability == null) return const {};
    final tags = widget.searchController.text;
    final source = ref.watch(selectedBooruUrlProvider);
    final inputs = (library, widget.view, tags, source);
    if (_unavailableInputs != inputs) {
      _unavailableInputs = inputs;
      _unavailableEntries = selectBookmarkGridEntries(
        state: library,
        view: widget.view,
        selectedTags: _parseTagsFromText(tags),
        sortType: BookmarkSortType.newest,
        selectedBooruUrl: source,
      );
    }
    final entries = _unavailableEntries;
    final counts = Map.of(availability.countsForEntries(entries));
    final origins = {
      for (final entry in entries.whereType<BookmarkPostEntry>())
        entry.bookmark.id: entry.bookmark.post.origin,
      for (final entry in entries.whereType<BookmarkNativeGroupEntry>())
        entry.bookmark.id: nativeBookmarkGroupOrigin(entry.bookmark),
    };
    final counted = <int>{};
    for (final entry in entries.whereType<BookmarkPostEntry>()) {
      final bookmark = entry.bookmark;
      if (availability.unavailableReasons.containsKey(bookmark.id)) continue;
      final resolution = const PostOriginResolver().resolve(
        bookmark.post.origin,
        ref.watch(booruConfigProvider),
        allowProfileHintFallback: true,
      );
      if (resolution case ResolvedPostOrigin(:final config)) {
        final policy = ref.watch(contentEffectivePolicyProvider(config.id));
        if (policy.hasError) {
          counted.add(bookmark.id);
          counts.update(
            PostPresentationFallbackReason.refreshFailed,
            (n) => n + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }
    for (final failure in ref.watch(contentMediaFailuresProvider).entries) {
      final id = failure.key.bookmarkId;
      final origin = origins[id];
      if (origin == null ||
          availability.unavailableReasons.containsKey(id) ||
          counted.contains(id))
        continue;
      if (ref.watch(contentAccessForOriginProvider(origin))?.key !=
          failure.key.access)
        continue;
      counted.add(id);
      counts.update(failure.value, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  void _retryObservedMedia() {
    final library = ref.read(bookmarkProvider).valueOrNull;
    if (library == null) return;
    final selected = selectBookmarkGridEntries(
      state: library,
      view: widget.view,
      selectedTags: _parseTagsFromText(widget.searchController.text),
      sortType: ref.read(selectedBookmarkSortTypeProvider),
      selectedBooruUrl: ref.read(selectedBooruUrlProvider),
    );
    final ids = {
      for (final entry in selected.whereType<BookmarkPostEntry>())
        entry.bookmark.id,
      for (final entry in selected.whereType<BookmarkNativeGroupEntry>())
        entry.bookmark.id,
    };
    for (final entry in selected.whereType<BookmarkPostEntry>()) {
      if (ref.read(
            contentAccessForOriginProvider(entry.bookmark.post.origin),
          ) ==
          null) {
        retryBookmarkPolicy(ref, entry.bookmark.post.origin);
      }
    }
    ref.read(contentMediaFailuresProvider.notifier).retry([
      for (final key in ref.read(contentMediaFailuresProvider).keys)
        if (ids.contains(key.bookmarkId)) key,
    ]);
    setState(() => _mediaRetryRevision++);
  }

  List<CollectionBookmark> _selectedPools() => [
    for (final entry in _entries.whereType<BookmarkPoolEntry>())
      if (_entryAvailable(entry, ref.read(booruConfigProvider)) &&
          _selectionModeController.selectedKeys.contains(entry.key))
        entry.pool,
  ];

  List<ContentGroupBookmark> _selectedNativeGroups() => [
    for (final entry in _entries.whereType<BookmarkNativeGroupEntry>())
      if (_entryAvailable(entry, ref.read(booruConfigProvider)) &&
          _selectionModeController.selectedKeys.contains(entry.key))
        entry.bookmark,
  ];

  bool _entryAvailable(BookmarkGridEntry entry, List<BooruConfig> profiles) =>
      switch (entry) {
        BookmarkPostEntry(:final bookmark) =>
          resolveBookmarkOriginProfile(bookmark.post.origin, profiles) !=
                  null ||
              (ref
                      .read(bookmarkProfileAvailabilityProvider)
                      ?.postIds
                      .contains(bookmark.id) ??
                  false),
        BookmarkPoolEntry(:final pool) =>
          ref
                  .read(bookmarkProfileAvailabilityProvider)
                  ?.collectionIds
                  .contains(pool.localId) ??
              false,
        BookmarkNativeGroupEntry(:final bookmark) =>
          ref
                  .read(bookmarkProfileAvailabilityProvider)
                  ?.nativeGroupIds
                  .contains(bookmark.id) ??
              false,
      };

  bool _hasUnavailableEntries(List<BooruConfig> profiles) =>
      _entries.any((entry) => !_entryAvailable(entry, profiles));

  Widget _mixedGrid(PostGridController<Post> controller) => ListenableBuilder(
    listenable: _selectionModeController,
    builder: (_, _) => ValueListenableBuilder(
      valueListenable: controller.itemsNotifier,
      builder: (context, posts, _) {
        final settings = ref.watch(imageListingSettingsProvider);
        final profiles = ref.watch(booruConfigProvider);
        // Keep stale entries out of the grid and viewer until refresh catches up.
        // Retaining their indices while hiding the sliver also prevents selection
        // and viewer navigation from addressing a different record.
        if (_hasUnavailableEntries(profiles)) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverPostGrid<Post>(
          postController: controller,
          displayItemCount: _entries.length,
          errorTranslator: ref.watch(
            appErrorTranslatorProvider(ref.watchConfigAuth),
          ),
          padding: EdgeInsets.symmetric(horizontal: settings.imageGridPadding),
          listType: settings.imageListType,
          spacing: settings.imageGridSpacing,
          aspectRatio: settings.imageGridAspectRatio,
          borderRadius: BorderRadius.circular(settings.imageBorderRadius),
          itemBuilder: (context, index) {
            final item = _entries[index];
            final pool = switch (item) {
              BookmarkPoolEntry(:final pool) => pool,
              _ => null,
            };
            final Widget child = pool != null
                ? BookmarkPoolCard(
                    pool: pool,
                    index: index,
                    onOpen: () {
                      if (_hasUnavailableEntries(
                        ref.read(booruConfigProvider),
                      )) {
                        return;
                      }
                      _endLocalGroupSelection();
                      goToBookmarkDetailsPage(
                        ref,
                        index,
                        initialThumbnailUrl: '',
                        controller: controller,
                        sourceView: widget.view,
                        entries: _viewerEntries(),
                      );
                    },
                    groupId: widget.view.kind == BookmarkViewKind.group
                        ? widget.view.groupId
                        : null,
                  )
                : item is BookmarkNativeGroupEntry
                ? BookmarkNativeGroupCard(
                    bookmark: item.bookmark,
                    index: index,
                    groupId: widget.view.kind == BookmarkViewKind.group
                        ? widget.view.groupId
                        : null,
                    onOpen: () {
                      if (_hasUnavailableEntries(ref.read(booruConfigProvider)))
                        return;
                      _endLocalGroupSelection();
                      goToBookmarkDetailsPage(
                        ref,
                        index,
                        initialThumbnailUrl:
                            item.bookmark.summary.cover?.thumbnail.toString() ??
                            '',
                        controller: controller,
                        sourceView: widget.view,
                        entries: _viewerEntries(),
                      );
                    },
                  )
                : _buildItem(
                    _rawPostIndices[item.key]!,
                    controller,
                    selectionIndex: index,
                  );
            return KeyedSubtree(
              key: ValueKey((item.key, _mediaRetryRevision)),
              child: child,
            );
          },
        );
      },
    ),
  );

  List<ViewerEntry> _viewerEntries() {
    return List.unmodifiable(
      _entries.map(
        (entry) => switch (entry) {
          BookmarkPostEntry(:final bookmark) => PostViewerEntry(
            post: bookmark.post,
            occurrenceId: entry.key,
            source:
                bindViewerOrigin(
                  ref,
                  bookmark.post.origin,
                  bookmarkId: bookmark.id,
                ) ??
                const ViewerSourceBinding(BooruConfig.empty),
          ),
          BookmarkPoolEntry(:final pool) => groupViewerEntryForBookmark(
            ref,
            pool,
            occurrenceId: entry.key,
          ),
          BookmarkNativeGroupEntry(:final bookmark) =>
            nativeGroupViewerEntryForBookmark(
              ref,
              bookmark,
              occurrenceId: entry.key,
            ),
        },
      ),
    );
  }

  Widget _buildItem(
    int index,
    PostGridController<Post> controller, {
    int? selectionIndex,
  }) {
    return ValueListenableBuilder(
      valueListenable: controller.itemsNotifier,
      builder: (_, posts, _) {
        final post = posts[index];
        final access = ref.watch(contentAccessForOriginProvider(post.origin));
        final config = access?.config;
        if (config == null)
          return BookmarkAccessPlaceholder(
            origin: post.origin,
            aspectRatio: post.aspectRatio ?? 1,
          );
        final visibility = ref.watch(
          contentPostVisibilityProvider((access: access!.key, post: post)),
        );
        if (visibility.valueOrNull != true)
          return BookmarkAccessPlaceholder(
            origin: post.origin,
            aspectRatio: post.aspectRatio ?? 1,
          );
        final effectiveAuth = config.auth;

        return CurrentBooruConfigScope(
          config: config,
          accessKey: access.key,
          requireAccess: true,
          bookmarkId: ref
              .watch(bookmarkProvider)
              .valueOrNull
              ?.storedBookmarkForPost(post)
              ?.id,
          child: PostGridContextMenu(
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
              imageConfig: config.auth,
              leadingIcons: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ConfigAwareWebsiteLogo.fromConfig(
                    config.auth,
                    customIconUrl: config.profileIcon?.url,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
              onTap: () {
                if (_hasUnavailableEntries(ref.read(booruConfigProvider))) {
                  return;
                }
                _endLocalGroupSelection();
                goToBookmarkDetailsPage(
                  ref,
                  selectionIndex ?? index,
                  entries: _viewerEntries(),
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
          ),
        );
      },
    );
  }
}
