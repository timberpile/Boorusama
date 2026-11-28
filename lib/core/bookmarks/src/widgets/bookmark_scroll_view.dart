import '../../../backups/mitemite/actions.dart' show isCurrentSyncService;

import '../../../posts/listing/src/widgets/related_grid_card.dart';

import '../providers/bookmark_read_access.dart';
import 'bookmark_group_viewer_entry.dart';
import '../../../backups/mitemite/providers.dart';
import '../../../backups/mitemite/page.dart';
import '../services/bookmark_seen_projection.dart';
import 'bookmark_seen_filter.dart';
import '../providers/pool_bookmark_provider.dart';
import '../../../posts/details/src/types/viewer_entry.dart';

import 'package:collection/collection.dart';

import '../../../posts/listing/src/widgets/measured_floating_header.dart';
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
import '../../../local_media/local_media_reference.dart';
import '../../../../foundation/loggers.dart';
import '../../../config_widgets/website_logo.dart';
import '../../../configs/config/providers.dart';
import '../../../configs/config/types.dart';
import '../../../configs/manage/widgets.dart';
import '../../../content/content_media_failures.dart';
import '../../../content/anonymous_access_provider.dart';
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
import '../types/bookmark_record_fields.dart';
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
    this.floatingAppBar,
    this.leadingSlivers = const [],
    this.localGroupSelectionController,
    this.onContentRendered,
    super.key,
  });

  final AutoScrollController scrollController;
  final TextEditingController searchController;
  final BookmarkView view;
  final PreferredSizeWidget? floatingAppBar;
  final List<Widget> leadingSlivers;
  final SelectionModeController? localGroupSelectionController;
  final ValueChanged<BookmarkLibraryState>? onContentRendered;

  @override
  ConsumerState<BookmarkScrollView> createState() => _BookmarkScrollViewState();
}

