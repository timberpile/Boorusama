import 'package:flutter/foundation.dart' show mapEquals;

import 'dart:math' as math;

import '../../../../selection/ordered_selection_canvas.dart';
import '../../../../selection/ordered_selection_controller.dart';
import '../../../../selection/selection_input.dart';
import '../types/post_selection_identity.dart';
import '../../../../navigation/navigation_interaction_scopes.dart';

// Flutter imports:
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';

// Package imports:
import 'package:anchor_ui/anchor_ui.dart';
import 'package:auto_scrolling/auto_scrolling.dart';
import 'package:equatable/equatable.dart';
import 'package:foundation/widgets.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:oktoast/oktoast.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:selection_mode/selection_mode.dart';
import 'package:sliver_tools/sliver_tools.dart';

// Project imports:
import '../../../../../foundation/display.dart';
import '../../../../../foundation/keyboard.dart';
import '../../../../haptics/types.dart';
import '../../../../settings/providers.dart';
import '../widgets/post_selection_controls.dart';
import '../../../../widgets/widgets.dart';
import '../../../post/types.dart';
import '../types/grid_size.dart';
import '../types/grid_utils.dart';
import '../types/page_mode.dart';
import '../widgets/conditional_value_listenable_builder.dart';
import '../widgets/post_grid_controller.dart';
import 'highres_preview_on_mobile_data_warning_banner.dart';
import 'swipe_to.dart';
import 'too_much_cached_images_warning_banner.dart';

class RawPostGrid<T extends Post> extends StatefulWidget {
  const RawPostGrid({
    required this.gridHeader,
    required this.topPageIndicator,
    required this.bottomPageIndicator,
    required this.scrollToTopButton,
    required this.body,
    required this.controller,
    required this.onNextPage,
    required this.onPreviousPage,
    required this.selectionModeController,
    required this.selectionOptions,
    super.key,
    this.sliverHeaders,
    this.scrollController,
    this.footer,
    this.bottomInset = 0,
    this.selectionScope,
    this.blacklistedIdString,
    this.refreshAtStart = true,
    this.enablePullToRefresh = true,
    this.safeArea = true,
    this.options = const PostGridOptions(),
  });

  final void Function() onNextPage;
  final void Function() onPreviousPage;
  final List<Widget>? sliverHeaders;
  final AutoScrollController? scrollController;

  final bool refreshAtStart;
  final bool enablePullToRefresh;
  final bool safeArea;

  final Widget? footer;
  final double bottomInset;
  final Object? selectionScope;
  final Widget body;
  final Widget gridHeader;
  final Widget topPageIndicator;
  final Widget bottomPageIndicator;
  final Widget scrollToTopButton;

  final String? blacklistedIdString;

  final SelectionModeController selectionModeController;
  final SelectionOptions selectionOptions;

  final PostGridController<T> controller;
  final PostGridOptions options;

  @override
  State<RawPostGrid<T>> createState() => _RawPostGridState();
}

