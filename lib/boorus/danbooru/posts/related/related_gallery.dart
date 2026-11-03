import 'package:dio/dio.dart';
import 'package:foundation/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:selection_mode/selection_mode.dart';

import '../../../../../core/bookmarks/src/widgets/bookmark_group_picker.dart';
import '../../../../../core/bookmarks/src/providers/bookmark_provider.dart';
import '../../../../../core/configs/config/providers.dart';
import '../../../../../core/http/client/coordination.dart';
import '../../../../../core/posts/details/routes.dart';
import '../../../../../core/posts/details/src/widgets/post_details_page_view_scope.dart';
import '../../../../../core/posts/details/src/types/viewer_entry.dart';
import '../../../../../core/posts/details/src/widgets/viewer_entry_navigation_header.dart';
import '../../../../../core/posts/details_pageview/widgets.dart';
import '../../../../../core/posts/listing/widgets.dart';
import '../../../../../core/posts/post/providers.dart';
import '../../../../../core/posts/post/types.dart';
import '../../../../../core/posts/related/related_family.dart';
import '../../../../../core/settings/providers.dart';
import '../../../../../core/posts/related/related_posts_order.dart';
import '../../../../../core/posts/listing/src/widgets/timeline_option_selector.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../pools/details/src/widgets/pool_gallery_checkpoint.dart';
import '../listing/widgets.dart';

void openRelatedFamily(WidgetRef ref, RelatedFamilyReference family) {
  final config = ref.readConfig;
  goToPostDetailsPageCore<Post>(
    ref: ref,
    posts: const [],
    initialIndex: 0,
    hero: false,
    initialThumbnailUrl: null,
    config: config,
    entries: [
      RelatedViewerEntry(
        family: family,
        occurrenceId: Object(),
        source: ViewerSourceBinding(config),
      ),
    ],
  );
}

class RelatedGallery extends ConsumerStatefulWidget {
  const RelatedGallery({required this.entry, super.key});
  final RelatedViewerEntry entry;
  @override
  ConsumerState<RelatedGallery> createState() => _RelatedGalleryState();
}

class _RelatedGalleryState extends ConsumerState<RelatedGallery> {
  final _scroll = AutoScrollController();
  final _selection = SelectionModeController();
  final _cancellation = CancelToken();
  PostDetailsPageViewController? _pager;
  bool _selecting = false;
  RelatedPostsOrder? _order;
  var _savingOrder = false;