class _BookmarkScrollViewState extends ConsumerState<BookmarkScrollView> {
  final _selectionModeController = OrderedSelectionController<Object>(
    exitWhenSelectionRemoved: true,
  );
  final _refreshGate = BookmarkViewRefreshGate();
  final _relatedGeometry = <Object, RelatedGridGeometry>{};
  var _refreshScheduled = false;
  var _mediaRetryRevision = 0;
  List<BookmarkGridEntry> _fetchedEntries = const [];
  BookmarkLibraryState? _fetchedLibrary;
  BookmarkView? _fetchedView;
  List<BookmarkGridEntry> _entries = const [];
  Map<Object, int> _rawPostIndices = const {};
  var _seenFilter = BookmarkSeenFilter.all;
  BookmarkSeenProjection? _seenProjection;
  (BookmarkLibraryState?, BookmarkView)? _seenInputs;
  var _markingSeen = false;
  Object? _unavailableInputs;
  var _unavailableSummary = const BookmarkUnavailableSummary();
  Map<int, PostPresentationFallbackReason> _activeUnavailableFailures =
      const {};

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
    _relatedGeometry.clear();
    _selectionModeController.disable();
  }

  @override
  void didUpdateWidget(BookmarkScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view != widget.view) {
      _relatedGeometry.clear();
      _seenFilter = BookmarkSeenFilter.all;
      _selectionModeController.synchronizeDuringBuild(
        _selectionModeController.disable,
      );
    }
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
            final view = widget.view;
            final searchTags = _parseTagsFromText(widget.searchController.text);
            final sortType = ref.read(selectedBookmarkSortTypeProvider);
            final selectedBooruUrl = ref.read(
              effectiveBookmarkSourceProvider(widget.view),
            );
            final shuffleState = ref.read(bookmarkShuffleProvider);
            final library = await ref.read(bookmarkProvider.future);
            final availability =
                ref.read(bookmarkProfileAvailabilityProvider) ??
                BookmarkProfileAvailability(
                  library,
                  ref.read(bookmarkReadProfilesProvider),
                );
            final entries = selectBookmarkGridEntries(
              state: library,
              view: view,
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
              _fetchedLibrary = library;
              _fetchedView = view;
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
          final library = ref.watch(bookmarkProvider).valueOrNull;
          if (library != null &&
              !library.mirrors.isReceived(widget.view.groupId ?? '')) {
            _seenFilter = BookmarkSeenFilter.all;
          }
          final seenInputs = (library, widget.view);
          if (!identical(_seenInputs?.$1, library) ||
              _seenInputs?.$2 != widget.view) {
            _seenProjection = library == null
                ? null
                : BookmarkSeenProjection(library, widget.view);
            _seenInputs = seenInputs;
          }
          ref
            ..listen(bookmarkReadProfilesProvider, (_, _) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) controller.refresh();
              });
            })
            ..listen(anonymousSourcePolicyProvider, (_, _) {
              _scheduleRefresh(controller);
            })
            ..listen(effectiveBookmarkSourceProvider(widget.view), (_, _) {
              _selectionModeController.disable();
              _scheduleRefresh(controller);
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
              )) {
                return;
              }
              if (_refreshGate.onLibraryChanged()) {
                _scheduleRefresh(controller);
              }
            });

          final auth = ref.watchConfigAuth;
          final reduceMotion = ref.watch(
            settingsProvider.select((settings) => settings.reduceAnimations),
          );
          final floatingAppBar = widget.floatingAppBar;
          final appBar = floatingAppBar == null
              ? null
              : Builder(
                  builder: (context) => SizedBox(
                    height:
                        AppBar.preferredHeightFor(
                          context,
                          floatingAppBar.preferredSize,
                        ) +
                        MediaQuery.paddingOf(context).top,
                    child: floatingAppBar,
                  ),
                );
          final hasLeadingContent = widget.leadingSlivers.isNotEmpty;

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
              selectedPostsBuilder: (_) {
                final posts = controller.itemsNotifier.value;
                return [
                  for (final entry
                      in _selectedAvailableEntries()
                          .whereType<BookmarkPostEntry>())
                    posts[_rawPostIndices[entry.key]!],
                ];
              },
              // Shared post actions use the source profile. Bookmark actions
              // on unified library entries retain their exact saved record.
              extraActions: (selectedPosts) {
                final selected = _selectedAvailableEntries();
                final library = _fetchedLibrary;
                final unified = library?.hasUnifiedRecords ?? false;
                final records = <Bookmark>[];
                final pools = <CollectionBookmark>[];
                for (final entry in selected) {
                  switch (entry) {
                    case BookmarkPostEntry(:final bookmark):
                      if (unified) records.add(bookmark);
                    case BookmarkNativeGroupEntry(:final bookmark):
                      records.add(bookmark);
                    case BookmarkPoolEntry(:final pool):
                      if (unified) {
                        final record = library!.byId[pool.bookmarkId];
                        if (record != null) records.add(record);
                      } else {
                        pools.add(pool);
                      }
                  }
                }
                return [
                  if (_hasSelectedUnseen)
                    MultiSelectButton(
                      name: context.t.mitemite.mark_seen,
                      icon: const Icon(Icons.done_all),
                      onPressed: _markingSeen ? null : _markSelectionSeen,
                    ),
                  MultiSelectPopupButton(
                    enabled:
                        !controller.refreshing &&
                        (records.isNotEmpty ||
                            pools.isNotEmpty ||
                            (!unified && selectedPosts.isNotEmpty)),
                    icon: const Icon(Symbols.bookmarks),
                    name: context.t.bookmark.bulk.title,
                    items: [
                      BookmarkMultiSelectionMenu(
                        posts: unified ? const [] : selectedPosts,
                        pools: pools,
                        records: records,
                        config: auth,
                        currentGroupId:
                            widget.view.kind == BookmarkViewKind.group
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
                ];
              },
            ),
            header: const SizedBox.shrink(),
            itemBuilder: (context, index, autoScrollController, useHero) =>
                _buildItem(
                  index,
                  controller,
                ),
            sliverHeaders: [
              // Structure mode keeps subgroup cards between the title and
              // the timeline controls.
              if (appBar != null && hasLeadingContent)
                MeasuredFloatingHeader(
                  reduceMotion: reduceMotion,
                  child: appBar,
                ),
              ...widget.leadingSlivers,
              TimelineHeaderSliver(
                keepVisible: ref.watch(
                  imageListingSettingsProvider.select(
                    (settings) => settings.keepTimelineToolbarVisible,
                  ),
                ),
                reduceMotion: reduceMotion,
                backgroundColor: Kurumi.themeOf(context).colorScheme.surface,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hasLeadingContent) ?appBar,
                    BookmarkSearchBar(
                      controller: widget.searchController,
                      postController: controller,
                      view: widget.view,
                      revealTimelineOnFocus:
                          widget.view.kind == BookmarkViewKind.group &&
                          widget.leadingSlivers.isNotEmpty,
                    ),
                    ValueListenableBuilder(
                      valueListenable: controller.itemsNotifier,
                      builder: (_, posts, _) => BookmarkListControls(
                        view: widget.view,
                        count: _entries.length,
                        seenFilter:
                            _seenProjection?.showFilter(_seenFilter) ?? false
                            ? BookmarkSeenFilterButton(
                                value: _seenFilter,
                                onSelected: (value) {
                                  _selectionModeController.disable();
                                  setState(() => _seenFilter = value);
                                },
                              )
                            : null,
                        unavailableIndicator: BookmarkUnavailableIndicator(
                          counts: _unavailableCounts(),
                          reasons: _unavailableSummary.reasons,
                          onRetry: _retryObservedMedia,
                        ),
                        gridConfig: PostGridConfigIconButton(
                          postController: controller,
                          showBlacklist: false,
                          itemCount: _entries.length,
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
    final filtered = [
      for (final entry in visible.entries)
        if (_seenProjection?.includes(entry, _seenFilter) ?? true) entry,
    ];
    if (!const ListEquality<BookmarkGridEntry>().equals(
      _entries,
      filtered,
    )) {
      _entries = filtered;
    }
    _rawPostIndices = visible.postIndices;
    return _entries.map((e) => e.key).toList();
  }

  Map<String, int> _unavailableCounts() {
    final library = ref.watch(bookmarkProvider).valueOrNull;
    final availability = ref.watch(bookmarkProfileAvailabilityProvider);
    if (library == null || availability == null) {
      _unavailableSummary = const BookmarkUnavailableSummary();
      return const {};
    }
    final activeFailures = <int, PostPresentationFallbackReason>{};
    for (final failure in ref.watch(contentMediaFailuresProvider).entries) {
      final id = failure.key.bookmarkId;
      final record = library.byId[id];
      final origin = switch (record) {
        PostBookmark(:final post) => post.origin,
        ContentGroupBookmark() => nativeBookmarkGroupOrigin(record),
        _ => null,
      };
      if (origin == null || availability.unavailableReasons.containsKey(id)) {
        continue;
      }
      if (ref
              .watch(bookmarkReadAccessProvider(BookmarkReaderRequest(origin)))
              ?.key !=
          failure.key.access) {
        continue;
      }
      activeFailures.putIfAbsent(id, () => failure.value);
    }
    final tags = widget.searchController.text;
    final source = ref.watch(effectiveBookmarkSourceProvider(widget.view));
    // Availability has identity equality and changes with the library/profiles.
    // Only the bounded failure map needs a value comparison.
    final inputs = (availability, widget.view, tags, source);
    if (_unavailableInputs != inputs ||
        !const MapEquality<int, PostPresentationFallbackReason>().equals(
          _activeUnavailableFailures,
          activeFailures,
        )) {
      _unavailableInputs = inputs;
      _activeUnavailableFailures = activeFailures;
      _unavailableSummary = availability.summarizeUnavailablePosts(
        library: library,
        view: widget.view,
        selectedTags: _parseTagsFromText(tags),
        selectedBooruUrl: source,
        observedFailures: activeFailures,
      );
    }
    return _unavailableSummary.sites;
  }

  void _retryObservedMedia() {
    final library = ref.read(bookmarkProvider).valueOrNull;
    if (library == null) return;
    final selected = selectBookmarkGridEntries(
      state: library,
      view: widget.view,
      selectedTags: _parseTagsFromText(widget.searchController.text),
      sortType: ref.read(selectedBookmarkSortTypeProvider),
      selectedBooruUrl: ref.read(effectiveBookmarkSourceProvider(widget.view)),
    );
    final ids = {
      for (final entry in selected.whereType<BookmarkPostEntry>())
        entry.bookmark.id,
    };
    ref.read(contentMediaFailuresProvider.notifier).retry([
      for (final key in ref.read(contentMediaFailuresProvider).keys)
        if (ids.contains(key.bookmarkId)) key,
    ]);
    setState(() => _mediaRetryRevision++);
  }

  Iterable<BookmarkGridEntry> get _selectedEntries {
    final keys = _selectionModeController.selectedKeys;
    return _entries.where((entry) => keys.contains(entry.key));
  }

  Iterable<BookmarkGridEntry> _selectedAvailableEntries() {
    final profiles = ref.read(bookmarkReadProfilesProvider);
    final availability = ref.read(bookmarkProfileAvailabilityProvider);
    return _selectedEntries.where(
      (entry) => _entryAvailable(entry, profiles, availability),
    );
  }

  bool get _hasSelectedUnseen {
    final seen = _seenProjection;
    return seen != null &&
        seen.unseenIds.isNotEmpty &&
        _selectedEntries.any(seen.isUnseen);
  }

  Future<void> _markSelectionSeen() async {
    if (_markingSeen) return;
    final targets = _selectedUnseenTargets();
    if (targets.isEmpty) return;
    setState(() => _markingSeen = true);
    try {
      await runSyncAction(context, () async {
        final service = await ref.read(miteMiteServiceProvider.future);
        if (!mounted || !isCurrentSyncService(context, service)) return;
        await service.markSeenTargets(targets);
        if (mounted) _selectionModeController.disable();
      });
    } finally {
      if (mounted) setState(() => _markingSeen = false);
    }
  }

  List<BookmarkSeenTarget> _selectedUnseenTargets() {
    final reading = _seenProjection;
    if (reading == null || reading.unseenIds.isEmpty) return const [];
    return [
      for (final entry in _selectedEntries)
        if (reading.isUnseen(entry)) ?reading.target(entry),
    ];
  }

  bool _entryAvailable(
    BookmarkGridEntry entry,
    List<BooruConfig> profiles,
    BookmarkProfileAvailability? availability,
  ) => switch (entry) {
    BookmarkPostEntry(:final bookmark) =>
      (availability?.postIds.contains(bookmark.id) ?? false) ||
          resolveBookmarkOriginProfile(bookmark.post.origin, profiles) != null,
    BookmarkNativeGroupEntry(:final bookmark) =>
      availability?.nativeGroupIds.contains(bookmark.id) ?? false,
    BookmarkPoolEntry(:final pool) =>
      availability?.collectionIds.contains(pool.localId) ?? false,
  };

  bool _hasUnavailableEntries(List<BooruConfig> profiles) {
    final availability = ref.read(bookmarkProfileAvailabilityProvider);
    return _entries.any(
      (entry) => !_entryAvailable(entry, profiles, availability),
    );
  }

  void _reportRendered(PostGridController<Post> controller) {
    final rendered = _fetchedLibrary;
    final view = _fetchedView;
    if (widget.onContentRendered == null || rendered == null || view == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.view != view ||
          !identical(_fetchedLibrary, rendered) ||
          controller.loading ||
          controller.refreshing ||
          controller.errors.value != null ||
          _refreshScheduled ||
          !TickerMode.valuesOf(context).enabled) {
        return;
      }
      final current = ref.read(bookmarkProvider).valueOrNull;
      if (current == null ||
          current.mirrors.owners[view.groupId]?.revision !=
              rendered.mirrors.owners[view.groupId]?.revision ||
          bookmarkViewContentsChanged(rendered, current, view)) {
        return;
      }
      widget.onContentRendered?.call(rendered);
    });
  }

  Widget _mixedGrid(PostGridController<Post> controller) => ListenableBuilder(
    listenable: Listenable.merge([_selectionModeController, controller]),
    builder: (context, _) {
      _reportRendered(controller);
      final settings = ref.watch(imageListingSettingsProvider);
      final profiles = ref.watch(bookmarkReadProfilesProvider);
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
          final native = item is BookmarkNativeGroupEntry
              ? item.bookmark
              : null;
          final child = native != null
              ? BookmarkNativeGroupCard(
                  bookmark: native,
                  index: index,
                  groupId: widget.view.kind == BookmarkViewKind.group
                      ? widget.view.groupId
                      : null,
                  onOpen: () {
                    if (_hasUnavailableEntries(
                      ref.read(bookmarkReadProfilesProvider),
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
                      seenTargets: _viewerSeenTargets(),
                    );
                  },
                )
              : pool != null
              ? BookmarkPoolCard(
                  relatedGeometry: pool.isRelated
                      ? _relatedGeometry.putIfAbsent(
                          item.key,
                          RelatedGridGeometry.new,
                        )
                      : null,
                  pool: pool,
                  index: index,
                  onOpen: () {
                    if (_hasUnavailableEntries(
                      ref.read(bookmarkReadProfilesProvider),
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
                      seenTargets: _viewerSeenTargets(),
                    );
                  },
                  groupId: widget.view.kind == BookmarkViewKind.group
                      ? widget.view.groupId
                      : null,
                )
              : _buildItem(
                  _rawPostIndices[item.key]!,
                  controller,
                  selectionIndex: index,
                );
          return KeyedSubtree(
            key: ValueKey((item.key, _mediaRetryRevision)),
            child: _seenProjection?.target(item) == null
                ? child
                : BookmarkSeenIndicator(
                    unseen: _seenProjection!.isUnseen(item),
                    selecting: _selectionModeController.isActive,
                    child: child,
                  ),
          );
        },
      );
    },
  );

  List<ViewerEntry> _viewerEntries() {
    return List.unmodifiable(
      _entries.map(
        (entry) => switch (entry) {
          BookmarkPostEntry(:final bookmark) => PostViewerEntry(
            post: bookmark.post,
            occurrenceId: entry.key,
            source: bookmark.post.booruData is LocalMediaPostData
                ? null
                : bookmarkReadBinding(
                        ref,
                        BookmarkReaderRequest(bookmark.post.origin),
                        bookmarkId: bookmark.id,
                      ) ??
                      const ViewerSourceBinding(BooruConfig.empty),
          ),
          BookmarkNativeGroupEntry(:final bookmark) =>
            nativeGroupViewerEntryForBookmark(
              ref,
              bookmark,
              occurrenceId: entry.key,
            ),
          BookmarkPoolEntry(:final pool) => groupViewerEntryForBookmark(
            ref,
            pool,
            occurrenceId: entry.key,
          ),
        },
      ),
    );
  }

  Map<Object, BookmarkSeenTarget> _viewerSeenTargets() => Map.unmodifiable({
    for (final entry in _entries) entry.key: ?_seenProjection?.target(entry),
  });

  Widget _buildItem(
    int index,
    PostGridController<Post> controller, {
    int? selectionIndex,
  }) {
    return ValueListenableBuilder(
      valueListenable: controller.itemsNotifier,
      builder: (_, posts, _) {
        final post = posts[index];
        if (post.booruData is LocalMediaPostData) {
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
              showRelatedBadge: false,
              config: BooruConfig.empty.auth,
              leadingIcons: [
                Icon(
                  Icons.perm_media_outlined,
                  semanticLabel: context.t.local_media.title,
                ),
              ],
              onTap: () {
                _endLocalGroupSelection();
                goToBookmarkDetailsPage(
                  ref,
                  selectionIndex ?? index,
                  entries: _viewerEntries(),
                  seenTargets: _viewerSeenTargets(),
                  sourceView: widget.view,
                  controller: controller,
                  initialThumbnailUrl: '',
                );
              },
            ),
          );
        }
        final access = ref.watch(
          bookmarkReadAccessProvider(BookmarkReaderRequest(post.origin)),
        );
        final config = access?.config;
        if (config == null) return const SizedBox.shrink();
        final effectiveAuth = config.auth;

        return CurrentBooruConfigScope(
          config: config,
          accessKey: access!.key,
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
              showRelatedBadge: false,
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
                if (_hasUnavailableEntries(
                  ref.read(bookmarkReadProfilesProvider),
                )) {
                  return;
                }
                _endLocalGroupSelection();
                goToBookmarkDetailsPage(
                  ref,
                  selectionIndex ?? index,
                  entries: _viewerEntries(),
                  seenTargets: _viewerSeenTargets(),
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