class _RawPostGridState<T extends Post> extends State<RawPostGrid<T>>
    with TickerProviderStateMixin, KeyboardListenerMixin {
  late final AutoScrollController _autoScrollController;
  late final SelectionModeController _selectionModeController;
  late SelectionOptions _selectionOptions;
  late PostGridOptions _options;

  PostGridController<T> get controller => widget.controller;

  var hasMore = true;
  final loading = ValueNotifier(false);
  final refreshing = ValueNotifier(false);
  var items = <T>[];
  final _identities = PostSelectionIdentity();
  var _filterScope = <String, bool>{};
  late var pageMode = controller.pageMode;

  @override
  void initState() {
    super.initState();
    _autoScrollController = widget.scrollController ?? AutoScrollController();
    _selectionModeController = widget.selectionModeController;

    controller.addListener(_onControllerChange);
    controller.activeFilters.addListener(_onFilterChanged);
    items = controller.items.toList();
    _filterScope = Map.of(controller.activeFilters.value);
    _syncSelection(duringBuild: true);
    if (widget.refreshAtStart) {
      controller.refresh();
    }

    _selectionOptions = widget.selectionOptions;
    _options = widget.options;

    registerListener(_handleKeyEvent);
  }

  @override
  void didUpdateWidget(RawPostGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selectionScope != oldWidget.selectionScope) {
      if (_selectionModeController
          case final OrderedSelectionController<Object> selection) {
        selection.reconcileDuringBuild(
          _identities.resolve(controller.items.toList()),
          scope: widget.selectionScope,
        );
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _selectionModeController.disable();
        });
      }
    }
    if (widget.selectionOptions != oldWidget.selectionOptions) {
      setState(() {
        _selectionOptions = widget.selectionOptions;
      });
    }

    if (widget.options != oldWidget.options) {
      setState(() {
        _options = widget.options;
      });
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (isKeyPressed(LogicalKeyboardKey.f5, event: event)) {
      controller.refresh();
    }

    return false;
  }

  @override
  void dispose() {
    removeListener(_handleKeyEvent);

    if (widget.scrollController == null) {
      _autoScrollController.dispose();
    }

    widget.controller.removeListener(_onControllerChange);
    controller.activeFilters.removeListener(_onFilterChanged);

    super.dispose();
  }

  void _onControllerChange() {
    if (!mounted) return;

    // check if refreshing, don't set state if it is
    if (controller.refreshing) {
      refreshing.value = true;

      if (_selectionModeController is OrderedSelectionController) {
        _selectionModeController.cancelDrag();
      }

      return;
    }

    // check if loading, don't set state if it is
    if (controller.loading) {
      loading.value = true;
      return;
    }

    _syncFilterScope();
    _syncSelection();
    setState(() {
      items = controller.items.toList();
      hasMore = controller.hasMore;
      loading.value = controller.loading;
      refreshing.value = controller.refreshing;
      pageMode = controller.pageMode;
    });
  }

  void _onFilterChanged() {
    // Refresh temporarily clears/rebuilds this map; those are not user filter
    // changes. Compare its final value before reconciling the refreshed posts.
    if (!controller.refreshing) _syncFilterScope();
  }

  void _syncFilterScope() {
    final filters = controller.activeFilters.value;
    if (!mapEquals(_filterScope, filters)) _selectionModeController.disable();
    _filterScope = Map.of(filters);
  }

  void _syncSelection({bool duringBuild = false}) {
    if (_selectionModeController
        case final OrderedSelectionController<Object> selection) {
      final keys = _identities.resolve(controller.items.toList());
      if (duringBuild) {
        selection.reconcileDuringBuild(keys, scope: widget.selectionScope);
      } else {
        selection.setEntries(keys, scope: widget.selectionScope);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Kurumi.themeOf(context).colorScheme;

    return NavigationScrollBoundary(
      child: ListenableBuilder(
        listenable: _selectionModeController,
        builder: (_, child) => NavigationSelectionBridge(
          controller: _selectionModeController,
          selected: _selectionModeController.isActive,
          child: child!,
        ),
        child: ColoredBox(
          color: colorScheme.surface,
          child: ConditionalParentWidget(
            condition: widget.safeArea,
            conditionalBuilder: (child) => SafeArea(
              bottom: false,
              left: false,
              child: child,
            ),
            child: _SelectionMode(
              footer: widget.footer,
              selectionModeController: _selectionModeController,
              selectionOptions: _selectionOptions,
              autoScrollController: _autoScrollController,
              itemCount: items.length,
              bottomInset: widget.bottomInset,
              child: _Scaffold(
                body: ConditionalParentWidget(
                  condition: kPreferredLayout.isMobile,
                  conditionalBuilder: (child) => KurumiRefreshIndicator(
                    edgeOffset: 60,
                    displacement: 50,
                    notificationPredicate: widget.enablePullToRefresh
                        ? (_) => true
                        : (_) => false,
                    onRefresh: () async {
                      await controller.refresh(
                        maintainPage: true,
                      );
                    },
                    child: child,
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: refreshing,
                    builder: (_, refreshing, child) => _SwipeTo(
                      pageMode: pageMode,
                      controller: controller,
                      refreshing: refreshing,
                      onNextPage: widget.onNextPage,
                      onPreviousPage: widget.onPreviousPage,
                      options: _options,
                      child: child!,
                    ),
                    child: PostGridOptionsProvider(
                      options: _options,
                      child: _CustomScrollView(
                        controller: _autoScrollController,
                        slivers: [
                          ...?widget.sliverHeaders,
                          ConditionalValueListenableBuilder(
                            valueListenable: refreshing,
                            useFalseChildAsCache: true,
                            trueChild: const SliverSizedBox.shrink(),
                            falseChild: SliverPinnedHeader(
                              child: widget.gridHeader,
                            ),
                          ),
                          ConditionalValueListenableBuilder(
                            valueListenable: refreshing,
                            useFalseChildAsCache: true,
                            trueChild: const SliverSizedBox.shrink(),
                            falseChild: const SliverToBoxAdapter(
                              child: HighresPreviewOnMobileDataWarningBanner(),
                            ),
                          ),
                          ConditionalValueListenableBuilder(
                            valueListenable: refreshing,
                            useFalseChildAsCache: true,
                            trueChild: const SliverSizedBox.shrink(),
                            falseChild: const SliverToBoxAdapter(
                              child: TooMuchCachedImagesWarningBanner(
                                threshold: _kImageCacheThreshold,
                              ),
                            ),
                          ),
                          if (pageMode == PageMode.paginated)
                            ConditionalValueListenableBuilder(
                              valueListenable: refreshing,
                              useFalseChildAsCache: true,
                              falseChild: SliverToBoxAdapter(
                                child: widget.topPageIndicator,
                              ),
                              trueChild: const SliverSizedBox.shrink(),
                            ),
                          widget.body,
                          if (pageMode == PageMode.infinite)
                            _buildLoadMore(colorScheme),
                          if (pageMode == PageMode.paginated)
                            ConditionalValueListenableBuilder(
                              valueListenable: refreshing,
                              useFalseChildAsCache: true,
                              trueChild: const SliverSizedBox.shrink(),
                              falseChild: SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 40,
                                    bottom: 20,
                                  ),
                                  child: widget.bottomPageIndicator,
                                ),
                              ),
                            ),
                          _SliverBottomGridPadding(
                            selectionModeController: _selectionModeController,
                            pageMode: pageMode,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                floatingActionButton: widget.scrollToTopButton,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMore(ColorScheme colorScheme) {
    void showNoMoreDataMessage() {
      showToast(
        context.t.infinite_scroll.nore_more_data,
        position: ToastPosition.bottom,
        margin: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 60,
        ),
        textPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: colorScheme.surfaceContainerHigh,
        textStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return ValueListenableBuilder(
      valueListenable: refreshing,
      builder: (context, refresh, child) => ConditionalValueListenableBuilder(
        valueListenable: loading,
        falseChild: switch ((refreshing: refresh, hasMore: hasMore)) {
          (refreshing: false, hasMore: true) => SliverLayoutBuilder(
            builder: (context, constraints) {
              final canScroll =
                  constraints.precedingScrollExtent >
                  constraints.viewportMainAxisExtent;

              return switch (canScroll) {
                true => const SliverSizedBox.shrink(),
                false => SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(120, 40),
                        ),
                        onPressed: () => controller.fetchMore(
                          onNoMoreData: () {
                            showNoMoreDataMessage();
                          },
                        ),
                        child: Text(
                          context.t.infinite_scroll.load_more,
                        ),
                      ),
                    ),
                  ),
                ),
              };
            },
          ),
          _ => const SliverSizedBox.shrink(),
        },
        trueChild: SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: KurumiPulseIndicator(
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeTo extends StatelessWidget {
  const _SwipeTo({
    required this.pageMode,
    required this.controller,
    required this.refreshing,
    required this.onNextPage,
    required this.onPreviousPage,
    required this.options,
    required this.child,
  });

  final PageMode pageMode;
  final PostGridController controller;
  final bool refreshing;
  final VoidCallback onNextPage;
  final VoidCallback onPreviousPage;
  final PostGridOptions options;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Kurumi.themeOf(context).colorScheme;

    return SwipeTo(
      enabled: pageMode == PageMode.paginated && !refreshing,
      swipeRightEnabled: controller.hasPreviousPage(),
      swipeLeftEnabled: controller.hasNextPage(),
      hapticFeedbackEnabled:
          options.hapticFeedbackLevel?.isBalanceAndAbove ?? false,
      rightSwipeWidget: KurumiMaterialChip(
        visualDensity: VisualDensity.compact,
        side: BorderSide(
          color: colorScheme.hintColor,
        ),
        backgroundColor: colorScheme.surface,
        label: Row(
          children: [
            Icon(
              Symbols.arrow_back,
              color: colorScheme.onSurface,
              size: 16,
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder(
              valueListenable: controller.pageNotifier,
              builder: (_, page, _) => Text(
                context.t.infinite_scroll.page_label(page: page - 1),
              ),
            ),
          ],
        ),
      ),
      leftSwipeWidget: KurumiMaterialChip(
        visualDensity: VisualDensity.compact,
        side: BorderSide(
          color: colorScheme.hintColor,
        ),
        backgroundColor: colorScheme.surface,
        label: Row(
          children: [
            ValueListenableBuilder(
              valueListenable: controller.pageNotifier,
              builder: (_, page, _) => Text(
                context.t.infinite_scroll.page_label(page: page + 1),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Symbols.arrow_forward,
              color: colorScheme.onSurface,
              size: 16,
            ),
          ],
        ),
      ),
      onLeftSwipe: (_) => onNextPage(),
      onRightSwipe: (_) => onPreviousPage(),
      child: child,
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({
    required this.body,
    required this.floatingActionButton,
  });

  final Widget body;
  final Widget floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(
        children: [
          Positioned.fill(
            child: body,
          ),
          floatingActionButton,
        ],
      ),
    );
  }
}

class PostGridConstraints extends InheritedWidget {
  const PostGridConstraints({
    required this.crossAxisCount,
    required super.child,
    super.key,
  });

  static PostGridConstraints? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PostGridConstraints>();
  }

  final int? crossAxisCount;

  @override
  bool updateShouldNotify(covariant PostGridConstraints oldWidget) {
    return crossAxisCount != oldWidget.crossAxisCount;
  }
}

class PostGridOptionsProvider extends InheritedWidget {
  const PostGridOptionsProvider({
    required this.options,
    required super.child,
    super.key,
  });

  static PostGridOptions of(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<PostGridOptionsProvider>();
    assert(result != null, 'No PostGridOptionsProvider found in context');
    return result!.options;
  }

  final PostGridOptions options;

  @override
  bool updateShouldNotify(covariant PostGridOptionsProvider oldWidget) {
    return options != oldWidget.options;
  }
}

class _SelectionMode extends ConsumerWidget {
  const _SelectionMode({
    required this.selectionModeController,
    required this.selectionOptions,
    required this.child,
    required this.itemCount,
    required this.bottomInset,
    this.footer,
    this.autoScrollController,
  });
  final Widget? footer;
  final Widget child;
  final int itemCount;
  final double bottomInset;
  final SelectionModeController selectionModeController;
  final AutoScrollController? autoScrollController;
  final SelectionOptions? selectionOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final longPressOpensMenu = ref.watch(postGridLongPressOpensMenuProvider);
    return SelectionMode(
      controller: selectionModeController,
      options: selectionOptions,
      scrollController: autoScrollController,
      child: SelectionInput(
        controller: selectionModeController,
        itemCount: itemCount,
        child: ListenableBuilder(
          listenable: selectionModeController,
          builder: (context, _) => KurumiContextMenuPolicy(
            touchLongPress:
                longPressOpensMenu && !selectionModeController.isActive,
            child: _SelectionKeyboardInset(
              enabled: selectionModeController.isActive,
              child: LayoutBuilder(
                builder: (context, available) => Column(
                  children: [
                    Expanded(
                      child: OrderedSelectionCanvas(
                        controller: selectionModeController,
                        child: child,
                      ),
                    ),
                    if (selectionModeController.isActive) ...[
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: math.max(
                            0,
                            math.min(
                              available.maxHeight - bottomInset,
                              MediaQuery.sizeOf(context).height * .45,
                            ),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Material(
                            color: Kurumi.themeOf(context).colorScheme.surface,
                            child: SafeArea(
                              top: false,
                              bottom: bottomInset == 0,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PostSelectionControls(
                                    controller: selectionModeController,
                                    itemCount: itemCount,
                                  ),
                                  if (footer case final footer?) footer,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (bottomInset > 0)
                        SizedBox(
                          height: math.min(bottomInset, available.maxHeight),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Measure after layout: route transitions may have ancestors whose paint
/// transforms require their final size. Avoid querying them during layout.
class _SelectionKeyboardInset extends StatefulWidget {
  const _SelectionKeyboardInset({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;
  @override
  State<_SelectionKeyboardInset> createState() =>
      _SelectionKeyboardInsetState();
}

class _SelectionKeyboardInsetState extends State<_SelectionKeyboardInset> {
  final _bounds = GlobalKey();
  var _overlap = 0.0;
  var _pending = false;
  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardTop = MediaQuery.sizeOf(context).height - inset;
    if (!widget.enabled || inset == 0) {
      _overlap = 0;
    } else if (!_pending) {
      _pending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pending = false;
        if (!mounted || !widget.enabled) return;
        final box = _bounds.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize) return;
        final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
        final overlap = (bottom - keyboardTop).clamp(0.0, box.size.height);
        if ((overlap - _overlap).abs() > .1) setState(() => _overlap = overlap);
      });
    }
    return SizedBox(
      key: _bounds,
      child: Padding(
        padding: EdgeInsets.only(bottom: _overlap),
        child: widget.child,
      ),
    );
  }
}

class _CustomScrollView extends StatefulWidget {
  const _CustomScrollView({
    required this.slivers,
    required this.controller,
  });

  final List<Widget> slivers;
  final ScrollController controller;

  @override
  State<_CustomScrollView> createState() => _CustomScrollViewState();
}

class _CustomScrollViewState extends State<_CustomScrollView> {
  @override
  Widget build(BuildContext context) {
    final options = PostGridOptionsProvider.of(context);

    return ScrollConfiguration(
      // Material scroll make it easier to pull to refresh
      behavior: const MaterialScrollBehavior(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = calculateGridCount(
            constraints.maxWidth,
            options.gridSize ?? GridSize.normal,
          );

          return PostGridConstraints(
            crossAxisCount: crossAxisCount,
            child: AutoScroll(
              controller: widget.controller,
              anchorBuilder: (context) => const SingleDirectionAnchor(),
              child: AnchorHoverGroup(
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  controller: widget.controller,
                  scrollCacheExtent: switch (options.cacheExtent) {
                    final cacheExtent? => ScrollCacheExtent.pixels(
                      cacheExtent,
                    ),
                    null => null,
                  },
                  slivers: widget.slivers,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliverBottomGridPadding extends StatelessWidget {
  const _SliverBottomGridPadding({
    required this.selectionModeController,
    required this.pageMode,
  });

  final SelectionModeController selectionModeController;
  final PageMode pageMode;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return SliverSizedBox(
      height: pageMode == PageMode.infinite ? bottomPadding : 0,
    );
  }
}

// 1GB threshold
const _kImageCacheThreshold = 1000 * 1024 * 1024;

class PostGridOptions extends Equatable {
  const PostGridOptions({
    this.cacheExtent,
    this.hapticFeedbackLevel,
    this.gridSize,
  });

  final double? cacheExtent;
  final HapticFeedbackLevel? hapticFeedbackLevel;
  final GridSize? gridSize;

  @override
  List<Object?> get props => [
    cacheExtent,
    hapticFeedbackLevel,
    gridSize,
  ];
}
