import 'package:i18n/i18n.dart';
// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../settings/providers.dart';
import '../../../listing/types.dart';
import '../../pool_grid_item.dart';

class PoolDiscoveryPage<T> {
  const PoolDiscoveryPage(this.items, this.nextRawPage);
  final List<T> items;
  final int? nextRawPage;
}

class PoolPagedSliverGridView<T> extends ConsumerStatefulWidget {
  const PoolPagedSliverGridView({
    required this.constraints,
    required this.fetchPage,
    required this.imageBuilder,
    required this.onTap,
    required this.total,
    required this.name,
    super.key,
    this.refreshKey,
    this.kind,
    this.fetchRawPage,
  });

  final Future<PoolDiscoveryPage<T>> Function(WidgetRef ref, int page)?
  fetchRawPage;
  final BoxConstraints constraints;
  final Object? refreshKey;
  final Future<List<T>> Function(WidgetRef ref, int page) fetchPage;
  final Widget Function(BuildContext context, T pool) imageBuilder;
  final void Function(WidgetRef ref, T pool) onTap;
  final int? Function(T pool) total;
  final String? Function(T pool) name;
  final PoolGridItemKind Function(T pool)? kind;

  @override
  ConsumerState<PoolPagedSliverGridView<T>> createState() =>
      _PoolPagedSliverGridViewState<T>();
}

class _PoolPagedSliverGridViewState<T>
    extends ConsumerState<PoolPagedSliverGridView<T>> {
  final _next = <int, int?>{};
  var _generation = 0;
  late final controller = PagingController<int, T>(
    getNextPageKey: (state) => widget.fetchRawPage == null
        ? (state.lastPageIsEmpty ? null : state.nextIntPageKey)
        : (state.keys?.isNotEmpty ?? false ? _next[state.keys!.last] : 1),
    fetchPage: (pageKey) async {
      final fetch = widget.fetchRawPage;
      if (fetch == null) return widget.fetchPage(ref, pageKey);
      final generation = _generation;
      final page = await fetch(ref, pageKey);
      if (mounted && generation == _generation) {
        _next[pageKey] = page.nextRawPage;
      }
      return page.items;
    },
  );

  @override
  void didUpdateWidget(covariant PoolPagedSliverGridView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshKey != widget.refreshKey) {
      _generation++;
      _next.clear();
      controller.refresh();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageGridSpacing = ref.watch(
      imageListingSettingsProvider.select((value) => value.imageGridSpacing),
    );
    final imageGridPadding = ref.watch(
      imageListingSettingsProvider.select((value) => value.imageGridPadding),
    );
    final gridSize = ref.watch(
      imageListingSettingsProvider.select((value) => value.gridSize),
    );
    final imageGridAspectRatio =
        ref.watch(
          imageListingSettingsProvider.select(
            (value) => value.imageGridAspectRatio,
          ),
        ) -
        0.2;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        imageGridPadding,
        0,
        imageGridPadding,
        MediaQuery.paddingOf(context).bottom,
      ),
      sliver: PagingListener(
        controller: controller,
        builder: (context, state, fetchNextPage) => PagedSliverGrid(
          state: state,
          fetchNextPage: fetchNextPage,
          builderDelegate: PagedChildBuilderDelegate<T>(
            itemBuilder: (context, pool, index) => PoolGridItem(
              image: widget.imageBuilder(context, pool),
              onTap: () => widget.onTap(ref, pool),
              total: widget.total(pool),
              name: widget.name(pool),
              kind: widget.kind?.call(pool) ?? PoolGridItemKind.collection,
            ),
            noItemsFoundIndicatorBuilder: widget.fetchRawPage == null
                ? null
                : (context) => Center(
                    child: state.hasNextPage
                        ? TextButton(
                            onPressed: fetchNextPage,
                            child: Text(context.t.infinite_scroll.load_more),
                          )
                        : const SizedBox.shrink(),
                  ),
            firstPageProgressIndicatorBuilder: (context) => const Center(
              child: CircularProgressIndicator.adaptive(),
            ),
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: calculateGridCount(
              widget.constraints.maxWidth,
              gridSize,
            ),
            childAspectRatio: imageGridAspectRatio,
            mainAxisSpacing: imageGridSpacing,
            crossAxisSpacing: imageGridSpacing,
          ),
        ),
      ),
    );
  }
}
