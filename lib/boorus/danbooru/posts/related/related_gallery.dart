import '../../../../core/posts/details/src/widgets/group_reading_controls.dart';
import '../../../../core/posts/pools/src/widgets/group_sort_icon.dart';
import '../../../../core/posts/links/share_group_link_button.dart';
import '../../../../core/posts/details/src/widgets/group_viewer_scope.dart';
import '../../../../core/posts/details/src/providers/group_reading_provider.dart';
import '../../../../core/posts/details/src/widgets/group_bookmark_button.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:selection_mode/selection_mode.dart';

import '../../../../../core/configs/config/providers.dart';
import '../../../../../core/content/groups/group_summary.dart';
import '../../../../../core/posts/details/routes.dart';
import '../../../../../core/posts/details/src/widgets/post_details_page_view_scope.dart';
import '../../../../../core/posts/details/src/types/viewer_entry.dart';
import '../../../../../core/posts/details/src/widgets/viewer_entry_navigation_header.dart';
import '../../../../../core/posts/details_pageview/widgets.dart';
import '../../../../../core/posts/listing/widgets.dart';
import '../../../../../core/posts/pools/group_post_scope.dart';
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
  final locator = ViewerSourceBinding(config);
  final reference = referenceForBoundGroup(
    origin: family.origin,
    sourceKey: 'related:${family.anchorId}',
    source: locator,
  );
  if (reference == null) {
    throw StateError('Related profile does not match family');
  }
  final source = config.anonymousReadScope == null
      ? locator
      : ViewerSourceBinding.publicRead(family.origin);
  goToPostDetailsPageCore<Post>(
    ref: ref,
    posts: const [],
    initialIndex: 0,
    hero: false,
    initialThumbnailUrl: null,
    config: config,
    entries: [
      GroupViewerEntry(
        summary: ContentGroupSummary(reference: reference),
        occurrenceId: Object(),
        source: source,
      ),
    ],
  );
}

class RelatedGallery extends ConsumerStatefulWidget {
  const RelatedGallery({required this.entry, super.key});
  final GroupViewerEntry entry;
  @override
  ConsumerState<RelatedGallery> createState() => _RelatedGalleryState();
}

class _RelatedGalleryState extends ConsumerState<RelatedGallery> {
  final _scroll = AutoScrollController();
  final _selection = SelectionModeController();
  PostDetailsPageViewController? _pager;
  var _selecting = false;
  Object? _scrollOrder;

  @override
  void initState() {
    super.initState();
    _selection.addListener(_selectionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pager = PostDetailsPageViewScope.maybeOf(context);
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
    final applied = await requestGroupSort(
      context,
      ref,
      widget.entry,
      order.name,
    );
    if (mounted && applied) _selection.disable();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfig;
    final reading = ref.watch(groupReadingProvider(widget.entry));
    if (reading.initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    final order = RelatedPostsOrder.values.byName(reading.orderKey!);
    if (_scrollOrder != null && _scrollOrder != order) {
      PageStorage.maybeOf(context)?.writeState(
        context,
        null,
        identifier: (widget.entry.occurrenceId, 'related-viewport', order),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollOrder == order && _scroll.hasClients) {
          _scroll.jumpTo(0);
        }
      });
    }
    _scrollOrder = order;
    final perPage = ref.watch(
      imageListingSettingsProvider.select((s) => s.postsPerPage),
    );
    return SafeArea(
      top: false,
      bottom: false,
      child: CustomContextMenuOverlay(
        child: GroupPostScope(
          scrollController: _scroll,
          key: ValueKey((widget.entry.occurrenceId, config, perPage)),
          reference: widget.entry.summary.reference,
          orderKey: order.name,
          perPage: perPage,
          builder: (context, controller) => PoolGalleryCheckpoint(
            identity: (widget.entry.occurrenceId, 'related-viewport', order),
            controller: controller,
            scrollController: _scroll,
            perPage: perPage,
            child: PostGrid<Post>(
              controller: controller,
              refreshAtStart: !controller.hasLoadedPage,
              scrollController: _scroll,
              selectionModeController: _selection,
              header: PostGridConfigurationHeader<Post>(
                additionalControls: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: TimelineOptionSelector<RelatedPostsOrder>(
                      label: order.localize(context),
                      value: order,
                      pending: reading.sorting,
                      options: RelatedPostsOrder.values,
                      optionLabel: (value) => value.localize(context),
                      optionLeading: (order) =>
                          GroupSortIcon(order.name, size: 18),
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
                  title: Text(context.t.post.detail.related_posts),
                  actions: [
                    const GroupLinkShareButton(),
                    GroupScopedBookmarkButton(
                      entry: widget.entry,
                      wholeGroup: true,
                      cachedMembers: controller.items.toList(),
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
                      onTap: () {
                        if (GroupViewerScope.openMember(
                          context,
                          controller.selectionKeysBuilder
                              ?.call(controller.items.toList())
                              .elementAtOrNull(index),
                        )) {
                          return;
                        }
                        goToPostDetailsPageFromController(
                          ref: ref,
                          initialIndex: index,
                          controller: controller,
                          initialThumbnailUrl: null,
                          config: config,
                          hero: false,
                        );
                      },
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