  @override
  void initState() {
    super.initState();
    _selection.addListener(_selectionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pager = PostDetailsPageViewScope.maybeOf(context);
    _order ??=
        PageStorage.maybeOf(context)?.readState(
          context,
          identifier: (widget.entry.occurrenceId, 'related-order'),
        ) as RelatedPostsOrder? ??
        ref.read(settingsProvider).relatedPostsOrder;
    // Freeze the occurrence's initial order as well as explicit changes. Other
    // galleries can change the preference while this page is evicted.
    PageStorage.maybeOf(context)?.writeState(
      context,
      _order,
      identifier: (widget.entry.occurrenceId, 'related-order'),
    );
  }

  void _selectionChanged() {
    if (_selecting == _selection.isActive) return;
    _selecting = _selection.isActive;
    if (_selecting) {
      _pager?.disableAllSwiping();
      _pager?.disableKeyboardShortcuts();
    } else {
      _pager?.enableAllSwiping();
      _pager?.enableKeyboardShortcuts();
    }
  }

  @override
  void dispose() {
    _cancellation.cancel();
    _selection.removeListener(_selectionChanged);
    _selection.dispose();
    _scroll.dispose();
    if (_selecting) {
      _pager?.enableAllSwiping();
      _pager?.enableKeyboardShortcuts();
    }
    super.dispose();
  }

  Future<void> _setOrder(RelatedPostsOrder order) async {
    if (order == _order || _savingOrder) return;
    setState(() => _savingOrder = true);
    try {
      final saved = await ref
          .read(settingsNotifierProvider.notifier)
          .updateWith(
            (settings) => settings.copyWith(relatedPostsOrder: order),
          );
      if (!mounted) return;
      if (!saved) throw StateError('Related order could not be saved');
      _selection.disable();
      PageStorage.maybeOf(context)?.writeState(
        context,
        null,
        identifier: (widget.entry.occurrenceId, 'related-viewport', order),
      );
      PageStorage.maybeOf(context)?.writeState(
        context,
        order,
        identifier: (widget.entry.occurrenceId, 'related-order'),
      );
      if (_scroll.hasClients) _scroll.jumpTo(0);
      setState(() => _order = order);
    } catch (_) {
      if (mounted)
        Kurumi.showErrorToast(
          context,
          context.t.bookmark.groups.operation_failed,
        );
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfig;
    final order = _order!;
    final saved = ref
        .watch(bookmarkProvider)
        .valueOrNull
        ?.pools
        .where((p) => p.identity == widget.entry.family.identity)
        .firstOrNull;
    final repo = ref.watch(originAwarePostRepoProvider(config));
    final perPage = ref.watch(
      imageListingSettingsProvider.select((s) => s.postsPerPage),
    );
    return SafeArea(
      top: false,
      bottom: false,
      child: CustomContextMenuOverlay(
        child: PostScope<Post>(
          key: ValueKey((widget.entry.occurrenceId, config, perPage, order)),
          fetcher: (page) => TaskEither(
            () => runWithApiRequestContext(
              ApiRequestContext(
                cancelToken: _cancellation,
                canStart: () => mounted,
              ),
              () => repo
                  .getPosts(
                    '${widget.entry.family.query} ${order.queryOrder}',
                    page,
                    limit: perPage,
                  )
                  .map(
                    (result) => result.copyWith(
                      posts: result.posts
                          .where(widget.entry.family.contains)
                          .toList(),
                    ),
                  )
                  .run(),
            ),
          ),
          builder: (context, controller) => PoolGalleryCheckpoint(
            identity: (widget.entry.occurrenceId, 'related-viewport', order),
            controller: controller,
            scrollController: _scroll,
            perPage: perPage,
            child: PostGrid<Post>(
              controller: controller,
              scrollController: _scroll,
              selectionModeController: _selection,
              safeArea: false,
              header: PostGridConfigurationHeader<Post>(
                additionalControls: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: TimelineOptionSelector<RelatedPostsOrder>(
                      label: order.localize(context),
                      value: order,
                      options: RelatedPostsOrder.values,
                      optionLabel: (value) => value.localize(context),
                      optionIcon: (_) => Symbols.swap_vert,
                      onSelected: _setOrder,
                    ),
                  ),
                ],
              ),
              gridBuilder: (context, itemBuilder) => ListenableBuilder(
                listenable: controller,
                builder: (context, _) =>
                    !controller.refreshing &&
                        !controller.hasMore &&
                        controller.items.isEmpty &&
                        controller.errors.value == null
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(context.t.bookmark.related_unavailable),
                              TextButton(
                                onPressed: controller.refresh,
                                child: Text(context.t.generic.action.retry),
                              ),
                            ],
                          ),
                        ),
                      )
                    : PostGridSliver<Post>(
                        postController: controller,
                        itemBuilder: itemBuilder,
                      ),
              ),
              sliverHeaders: [
                ViewerEntryNavigationHeader(
                  actions: [
                    BookmarkGroupPickerAnchor(
                      request: RelatedBookmarkPickerRequest(
                        config: config,
                        family: widget.entry.family,
                      ),
                      builder: (context, show) => IconButton(
                        tooltip: context.t.bookmark.bookmark_related,
                        onPressed: show,
                        icon: Icon(
                          Symbols.bookmark,
                          fill: saved?.groupIds.isNotEmpty == true ? 1 : 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              itemBuilder: (context, index, scroll, useHero) =>
                  DanbooruPostListingContextMenu(
                    index: index,
                    controller: controller,
                    child: DefaultDanbooruImageGridItem(
                      index: index,
                      autoScrollController: scroll,
                      controller: controller,
                      useHero: false,
                      onTap: () => goToPostDetailsPageFromController(
                        ref: ref,
                        initialIndex: index,
                        controller: controller,
                        initialThumbnailUrl: null,
                        config: config,
                        hero: false,
                      ),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
