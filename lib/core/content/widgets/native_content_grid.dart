import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:sliver_masonry_grid/sliver_masonry_grid.dart';

import '../../configs/manage/widgets.dart';
import '../../configs/config/types.dart';
import '../../http/client/coordination.dart';
import '../../images/booru_image.dart';
import '../../posts/details/routes.dart';
import '../../posts/details/src/routes/post_details_live_source.dart';
import '../../posts/details/src/types/viewer_entry.dart';
import '../../posts/listing/src/types/page_mode.dart';
import '../../posts/listing/src/types/grid_utils.dart';
import '../../posts/listing/src/types/image_list_type.dart';
import '../../posts/listing/src/widgets/timeline_header_sliver.dart';
import '../../posts/listing/providers.dart';
import '../../settings/providers.dart';
import '../../posts/listing/src/types/timeline_continuation_controller.dart';
import '../../posts/listing/src/widgets/post_grid_prefetch.dart';
import '../../posts/listing/src/widgets/post_grid_item.dart';
import '../../posts/pools/pool_grid_item.dart';
import '../../posts/post/types.dart';
import '../content_access_provider.dart';
import '../groups/group_capability.dart';
import '../groups/group_source_provider.dart';
import '../types.dart';
import 'native_content_configuration_header.dart';

final class NativeContentPage {
  NativeContentPage({
    required Iterable<ContentEntry> entries,
    required this.hasMore,
    this.total,
    this.rawCount,
  }) : entries = List.unmodifiable(entries);
  final List<ContentEntry> entries;
  final bool hasMore;
  final int? total;
  final int? rawCount;
}

/// One native Work/Gallery occurrence per card, using the common viewport
/// continuation controller and the ordinary mixed viewer route.
class NativeContentGrid extends ConsumerStatefulWidget {
  const NativeContentGrid({
    required this.access,
    required this.fetchPage,
    this.queryIdentity,
    this.pageMode = PageMode.infinite,
    this.initialPage = 1,
    this.onRefresh,
    this.header,
    this.sliverHeaders = const [],
    this.allowPageModeChange = false,
    this.counterLabel,
    this.groupLabel,
    super.key,
  });
  static NativeContentController controllerOf(BuildContext context) =>
      context.findAncestorStateOfType<_NativeContentGridState>()?._controller ??
      (throw StateError('No native content timeline in context'));

  final ContentAccessContext access;
  final Future<NativeContentPage> Function(int page) fetchPage;
  final Object? queryIdentity;
  final PageMode pageMode;
  final int initialPage;
  final VoidCallback? onRefresh;
  final Widget? header;
  final List<Widget> sliverHeaders;
  final bool allowPageModeChange;
  final String Function(BuildContext, int)? counterLabel;
  final String Function(BuildContext, ContentGroupSummary)? groupLabel;
  @override
  ConsumerState<NativeContentGrid> createState() => _NativeContentGridState();
}

