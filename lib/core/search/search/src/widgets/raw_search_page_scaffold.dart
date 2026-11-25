// Dart imports:
import 'dart:math';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/widgets.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:selection_mode/selection_mode.dart';

// Project imports:
import '../../../../../foundation/utils/stream/text_editing_controller_utils.dart';
import '../../../../analytics/providers.dart';
import '../../../../analytics/types.dart';
import '../../../../configs/config/providers.dart';
import '../../../../posts/listing/providers.dart';
import '../../../../posts/listing/types.dart';
import '../../../../posts/listing/widgets.dart';
import '../../../../posts/listing/src/widgets/timeline_toolbar_host.dart';
import '../../../../posts/post/types.dart';
import '../../../../settings/providers.dart';
import '../../../../widgets/widgets.dart';
import '../../../histories/providers.dart';
import '../../../selected_tags/providers.dart';
import '../../../selected_tags/types.dart';
import '../routes/params.dart';
import '../types/search_bar_position.dart';
import 'search_controller.dart';

typedef IndexedSelectableSearchWidgetBuilder<T extends Post> = Widget Function(
  BuildContext context,
  int index,
  AutoScrollController autoScrollController,
  PostGridController<T> controller,
  bool useHero,
);

typedef NativeSearchResultBuilder = Widget Function(
  BuildContext context,
  String query,
  int initialPage,
  int? initialScrollPosition,
  PageMode? pageMode,
  Widget header,
  Widget? leadingSliver,
);

const kSearchBarHeight = kToolbarHeight;
const kSelectedSearchTagHeight = 48.0;

class RawSearchPageScaffold<T extends Post> extends ConsumerStatefulWidget {
  const RawSearchPageScaffold({
    required this.fetcher,
    required this.params,
    required this.tagsController,
    required this.controller,
    required this.selectionModeController,
    required this.onQueryChanged,
    required this.searchRegion,
    required this.searchSuggestions,
    required this.resultHeader,
    required this.onPostControllerCreated,
    required this.landingView,
    super.key,
    this.extraHeaders,
    this.itemBuilder,
    this.resultGridBuilder,
    this.nativeResultBuilder,
  });

  final NativeSearchResultBuilder? nativeResultBuilder;

  final SearchParams params;

  String? get initialQuery => params.query;
  int? get initialPage => params.page;
  int? get initialScrollPosition => params.scrollPosition;

  final List<Widget> Function(
    BuildContext context,
    PostGridController<T> postController,
  )?
  extraHeaders;

  final PostsOrErrorCore<T> Function(
    int page,
    SelectedTagController selectedTagController,
  )
  fetcher;

  final IndexedSelectableSearchWidgetBuilder<T>? itemBuilder;
  final Widget Function(
    BuildContext,
    PostGridController<T>,
    IndexedWidgetBuilder,
  )?
  resultGridBuilder;

  final Widget landingView;

  final SelectedTagController tagsController;
  final SearchPageController controller;
  final SelectionModeController selectionModeController;
  final void Function(String value) onQueryChanged;
  final Widget searchRegion;
  final Widget searchSuggestions;
  final Widget resultHeader;
  final void Function(PostGridController<T> controller) onPostControllerCreated;

  @override
  ConsumerState<RawSearchPageScaffold<T>> createState() =>
      _SearchPageScaffoldState<T>();
}

