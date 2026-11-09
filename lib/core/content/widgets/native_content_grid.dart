import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../configs/manage/widgets.dart';
import '../../configs/config/types.dart';
import '../../http/client/coordination.dart';
import '../../images/booru_image.dart';
import '../../posts/details/routes.dart';
import '../../posts/details/src/routes/post_details_live_source.dart';
import '../../posts/details/src/types/viewer_entry.dart';
import '../../posts/listing/src/types/page_mode.dart';
import '../../posts/listing/src/types/timeline_continuation_controller.dart';
import '../../posts/listing/src/widgets/post_grid_prefetch.dart';
import '../../posts/listing/src/widgets/post_grid_item.dart';
import '../../posts/pools/pool_grid_item.dart';
import '../../posts/post/types.dart';
import '../content_access_provider.dart';
import '../types.dart';

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
    super.key,
  });
  final ContentAccessContext access;
  final Future<NativeContentPage> Function(int page) fetchPage;
  final Object? queryIdentity;
  final PageMode pageMode;
  final int initialPage;
  final VoidCallback? onRefresh;
  final Widget? header;
  final List<Widget> sliverHeaders;
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
          ref
                  .read(contentAccessContextProvider(access.key))
                  ?.hasSameAuthorization(access) ==
              true,
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
    final current = ref.watch(contentAccessContextProvider(widget.access.key));
    if (current == null || !current.hasSameAuthorization(widget.access)) {
      return Center(child: Text(context.t.navigation.unavailable_profile));
    }
    return CurrentBooruConfigScope(
      config: widget.access.config!,
      accessKey: widget.access.key,
      requireAccess: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, size) {
            final columns = (size.maxWidth / 160).floor().clamp(2, 8);
            return PostGridPrefetch(
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
                    SliverPadding(
                      padding: const EdgeInsets.all(6),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          childAspectRatio: .72,
                        ),
                        itemCount: _controller.entries.length,
                        itemBuilder: (context, index) => _card(context, index),
                      ),
                    ),
                    SliverToBoxAdapter(child: _footer(context)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _card(BuildContext context, int index) {
    final entry = _controller.entries[index];
    final group = entry is GroupContentEntry ? entry.summary : null;
    final post = entry is PostContentEntry ? entry.post : null;
    final image =
        group?.cover?.thumbnail.toString() ?? post?.thumbnailImageUrl ?? '';
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
    return PoolGridItem(
      name: group?.title,
      total: group?.memberCount,
      image: image.isEmpty
          ? const Center(child: Icon(Icons.image_not_supported_outlined))
          : BooruImage(
              imageUrl: image,
              config: widget.access.config!.auth,
              fit: BoxFit.cover,
              forceCover: true,
            ),
      onTap: () => _open(index, image),
    );
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
          Text(context.t.bookmark.pool_unavailable),
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
  @override
  final ValueNotifier<Object?> errors = ValueNotifier<Object?>(null);
  final entries = <ContentEntry>[];
  final viewerEntries = <ViewerEntry>[];
  @override
  var refreshing = false;
  @override
  var loadingMore = false;
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
  Future<void> fetchMore({bool Function()? canStart}) => _load(
    _loaded ? page + 1 : initialPage,
    replace: pageMode == PageMode.paginated,
    canStart: canStart,
  );

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
        !(canStart?.call() ?? true))
      return;
    final generation = _generation;
    final token = CancelToken();
    _request = token;
    bool allowed() =>
        !_disposed &&
        generation == _generation &&
        !token.isCancelled &&
        current() &&
        (canStart?.call() ?? true);
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
