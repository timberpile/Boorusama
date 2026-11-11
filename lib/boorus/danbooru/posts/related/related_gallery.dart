import '../../../../core/posts/links/share_group_link_button.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:selection_mode/selection_mode.dart';

import '../../../../../core/boorus/booru/types.dart';
import '../../../../../core/bookmarks/src/widgets/bookmark_group_picker.dart';
import '../../../../../core/bookmarks/src/providers/bookmark_provider.dart';
import '../../../../../core/bookmarks/src/types/content_group_bookmark.dart'
    as native_bookmarks;
import '../../../../../core/bookmarks/src/types/legacy_group_bookmark.dart'
    as legacy_bookmarks;
import '../../../../../core/bookmarks/src/types/bookmark_library_state.dart';
import '../../../../../core/configs/config/providers.dart';
import '../../../../../core/content/content_reference.dart';
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
  }

  RelatedFamilyReference get _family {
    final reference = widget.entry.summary.reference;
    if (reference.engine != BooruType.danbooru ||
        reference.kind != ContentKind.group ||
        !reference.sourceKey.startsWith('related:')) {
      throw const FormatException('Invalid Related Group reference');
    }
    const BooruContentKeyCodec(BooruType.danbooru)
        .canonicalize(ContentKind.group, reference.sourceKey);
    return RelatedFamilyReference(
      origin: PostOrigin.fromSource(
        booruType: reference.engine,
        booruId: reference.engine.id,
        source: reference.site.toString(),
      ),
      anchorId: int.parse(reference.sourceKey.substring('related:'.length)),
    );
  }

  Object? _savedRelatedRecord(BookmarkLibraryState library) {
    final id =
        library.idByContent[(
          siteNamespace: _family.origin.sourceHost,
          kind: ContentKind.group,
          sourceKey: 'related:${_family.anchorId}',
        )];
    final record = id == null ? null : library.byId[id];
    return switch (record) {
      native_bookmarks.RelatedBookmark() => record,
      legacy_bookmarks.LegacyRelatedGroupBookmark() => record,
      _ => null,
    };
  }

  RelatedPostsOrder? _savedRelatedOrder(BookmarkLibraryState library) =>
      switch (_savedRelatedRecord(library)) {
        native_bookmarks.RelatedBookmark(:final preferredOrder?) =>
          preferredOrder,
        legacy_bookmarks.LegacyRelatedGroupBookmark(:final preferredOrder?) =>
          preferredOrder,
        _ => null,
      };

  void _initializeOrder(BookmarkLibraryState? library) {
    if (_order != null) return;
    final pageOrder = PageStorage.maybeOf(context)?.readState(
      context,
      identifier: (widget.entry.occurrenceId, 'related-order'),
    ) as RelatedPostsOrder?;
    final initial =
        pageOrder ??
        (library == null ? null : _savedRelatedOrder(library)) ??
        ref.read(settingsProvider).relatedPostsOrder;
    _order = initial;
    PageStorage.maybeOf(context)?.writeState(
      context,
      initial,
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
      final library = ref.read(bookmarkProvider).valueOrNull;
      final record = library == null ? null : _savedRelatedRecord(library);
      final savedId = switch (record) {
        native_bookmarks.RelatedBookmark(:final id) => id,
        legacy_bookmarks.LegacyRelatedGroupBookmark(:final id) => id,
        _ => null,
      };
      if (savedId != null) {
        await ref
            .read(bookmarkProvider.notifier)
            .setRelatedOrder(savedId, order);
      }
      if (!mounted) return;
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
    final libraryState = ref.watch(bookmarkProvider);
    final library = libraryState.valueOrNull;
    if (_order == null) {
      if (library == null && libraryState.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      _initializeOrder(library);
    }
    final order = _order!;
    final saved = library?.pools
        .where((p) => p.identity == _family.identity)
        .firstOrNull;
    final perPage = ref.watch(
      imageListingSettingsProvider.select((s) => s.postsPerPage),
    );
    return SafeArea(
      top: false,
      bottom: false,
      child: CustomContextMenuOverlay(
        child: GroupPostScope(
          scrollController: _scroll,
          key: ValueKey((widget.entry.occurrenceId, config, perPage, order)),
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
                    const GroupLinkShareButton(),
                    BookmarkGroupPickerAnchor(
                      request: RelatedBookmarkPickerRequest(
                        config: config,
                        family: _family,
                        visibleOrder: order,
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
