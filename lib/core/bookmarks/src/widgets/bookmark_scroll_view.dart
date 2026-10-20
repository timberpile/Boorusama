import '../../../selection/ordered_selection_controller.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
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
import '../../../posts/listing/widgets.dart';
import '../../../posts/post/types.dart';
import '../../../widgets/widgets.dart';
import '../../types.dart';
import '../data/bookmark_convert.dart';
import '../data/bookmark_view_refresh_gate.dart';
import '../providers/bookmark_details_mutation_notifier.dart';
import '../providers/bookmark_provider.dart';
import '../providers/bookmark_group_selectors.dart';
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
  final _selectionModeController = OrderedSelectionController<Object>();
  final _refreshGate = BookmarkViewRefreshGate();

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
      onError: (message) {
        ref.read(loggerProvider).error('Bookmark Listing', message);
      },
      fetcher: (page) => TaskEither.Do(
        ($) async {
          final searchTags = _parseTagsFromText(widget.searchController.text);
          final sortType = ref.read(selectedBookmarkSortTypeProvider);
          final selectedBooruUrl = ref.read(selectedBooruUrlProvider);
          final shuffleState = ref.read(bookmarkShuffleProvider);
          final library = await ref.read(bookmarkProvider.future);
          final bookmarks = selectBookmarks(
            state: library,
            view: widget.view,
            selectedTags: searchTags,
            sortType: sortType,
            selectedBooruUrl: selectedBooruUrl,
            shuffleState: shuffleState,
          );
          final posts = bookmarks.map((bookmark) => bookmark.toPost()).toList();

          return page == 1
              ? PostResult(
                  posts: posts,
                  total: posts.length,
                )
              : PostResult.empty();
        },
      ),
      builder: (context, controller) => Consumer(
        builder: (context, ref, child) {
          ref
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
            ..listen(bookmarkProvider, (_, _) {
              if (_refreshGate.onLibraryChanged()) {
                _scheduleRefresh(controller);
              }
            });

          final auth = ref.watchConfigAuth;
          final download = ref.watchConfigDownload;

          return PostGrid(
            selectionModeController: _selectionModeController,
            selectionScope: widget.view,
            scrollController: widget.scrollController,
            controller: controller,
            enablePullToRefresh: true,
            multiSelectActions: DefaultMultiSelectionActions(
              postController: controller,
              bookmark: false,
              onBulkDownload: (selectedPosts) {
                final library = ref.read(bookmarkProvider).valueOrNull;
                final bookmarks = selectedPosts
                    .map((post) => library?.bookmarkForPost(post))
                    .nonNulls
                    .toList();
                if (bookmarks.length != selectedPosts.length) {
                  throw StateError('Selected bookmark disappeared');
                }
                return ref
                    .read(bookmarkProvider.notifier)
                    .downloadBookmarks(
                      auth,
                      download,
                      bookmarks,
                    );
              },
              extraActions: (selectedPosts) => [
                MultiSelectPopupButton(
                  enabled: selectedPosts.isNotEmpty,
                  icon: const Icon(Symbols.bookmarks),
                  name: context.t.bookmark.bulk.title,
                  items: [
                    BookmarkMultiSelectionMenu(
                      posts: selectedPosts,
                      config: auth,
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
                child: BookmarkSearchBar(
                  controller: widget.searchController,
                  postController: controller,
                  view: widget.view,
                ),
              ),
              SliverPinnedHeader(
                child: ValueListenableBuilder(
                  valueListenable: controller.itemsNotifier,
                  builder: (_, posts, _) => BookmarkListControls(
                    count: posts.length,
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

  Widget _buildItem(
    int index,
    PostGridController<Post> controller,
  ) {
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
          controller: controller,
          child: DefaultImageGridItem(
            index: index,
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