class _NativeContentGridState extends ConsumerState<NativeContentGrid> {
  late NativeContentController _controller;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _createController();
  }

  void _createController() {
    final access = widget.access;
    _controller = NativeContentController(
      access: access,
      fetchPage: (page) => widget.fetchPage(page),
      current: () =>
          mounted &&
          (ref
                  .read(contentAccessContextProvider(access.key))
                  ?.hasSameAuthorization(access) ??
              false),
      pageMode: widget.pageMode,
      initialPage: widget.initialPage,
      onRefresh: () => widget.onRefresh?.call(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_controller.access, access)) {
        unawaited(_controller.refresh());
      }
    });
  }

  @override
  void didUpdateWidget(NativeContentGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.access.hasSameAuthorization(oldWidget.access) ||
        widget.queryIdentity != oldWidget.queryIdentity ||
        widget.pageMode != oldWidget.pageMode ||
        widget.initialPage != oldWidget.initialPage) {
      _controller.dispose();
      _createController();
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = ref.watch(imageListingSettingsProvider);
    final current = ref.watch(contentAccessContextProvider(widget.access.key));
    if (current == null || !current.hasSameAuthorization(widget.access)) {
      return Center(child: Text(context.t.navigation.unavailable_profile));
    }
    return CurrentBooruConfigScope(
      config: widget.access.config!,
      accessKey: widget.access.key,
      requireAccess: true,
      child: SafeArea(
        bottom: false,
        left: false,
        child: Material(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => LayoutBuilder(
              builder: (context, size) {
                final columns = calculateGridCount(
                  size.maxWidth,
                  listing.gridSize,
                );
                final timeline = PostGridPrefetch(
                  controller: _controller,
                  scrollController: _scroll,
                  child: RefreshIndicator(
                    onRefresh: _controller.refresh,
                    child: CustomScrollView(
                      controller: _scroll,
                      scrollCacheExtent: const ScrollCacheExtent.viewport(1),
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        ...widget.sliverHeaders,
                        if (widget.header case final header?)
                          SliverToBoxAdapter(child: header),
                        if (_controller.entries.isNotEmpty)
                          TimelineHeaderSliver(
                            keepVisible: listing.keepTimelineToolbarVisible,
                            reduceMotion: ref.watch(
                              settingsProvider.select(
                                (value) => value.reduceAnimations,
                              ),
                            ),
                            child: NativeContentConfigurationHeader(
                              count: _controller.entries.length,
                              counterLabel: widget.counterLabel?.call(
                                context,
                                _controller.entries.length,
                              ),
                              allowPageModeChange: widget.allowPageModeChange,
                            ),
                          ),
                        SliverPadding(
                          padding: EdgeInsets.all(listing.imageGridPadding),
                          sliver: listing.imageListType == ImageListType.masonry
                              ? SliverMasonryGrid.count(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: listing.imageGridSpacing,
                                  crossAxisSpacing: listing.imageGridSpacing,
                                  childCount: _controller.entries.length,
                                  itemBuilder: (context, index) => _masonryCard(
                                    context,
                                    index,
                                    listing.imageGridAspectRatio,
                                  ),
                                )
                              : SliverGrid.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        childAspectRatio:
                                            listing.imageGridAspectRatio,
                                        mainAxisSpacing:
                                            listing.imageGridSpacing,
                                        crossAxisSpacing:
                                            listing.imageGridSpacing,
                                      ),
                                  itemCount: _controller.entries.length,
                                  itemBuilder: (context, index) =>
                                      _card(context, index),
                                ),
                        ),
                        SliverToBoxAdapter(child: _footer(context)),
                      ],
                    ),
                  ),
                );
                final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
                final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
                return Stack(
                  children: [
                    Positioned.fill(child: timeline),
                    Positioned(
                      right: 12,
                      bottom:
                          (bottomInset > bottomPadding
                              ? bottomInset
                              : bottomPadding) +
                          8,
                      child: KurumiScrollToTop(
                        scrollController: _scroll,
                        layoutChanges: _controller,
                        child: KurumiScrollToTopButton(
                          onPressed: () => _scroll.jumpTo(0),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _masonryCard(BuildContext context, int index, double fallbackRatio) {
    final entry = _controller.entries[index];
    final ratio = switch (entry) {
      PostContentEntry(:final post) => post.aspectRatio ?? fallbackRatio,
      GroupContentEntry(:final summary)
          when summary.cover?.width != null && summary.cover?.height != null =>
        summary.cover!.width! / summary.cover!.height!,
      _ => fallbackRatio,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var captionHeight = 0.0;
        if (entry
            case GroupContentEntry(
              summary: ContentGroupSummary(title: final title?),
            )
            when title.isNotEmpty) {
          // PoolGridItem keeps its two-line caption outside the cover. Reserve
          // its measured height so narrow/enlarged text cannot squeeze the image.
          final painter = TextPainter(
            text: TextSpan(
              text: title.replaceAll('_', ' '),
              style: DefaultTextStyle.of(context).style
                  .merge(const TextStyle(fontWeight: FontWeight.w600)),
            ),
            maxLines: 2,
            ellipsis: '…',
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: (width - 12).clamp(0, double.infinity));
          captionHeight = painter.height;
          painter.dispose();
        }
        return SizedBox(
          height: width / (ratio > 0 ? ratio : 1) + captionHeight + 4,
          child: _card(context, index),
        );
      },
    );
  }

  Widget _card(BuildContext context, int index) {
    final entry = _controller.entries[index];
    final group = entry is GroupContentEntry ? entry.summary : null;
    final post = entry is PostContentEntry ? entry.post : null;
    final cover = group?.cover;
    final image = cover == null
        ? post?.thumbnailImageUrl ?? ''
        : defaultStaticGridThumbnailUrl(
            thumbnail: cover.thumbnail.toString(),
            sample: (cover.sample ?? cover.thumbnail).toString(),
            original: (cover.original ?? cover.sample ?? cover.thumbnail)
                .toString(),
            isVideo: false,
            settings: ref.watch(
              gridThumbnailSettingsProvider(widget.access.config!.auth),
            ),
          );
    if (post != null) {
      return PostGridItem(
        post: post,
        index: index,
        useHero: false,
        multiSelectEnabled: false,
        selectionEnabled: false,
        config: widget.access.config!.auth,
        onTap: (media) => _open(index, media.url),
      );
    }
    final tile = PoolGridItem(
      category: group == null ? null : widget.groupLabel?.call(context, group),
      name: group?.title,
      total: group?.memberCount,
      image: image.isEmpty
          ? const Center(child: Icon(Icons.image_not_supported_outlined))
          : BooruImage(
              imageUrl: image,
              config: widget.access.config!.auth,
              fit:
                  ref.watch(imageListingSettingsProvider).imageListType ==
                      ImageListType.classic
                  ? BoxFit.contain
                  : BoxFit.cover,
              forceCover:
                  ref.watch(imageListingSettingsProvider).imageListType ==
                  ImageListType.standard,
            ),
      onTap: () => _open(index, image),
    );
    final presentation = group == null
        ? null
        : ref
              .watch(booruGroupCapabilityProvider(group.reference.engine))
              ?.presentation;
    return presentation is BooruMediaGroupBookmarkPresentation && group != null
        ? (presentation as BooruMediaGroupBookmarkPresentation)
              .wrapBookmarkMenu(
                context,
                GroupBookmarkPresentationData(
                  access: widget.access,
                  summary: group,
                ),
                tile,
              )
        : tile;
  }

  void _open(int index, String image) => goToPostDetailsPageCore<Post>(
    ref: ref,
    posts: [
      for (final item in _controller.entries)
        if (item is PostContentEntry) item.post,
    ],
    initialIndex: index,
    initialThumbnailUrl: image.isEmpty ? null : image,
    hero: false,
    config: widget.access.config,
    entries: _controller.viewerEntries.toList(),
    entrySource: ViewerEntryLiveSource(
      changes: _controller,
      entries: () => _controller.viewerEntries.toList(),
      pagination: PostDetailsLiveSource(
        changes: _controller,
        posts: () => [
          for (final item in _controller.entries)
            if (item is PostContentEntry) item.post,
        ],
        hasMore: () =>
            widget.pageMode == PageMode.infinite && _controller.hasMore,
        loading: () => _controller.loadingMore,
        failed: () => _controller.errors.value != null,
        fetchMore: _controller.fetchMore,
      ),
    ),
  );

  Widget _footer(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_controller.loadingMore) const CircularProgressIndicator(),
        if (!_controller.loadingMore &&
            _controller.entries.isEmpty &&
            _controller.errors.value == null)
          Text(context.t.search.no_result),
        if (_controller.errors.value != null)
          Text(context.t.search.errors.failed_to_load_data),
        if (!_controller.loadingMore && _controller.errors.value != null)
          TextButton(
            onPressed: _controller.retry,
            child: Text(context.t.generic.action.retry),
          ),
        if (widget.pageMode == PageMode.paginated)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _controller.page > 1 && !_controller.loadingMore
                    ? () => _controller.loadPage(_controller.page - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: context.t.generic.action.back,
              ),
              Text('${_controller.page}'),
              IconButton(
                onPressed: _controller.hasMore && !_controller.loadingMore
                    ? () => _controller.loadPage(_controller.page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: context.t.infinite_scroll.next_page,
              ),
            ],
          )
        else if (_controller.hasMore &&
            !_controller.loadingMore &&
            _controller.errors.value == null)
          TextButton(
            onPressed: _controller.fetchMore,
            child: Text(context.t.infinite_scroll.load_more),
          ),
      ],
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }
}

/// Pure source/page state is testable independently from a rendered viewport.
final class NativeContentController extends ChangeNotifier
    implements TimelineContinuationController {
  NativeContentController({
    required this.access,
    required this.fetchPage,
    required this.current,
    this.pageMode = PageMode.infinite,
    this.initialPage = 1,
    this.onRefresh,
  }) : page = initialPage;
  final ContentAccessContext access;
  final Future<NativeContentPage> Function(int page) fetchPage;
  final bool Function() current;
  final int initialPage;
  final VoidCallback? onRefresh;
  @override
  final PageMode pageMode;
  final _errors = ValueNotifier<Object?>(null);
  @override
  ValueNotifier<Object?> get errors => _errors;
  final entries = <ContentEntry>[];
  final viewerEntries = <ViewerEntry>[];
  @override
  var refreshing = false;
  @override
  var loadingMore = false;
  var _manualContinuationRevision = 0;
  @override
  int get continuationDispatchRevision => _continuationDispatchRevision;
  var _continuationDispatchRevision = 0;
  @override
  int get manualContinuationRevision => _manualContinuationRevision;
  @override
  var hasMore = true;
  int page;
  var _disposed = false;
  var _generation = 0;
  var _loaded = false;
  int? _failedPage;
  CancelToken? _request;

  Future<void> refresh() async {
    _generation++;
    _request?.cancel('Native timeline refreshed');
    loadingMore = false;
    refreshing = true;
    entries.clear();
    viewerEntries.clear();
    _loaded = false;
    hasMore = true;
    onRefresh?.call();
    await _load(initialPage, replace: true);
  }

  Future<void> loadPage(int requested) => _load(requested, replace: true);
  Future<void> retry() => _load(
    _failedPage ?? page,
    replace: !_loaded || pageMode == PageMode.paginated,
  );
  @override
  Future<void> fetchMore({bool Function()? canStart}) {
    if (canStart == null && !_disposed && !loadingMore && hasMore) {
      _manualContinuationRevision++;
      notifyListeners();
    }
    return _load(
      _loaded ? page + 1 : initialPage,
      replace: pageMode == PageMode.paginated,
      canStart: canStart,
    );
  }

  Future<void> _load(
    int requested, {
    required bool replace,
    bool Function()? canStart,
  }) async {
    if (_disposed ||
        loadingMore ||
        requested < 1 ||
        !current() ||
        (!replace && !hasMore) ||
        !(canStart?.call() ?? true)) {
      return;
    }
    final generation = _generation;
    final token = CancelToken();
    _request = token;
    bool allowed() =>
        !_disposed &&
        generation == _generation &&
        !token.isCancelled &&
        current() &&
        (canStart?.call() ?? true);
    _continuationDispatchRevision++;
    loadingMore = true;
    _failedPage = null;
    errors.value = null;
    notifyListeners();
    try {
      final result = await runWithApiRequestContext(
        ApiRequestContext(
          cancelToken: token,
          replaySafety: ApiReplaySafety.safeRead,
          canStart: allowed,
          canAdmit: allowed,
        ),
        () => fetchPage(requested),
      );
      if (!allowed()) return;
      if (result.entries.any((entry) => !access.accepts(entry.reference))) {
        throw const FormatException('Foreign native listing entry');
      }
      if (replace) {
        entries.clear();
        viewerEntries.clear();
      }
      final config = access.config!;
      final binding = access.key.profileId == null
          ? ViewerSourceBinding.publicRead(
              PostOrigin.fromSource(
                booruType: access.key.engine,
                booruId: access.key.engine.id,
                source: config.url,
              ),
            )
          : ViewerSourceBinding(config);
      for (final entry in result.entries) {
        entries.add(entry);
        viewerEntries.add(switch (entry) {
          GroupContentEntry(:final summary) => GroupViewerEntry(
            summary: summary,
            occurrenceId: Object(),
            source: binding,
          ),
          PostContentEntry(:final post) => PostViewerEntry(
            post: post,
            occurrenceId: Object(),
            source: binding,
          ),
        });
      }
      page = requested;
      hasMore = result.hasMore;
      _loaded = true;
    } catch (error) {
      if (allowed()) {
        _failedPage = requested;
        errors.value = error;
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loadingMore = false;
        refreshing = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _request?.cancel('Native timeline disposed');
    errors.dispose();
    super.dispose();
  }
}
