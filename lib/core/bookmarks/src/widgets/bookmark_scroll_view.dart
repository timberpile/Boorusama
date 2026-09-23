// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:foundation/widgets.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:selection_mode/selection_mode.dart';
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
import '../data/bookmark_selection.dart';
import '../data/providers.dart';
import '../providers/bookmark_provider.dart';
import '../providers/bookmark_group_selectors.dart';
import '../providers/bookmark_shuffle_provider.dart';
import '../providers/local_providers.dart';
import '../routes/route_utils.dart';
import 'bookmark_appbar.dart';
import 'bookmark_booru_type_selector.dart';
import 'bookmark_search_bar.dart';
import 'bookmark_shuffle_button.dart';
import 'bookmark_sort_button.dart';
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
  final _selectionModeController = SelectionModeController();

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
            ..listen(bookmarkProvider, (_, _) {
              final selected = selectedBookmarkIdentities(
                controller.items.toList(),
                _selectionModeController.selection,
              );
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await controller.refresh(preserveSelection: true);
                if (!mounted || selected.isEmpty) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  final indices = bookmarkSelectionIndices(
                    controller.items.toList(),
                    selected,
                  );
                  _selectionModeController.deselectAll();
                  if (indices.isEmpty) {
                    _selectionModeController.disable();
                  } else {
                    _selectionModeController.enable(initialSelected: indices);
                  }
                });
              });
            });

          final auth = ref.watchConfigAuth;
          final download = ref.watchConfigDownload;

          return PostGrid(
            selectionModeController: _selectionModeController,
            scrollController: widget.scrollController,
            controller: controller,
            enablePullToRefresh: true,
            multiSelectActions: DefaultMultiSelectionActions(
              postController: controller,
              bookmark: false,
              onBulkDownload: (selectedPosts) {
                final library = ref.read(bookmarkProvider).valueOrNull;
                ref
                    .read(bookmarkProvider.notifier)
                    .downloadBookmarks(
                      auth,
                      download,
                      selectedPosts
                          .map((post) => library?.bookmarkForPost(post))
                          .nonNulls
                          .toList(),
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
            header: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ValueListenableBuilder(
                      valueListenable: controller.itemsNotifier,
                      builder: (_, posts, _) => Text(
                        context.t.bookmark.counter(n: posts.length),
                        style: Kurumi.themeOf(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  PostGridConfigIconButton(
                    postController: controller,
                    showBlacklist: false,
                  ),
                ],
              ),
            ),
            itemBuilder: (context, index, autoScrollController, useHero) =>
                _buildItem(
                  index,
                  controller,
                ),
            sliverHeaders: [
              SliverAppBar(
                floating: true,
                snap: true,
                pinned: true,
                automaticallyImplyLeading: false,
                titleSpacing: 0,
                backgroundColor: Kurumi.themeOf(context).colorScheme.surface,
                title: BookmarkAppBar(
                  controller: controller,
                  title: widget.title,
                ),
              ),
              SliverToBoxAdapter(
                child: BookmarkSearchBar(
                  controller: widget.searchController,
                  postController: controller,
                ),
              ),
              const SliverPinnedHeader(
                child: BookmarkBooruSourceUrlSelector(),
              ),
              const SliverSizedBox(height: 8),
              ValueListenableBuilder(
                valueListenable: controller.itemsNotifier,
                builder: (_, posts, _) => posts.isNotEmpty
                    ? const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              BookmarkSortButton(),
                              BookmarkShuffleButton(),
                            ],
                          ),
                        ),
                      )
                    : const SliverSizedBox.shrink(),
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
    final edit = ref.watch(bookmarkEditProvider);

    return ValueListenableBuilder(
      valueListenable: controller.itemsNotifier,
      builder: (_, posts, _) {
        final post = posts[index];
        final bookmark = ref
            .watch(bookmarkProvider)
            .valueOrNull
            ?.bookmarkForPost(post);
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

        return Stack(
          children: [
            PostGridContextMenu(
              index: index,
              controller: controller,
              child: DefaultImageGridItem(
                index: index,
                autoScrollController: widget.scrollController,
                controller: controller,
                imageUrl: post.isVideo
                    ? post.thumbnailImageUrl
                    : post.sampleImageUrl,
                imageCacheManager: ref.watch(bookmarkImageCacheManagerProvider),
                useHero: false,
                config: effectiveAuth,
                imageConfig: config?.auth,
                presentation: presentation,
                leadingIcons: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ConfigAwareWebsiteLogo.fromBooruType(
                      post.origin.booruType,
                      post.origin.sourceHost,
                    ),
                  ),
                ],
                onTap: () {
                  goToBookmarkDetailsPage(
                    ref,
                    index,
                    initialThumbnailUrl: post.isVideo
                        ? post.thumbnailImageUrl
                        : post.sampleImageUrl,
                    controller: controller,
                  );
                },
              ),
            ),
            if (edit)
              Positioned(
                top: 5,
                right: 5,
                child: KurumiCircularIconButton(
                  padding: const EdgeInsets.all(4),
                  icon: const Icon(Symbols.close),
                  onPressed: bookmark == null
                      ? null
                      : () => ref.bookmarks.removeBookmarkFromView(
                          bookmark,
                          widget.view,
                          onSuccess: () {
                            controller.remove([post.id], (e) => e.id);
                          },
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}