class _SearchPageScaffoldState<T extends Post>
    extends ConsumerState<RawSearchPageScaffold<T>>
    with SingleTickerProviderStateMixin {
  SelectedTagController get _tagsController => widget.tagsController;
  final _scrollController = AutoScrollController();

  final _topics = CompositeSubscription();
  SearchPageController get _controller => widget.controller;

  late final _searchBarAnimController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  SelectionModeController get _selectionModeController =>
      widget.selectionModeController;

  var _keyboardWasVisible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final hidden = _keyboardWasVisible && !visible;
    _keyboardWasVisible = visible;
    if (!hidden) return;
    // An unused transparent editor must not leave a modal barrier over Browse
    // after Android dismisses only the IME. Advanced UI owns its own dismissal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || MediaQuery.viewInsetsOf(context).bottom > 0) return;
      if (_controller.didSearchOnce.value ||
          _controller.state.value != SearchState.initial ||
          _controller.textController.text.isNotEmpty ||
          _tagsController.tags.isNotEmpty ||
          _controller.editingTag.value != null) {
        return;
      }
      final route = ModalRoute.of(context);
      if (route != null && route.isCurrent && route.impliesAppBarDismissal) {
        Navigator.of(context).pop();
      }
    });
  }

  var _hasScrolledToInitialPosition = false;
  late final String _restoredQuery;
  var _useRoutePosition = true;

  @override
  void initState() {
    super.initState();

    if (widget.initialPage != null) {
      _controller.skipToResultWithTag(
        widget.initialQuery ?? '',
        queryType: widget.params.queryType,
      );
    } else if (widget.initialQuery case final String query) {
      _controller.skipToResultWithTag(
        query,
        queryType: widget.params.queryType,
      );
      ref
          .read(searchHistoryProvider.notifier)
          .addHistoryFromController(_tagsController, ref.readConfigAuth);
    } else if (widget.params.tags case final SearchTagSet tags) {
      _controller.skipToResultWithTags(
        tags,
        queryType: widget.params.queryType,
      );
      ref
          .read(searchHistoryProvider.notifier)
          .addHistoryFromController(_tagsController, ref.readConfigAuth);
    }
    _restoredQuery = _controller.tagString.value;

    _controller.textController
        .textAsStream()
        .startWith(_controller.textController.text)
        .pairwise()
        .listen((pair) {
          _onQueryChanged(pair.first, pair.last);
        })
        .addTo(_topics);

    _tagsController.addListener(_onSelectedTagChanged);
    _controller.tagString.addListener(_onTagChanged);
  }

  final _toolbarHost = TimelineToolbarHost();
  final _panelExtents = ValueNotifier((editor: 0.0, toolbar: 0.0));
  var _userScroll = false;

  void _measureEditor(Size size) {
    if (!mounted) return;
    _panelExtents.value = (
      editor: size.height,
      toolbar: _panelExtents.value.toolbar,
    );
  }

  void _measureToolbar(Size size) {
    if (!mounted) return;
    _panelExtents.value = (
      editor: _panelExtents.value.editor,
      toolbar: size.height,
    );
  }

  void _onTagChanged() {
    _toolbarHost.clear();
    _userScroll = false;
    _searchBarAnimController.value = 0;
    if (_controller.tagString.value != _restoredQuery) {
      _useRoutePosition = false;
    }
    _selectionModeController.disable();
    // check if scroll controller is attached
    if (_scrollController.hasClients) {
      // scroll to top when tag is added
      _scrollController.jumpTo(0);
    }
  }

  void _onQueryChanged(String previous, String current) {
    if (previous == current) {
      return;
    }

    _controller.onQueryChanged(current);

    widget.onQueryChanged(current);
  }

  void _onSelectedTagChanged() {
    _controller.allowSearch.value = _tagsController.rawTags.isNotEmpty;
  }

  @override
  void dispose() {
    _tagsController.removeListener(_onSelectedTagChanged);
    _controller.tagString.removeListener(_onTagChanged);

    _topics.dispose();
    _scrollController.dispose();
    _searchBarAnimController.dispose();
    _toolbarHost.dispose();
    _panelExtents.dispose();

    super.dispose();
  }

  PostGridController<T>? _postController;

  void _setupPostControllerListener(PostGridController<T> controller) {
    if (_postController != controller) {
      if (_useRoutePosition && widget.initialScrollPosition != null) {
        controller.events.takeWhile((_) => _useRoutePosition && mounted).listen(
          (event) {
            if (event is PostControllerRefreshCompleted &&
                !_hasScrolledToInitialPosition &&
                widget.initialScrollPosition != null) {
              _scrollController.scrollToIndex(
                widget.initialScrollPosition!,
              );
              _hasScrolledToInitialPosition = true;
            }
          },
        );
      }

      _postController = controller;
      widget.onPostControllerCreated(controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = ref.watch(searchBarPositionProvider) == SearchBarPosition.top;
    return TimelineToolbarHostScope(
      host: top ? _toolbarHost : null,
      child: _buildPage(context, top),
    );
  }

  Widget _buildPage(BuildContext context, bool top) {
    final searchPinned = ref.watch(
      settingsProvider.select(
        (value) => value.searchBarScrollBehavior.persistSearchBar,
      ),
    );
    final toolbarPinned = ref.watch(
      imageListingSettingsProvider.select(
        (value) => value.keepTimelineToolbarVisible,
      ),
    );
    final leadingSliver = top
        ? ValueListenableBuilder(
            valueListenable: _panelExtents,
            builder: (_, extents, _) => SliverToBoxAdapter(
              child: SizedBox(
                height:
                    (searchPinned ? 0 : extents.editor) +
                    (toolbarPinned ? 0 : extents.toolbar),
              ),
            ),
          )
        : null;
    return InheritedSearchPageController(
      controller: _controller,
      child: Material(
        type: MaterialType.transparency,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            _controller.didSearchOnce,
            _controller.state,
          ]),
          builder: (context, child) => ColoredBox(
            key: const ValueKey('search-route-surface'),
            color:
                _controller.didSearchOnce.value ||
                    _controller.state.value != SearchState.initial
                ? Kurumi.themeOf(context).colorScheme.surface
                : Colors.transparent,
            child: child,
          ),
          child: SafeArea(
            bottom: false,
            child: ListenableBuilder(
              listenable: Listenable.merge([
                _searchBarAnimController,
                _toolbarHost,
                _panelExtents,
                _selectionModeController,
                _controller.state,
                _controller.didSearchOnce,
              ]),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ValueListenableBuilder(
                    valueListenable: _controller.state,
                    builder: (context, state, child) => ExcludeSemantics(
                      excluding: state != SearchState.initial,
                      child: ExcludeFocus(
                        excluding: state != SearchState.initial,
                        child: child!,
                      ),
                    ),
                    child: ValueListenableBuilder(
                      valueListenable: _controller.didSearchOnce,
                      builder: (context, searched, _) => searched
                          ? _buildResult(leadingSliver)
                          : const SizedBox.shrink(),
                    ),
                  ),
                  ValueListenableBuilder(
                    valueListenable: _controller.state,
                    builder: (context, state, _) => state == SearchState.initial
                        ? const SizedBox.shrink()
                        : Positioned.fill(
                            child: ColoredBox(
                              key: const ValueKey('search-editor-background'),
                              color: Kurumi.themeOf(context)
                                  .colorScheme
                                  .surface,
                            ),
                          ),
                  ),
                  _SearchOptionsView(
                    landingView: widget.landingView,
                    selectionModeController: _selectionModeController,
                  ),
                  widget.searchSuggestions,
                ],
              ),
              builder: (context, child) {
                final resultsActive =
                    _controller.didSearchOnce.value &&
                    _controller.state.value == SearchState.initial;
                final hidden =
                    !resultsActive || _selectionModeController.isActive
                    ? 0.0
                    : _searchBarAnimController.value;
                final editor = KurumiMeasureSize(
                  onChange: _measureEditor,
                  child: widget.searchRegion,
                );
                final toolbar = Visibility(
                  visible: resultsActive,
                  maintainState: true,
                  child: KurumiMeasureSize(
                    onChange: _measureToolbar,
                    child: _toolbarHost.toolbar ?? const SizedBox.shrink(),
                  ),
                );
                // When both rows hide, clip the entire natural-height Column.
                // Neither row has an independent displacement or snap driver.
                final together = !searchPinned && !toolbarPinned;
                final panel = top
                    ? ColoredBox(
                        color: Kurumi.themeOf(context).colorScheme.surface,
                        child: _collapse(
                          hidden: together ? hidden : 0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _collapse(
                                hidden: together || searchPinned ? 0 : hidden,
                                child: editor,
                              ),
                              _collapse(
                                hidden: together || toolbarPinned ? 0 : hidden,
                                child: toolbar,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _collapse(
                        hidden: searchPinned ? 0 : hidden,
                        alignment: Alignment.topCenter,
                        child: editor,
                      );
                final extents = _panelExtents.value;
                return CustomMultiChildLayout(
                  delegate: _SearchViewportLayout(
                    top: top,
                    pinnedExtent: top && resultsActive && extents.editor > 0
                        ? (searchPinned ? extents.editor : 0.0) +
                              (toolbarPinned ? extents.toolbar : 0.0)
                        : null,
                  ),
                  children: [
                    LayoutId(id: _SearchViewportChild.content, child: child!),
                    LayoutId(id: _SearchViewportChild.panel, child: panel),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _collapse({
    required double hidden,
    required Widget child,
    Alignment alignment = Alignment.bottomCenter,
  }) => ClipRect(
    child: Align(
      alignment: alignment,
      heightFactor: 1 - hidden,
      child: IgnorePointer(
        ignoring: hidden == 1,
        child: ExcludeFocus(
          excluding: hidden == 1,
          child: ExcludeSemantics(excluding: hidden == 1, child: child),
        ),
      ),
    ),
  );

  bool _onResultScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      _userScroll = notification.dragDetails != null;
      if (_userScroll) _searchBarAnimController.stop();
    }
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      _userScroll = true;
    }
    final pixels = notification.metrics.pixels;
    if (notification is ScrollUpdateNotification &&
        !notification.metrics.outOfRange &&
        pixels <= notification.metrics.minScrollExtent) {
      // The leading spacer is visible at the top, including after a jump.
      _searchBarAnimController.value = 0;
      return false;
    }
    final settings = ref.read(settingsProvider);
    final top = ref.read(searchBarPositionProvider) == SearchBarPosition.top;
    final searchPinned = settings.searchBarScrollBehavior.persistSearchBar;
    final toolbarPinned = ref
        .read(imageListingSettingsProvider)
        .keepTimelineToolbarVisible;
    final extents = _panelExtents.value;
    final extent =
        (searchPinned ? 0.0 : extents.editor) +
        (top && !toolbarPinned && _toolbarHost.toolbar != null
            ? extents.toolbar
            : 0.0);
    if (!_userScroll ||
        extent <= 0 ||
        _controller.state.value != SearchState.initial ||
        _selectionModeController.isActive) {
      if (notification is ScrollEndNotification) _userScroll = false;
      return false;
    }
    if (notification is ScrollUpdateNotification &&
        !notification.metrics.outOfRange) {
      _searchBarAnimController.value =
          ((_searchBarAnimController.value * extent +
                      (notification.scrollDelta ?? 0)) /
                  extent)
              .clamp(0.0, 1.0);
    } else if (notification is ScrollEndNotification) {
      _userScroll = false;
      final target = pixels < extent || _searchBarAnimController.value <= .5
          ? 0.0
          : 1.0;
      if (settings.reduceAnimations) {
        _searchBarAnimController.value = target;
      } else {
        _searchBarAnimController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
    return false;
  }

  Widget _buildResult(Widget? leadingSliver) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onResultScroll,
      child: ValueListenableBuilder(
        valueListenable: _controller.tagString,
        builder: (context, query, _) => widget.nativeResultBuilder != null
            ? widget.nativeResultBuilder!(
                context,
                query,
                _useRoutePosition ? widget.initialPage ?? 1 : 1,
                _useRoutePosition ? widget.initialScrollPosition : null,
                _useRoutePosition && widget.initialPage != null
                    ? PageMode.paginated
                    : null,
                widget.resultHeader,
                leadingSliver,
              )
            : PostScope(
                // Each applied query owns its requests and pagination. Replacing this
                // scope logically cancels old work without waiting for the server.
                key: ValueKey(query),
                fetcher: (page) => widget.fetcher(
                  page,
                  _controller.tagsController,
                ),
                pageMode: _useRoutePosition && widget.initialPage != null
                    ? PageMode.paginated
                    : null,
                initialPage: _useRoutePosition ? widget.initialPage : null,
                builder: (context, controller) {
                  // Hacky way to get the controller
                  _setupPostControllerListener(controller);
                  return _buildDefaultSearchResults(
                    context,
                    controller,
                    leadingSliver,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildDefaultSearchResults(
    BuildContext context,
    PostGridController<T> controller,
    Widget? leadingSliver,
  ) {
    return ColoredBox(
      color: Kurumi.themeOf(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: PostGrid<T>(
          gridBuilder: widget.resultGridBuilder == null
              ? null
              : (context, itemBuilder) =>
                    widget.resultGridBuilder!(context, controller, itemBuilder),
          selectionModeController: _selectionModeController,
          scrollController: _scrollController,
          controller: controller,
          itemBuilder: widget.itemBuilder != null
              ? (context, index, scrollController, useHero) {
                  return widget.itemBuilder!(
                    context,
                    index,
                    _scrollController,
                    controller,
                    useHero,
                  );
                }
              : null,
          scrollToTopButton: PostGridScrollToTopButton(
            controller: controller,
            autoScrollController: _scrollController,
          ),
          sliverHeaders: [
            ?leadingSliver,
            const SearchResultAnalyticsAnchor(),
            if (widget.extraHeaders != null)
              ...widget.extraHeaders!(
                context,
                controller,
              ),
            SliverToBoxAdapter(
              child: widget.resultHeader,
            ),
          ],
        ),
      ),
    );
  }
}

enum _SearchViewportChild { content, panel }

class _SearchViewportLayout extends MultiChildLayoutDelegate {
  _SearchViewportLayout({required this.top, required this.pinnedExtent});

  final bool top;
  final double? pinnedExtent;

  @override
  void performLayout(Size size) {
    final panel = layoutChild(
      _SearchViewportChild.panel,
      BoxConstraints(
        minWidth: size.width,
        maxWidth: size.width,
        maxHeight: size.height,
      ),
    );
    // While results are active, the leading sliver reserves the floating part.
    // Moving the viewport as well would add the panel's travel to every tile.
    final reserved = (pinnedExtent ?? panel.height).clamp(0.0, size.height);
    layoutChild(
      _SearchViewportChild.content,
      BoxConstraints.tight(Size(size.width, size.height - reserved)),
    );
    positionChild(_SearchViewportChild.content, Offset(0, top ? reserved : 0));
    positionChild(
      _SearchViewportChild.panel,
      Offset(0, top ? 0 : size.height - panel.height),
    );
  }

  @override
  bool shouldRelayout(_SearchViewportLayout oldDelegate) =>
      top != oldDelegate.top || pinnedExtent != oldDelegate.pinnedExtent;
}

class SearchRegionSafeArea extends ConsumerWidget {
  const SearchRegionSafeArea({
    required this.child,
    required this.selectionModeController,
    super.key,
  });

  final Widget child;
  final SelectionModeController selectionModeController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(searchBarPositionProvider) == SearchBarPosition.top;
    return Padding(
      // The surrounding Column already reserves the complete editor. A top
      // editor leaves only native bottom obstructions for its panels to avoid.
      padding: EdgeInsets.only(
        bottom: top
            ? max(
                MediaQuery.viewInsetsOf(context).bottom,
                MediaQuery.viewPaddingOf(context).bottom,
              )
            : 0,
      ),
      child: child,
    );
  }
}

class _SearchOptionsView extends ConsumerWidget {
  const _SearchOptionsView({
    required this.landingView,
    required this.selectionModeController,
  });

  final Widget landingView;
  final SelectionModeController selectionModeController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = InheritedSearchPageController.of(context);
    final colorScheme = Kurumi.themeOf(context).colorScheme;

    return SearchRegionSafeArea(
      selectionModeController: selectionModeController,
      child: FocusTraversalGroup(
        child: MultiValueListenableBuilder2(
          first: controller.state,
          second: controller.didSearchOnce,
          builder: (context, state, searched) => state == SearchState.options
              ? ColoredBox(
                  color: colorScheme.surface,
                  child: Column(
                    children: [
                      ref
                          .watch(analyticsProvider)
                          .maybeWhen(
                            data: (analytics) => SearchViewAnalyticsAnchor(
                              routeName: '/search_options',
                              previousRoute: const RouteSettings(
                                name: '/search_result',
                              ),
                              analytics: analytics,
                            ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                      Expanded(
                        child: landingView,
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class SearchResultAnalyticsAnchor extends ConsumerStatefulWidget {
  const SearchResultAnalyticsAnchor({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _SearchResultAnalyticsAnchorState();
}

class _SearchResultAnalyticsAnchorState
    extends ConsumerState<SearchResultAnalyticsAnchor> {
  @override
  void initState() {
    super.initState();
    ref
        .read(analyticsProvider)
        .whenData(
          (analytics) => analytics?.logScreenView('/search_result'),
        );
  }

  @override
  Widget build(BuildContext context) {
    return const SliverSizedBox.shrink();
  }
}

class SearchViewAnalyticsAnchor extends ConsumerStatefulWidget {
  const SearchViewAnalyticsAnchor({
    required this.routeName,
    required this.previousRoute,
    required this.analytics,
    super.key,
  });

  final String routeName;

  final RouteSettings? previousRoute;
  final AnalyticsInterface? analytics;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _SuggestionViewAnalyticsAnchoreState();
}

class _SuggestionViewAnalyticsAnchoreState
    extends ConsumerState<SearchViewAnalyticsAnchor> {
  @override
  void initState() {
    super.initState();
    widget.analytics?.logScreenView(widget.routeName);
  }

  @override
  void dispose() {
    final name = widget.previousRoute?.name;

    if (name != null) {
      widget.analytics?.logScreenView(name);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
