import '../../../../../../core/content/types.dart';
import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/posts/pools/group_post_scope.dart';
import '../../../content_group_source.dart';
import 'pool_gallery_checkpoint.dart';
import '../../../../../../core/posts/details/src/routes/route_utils.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:selection_mode/selection_mode.dart';

// Project imports:
import '../../../../../../core/configs/config/providers.dart';
import '../../../../../../core/posts/listing/widgets.dart';
import '../../../../../../core/posts/pools/widgets.dart';
import '../../../../../../core/settings/providers.dart';
import '../../../../../../core/widgets/widgets.dart';
import '../../../../posts/listing/widgets.dart';
import '../../../../posts/post/types.dart';
import '../../../pool/types.dart';
import '../providers/filter_provider.dart';

class DanbooruInfinitePostIdList extends ConsumerWidget {
  const DanbooruInfinitePostIdList({
    required this.pool,
    super.key,
    this.sliverHeaders,
    this.order,
    this.checkpointIdentity,
    this.scrollController,
    this.onSelectionChanged,
    this.orderControl,
    this.useHero = true,
  });

  final DanbooruPool pool;
  final PoolDetailsOrder? order;
  final Object? checkpointIdentity;
  final AutoScrollController? scrollController;
  final ValueChanged<bool>? onSelectionChanged;
  final bool useHero;
  final Widget? orderControl;
  final List<Widget>? sliverHeaders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perPage = ref.watch(
      imageListingSettingsProvider.select((value) => value.postsPerPage),
    );
    final config = ref.watchConfig;
    final selectedOrder = order ?? ref.watch(poolFilterProvider).order;
    final reference = const ContentReferenceCodec().parse(
      engine: config.auth.booruType,
      site: Uri.parse(config.url),
      kind: ContentKind.group,
      sourceKey: 'pool:${pool.id}',
    );

    return CustomContextMenuOverlay(
      child: GroupPostScope(
        key: ValueKey((pool.id, selectedOrder, perPage)),
        reference: reference,
        orderKey: selectedOrder.name,
        perPage: perPage,
        prepareSource: (source) {
          if (source is DanbooruGroupSource && pool.postIds != null) {
            source.seedPool(reference, pool);
          }
        },
        builder: (context, controller) {
          final grid = PostGrid(
            safeArea: false,
            header: PostGridConfigurationHeader<Post>(
              additionalControls: [
                if (orderControl case final control?) control,
              ],
            ),
            scrollController: scrollController,
            controller: controller,
            itemBuilder: (context, index, scrollController, useHero) =>
                DanbooruPostListingContextMenu(
                  index: index,
                  controller: controller,
                  child: DefaultDanbooruImageGridItem(
                    index: index,
                    autoScrollController: scrollController,
                    controller: controller,
                    useHero: this.useHero && useHero,
                    // Back must preserve the gallery viewport, rather than apply
                    // the ordinary originating-grid scroll-to-current behavior.
                    onTap: this.useHero
                        ? null
                        : () => goToPostDetailsPageFromController(
                            ref: ref,
                            initialIndex: index,
                            controller: controller,
                            initialThumbnailUrl: null,
                            config: config,
                            hero: false,
                          ),
                  ),
                ),
            sliverHeaders: [
              ...?sliverHeaders,
              SliverToBoxAdapter(
                child: _PoolSelectionListener(onChanged: onSelectionChanged),
              ),
            ],
          );
          final identity = checkpointIdentity;
          final scroll = scrollController;
          return identity == null || scroll == null
              ? grid
              : PoolGalleryCheckpoint(
                  identity: identity,
                  controller: controller,
                  scrollController: scroll,
                  perPage: perPage,
                  child: grid,
                );
        },
      ),
    );
  }
}

class _PoolSelectionListener extends StatefulWidget {
  const _PoolSelectionListener({this.onChanged});
  final ValueChanged<bool>? onChanged;
  @override
  State<_PoolSelectionListener> createState() => _PoolSelectionListenerState();
}

class _PoolSelectionListenerState extends State<_PoolSelectionListener> {
  SelectionModeController? _selection;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selection = SelectionMode.of(context);
    if (_selection == selection) return;
    _selection?.removeListener(_changed);
    _selection = selection..addListener(_changed);
  }

  void _changed() => widget.onChanged?.call(_selection!.isActive);
  @override
  void dispose() {
    _selection?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
