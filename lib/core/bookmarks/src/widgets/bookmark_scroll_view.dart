import '../../../posts/related/related_family.dart';
import '../providers/pool_bookmark_provider.dart';
import '../../../posts/details/src/types/viewer_entry.dart';
import '../types/pool_bookmark_capability.dart';

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
import '../../../posts/listing/providers.dart';
import '../../../posts/listing/src/_internal/sliver_post_grid.dart';
import '../../../errors/providers.dart';
import '../../../settings/providers.dart';
import '../types/bookmark_grid_entry.dart';
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
import 'bookmark_list_controls.dart';
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
  List<BookmarkGridEntry> _fetchedEntries = const [];
  List<BookmarkGridEntry> _entries = const [];
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

  List<CollectionBookmark> _selectedPools() => [
    for (final entry in _entries.whereType<BookmarkPoolEntry>())
      if (_selectionModeController.selectedKeys.contains(entry.key)) entry.pool,
  ];

  Widget _mixedGrid(PostGridController<Post> controller) => ListenableBuilder(
    listenable: _selectionModeController,
    builder: (_, _) => ValueListenableBuilder(
      valueListenable: controller.itemsNotifier,
      builder: (context, posts, _) {
        final settings = ref.watch(imageListingSettingsProvider);
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
                : _buildItem(
                    _rawPostIndices[item.key]!,
                    controller,
                    selectionIndex: index,
                  );
            return KeyedSubtree(key: ValueKey(item.key), child: child);
          },
        );
      },
    ),
  );

  List<ViewerEntry> _viewerEntries() {
    final profiles = ref.read(booruConfigProvider);
    return List.unmodifiable(
      _entries.map(
        (entry) => switch (entry) {
          BookmarkPostEntry(:final bookmark) => PostViewerEntry(
            post: bookmark.post,
            occurrenceId: entry.key,
            source: switch (resolveBookmarkOriginProfile(
              bookmark.post.origin,
              profiles,
            )) {
              final config? => ViewerSourceBinding(config),
              _ => null,
            },
          ),
          BookmarkPoolEntry(:final pool) when pool.family != null =>
            RelatedViewerEntry(
              family: pool.family!,
              occurrenceId: entry.key,
              source: switch (resolvePoolBookmarkProfile(pool, profiles)) {
                final config? => ViewerSourceBinding(config),
                _ => null,
              },
            ),
          BookmarkPoolEntry(:final pool) => PoolViewerEntry(
            origin: pool.origin,
            pool: RemoteBookmarkPool(
              id: pool.referenceId,
              title: pool.title,
              category: pool.category,
              total: pool.total,
              supportsUploadOrder: true,
            ),
            occurrenceId: entry.key,
            source: switch (resolvePoolBookmarkProfile(pool, profiles)) {
              final config? => ViewerSourceBinding(config),
              _ => null,
            },
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
        );
      },
    );
  }
}
