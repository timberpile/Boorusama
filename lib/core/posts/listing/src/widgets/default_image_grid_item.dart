// Package imports:
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:selection_mode/selection_mode.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../details/routes.dart';
import '../../../post/types.dart';
import '../../../post/widgets.dart';
import 'post_grid_controller.dart';
import 'post_grid_item.dart';

class DefaultImageGridItem<T extends Post> extends StatelessWidget {
  const DefaultImageGridItem({
    required this.index,
    required this.autoScrollController,
    required this.controller,
    required this.useHero,
    required this.config,
    this.onTap,
    super.key,
    this.leadingIcons,
    this.imageUrl,
    this.imageCacheManager,
    this.imageConfig,
  });

  final int index;
  final AutoScrollController autoScrollController;
  final PostGridController<T> controller;
  final bool useHero;
  final VoidCallback? onTap;
  final List<Widget>? leadingIcons;
  final String? imageUrl;
  final ImageCacheManager? imageCacheManager;
  final BooruConfigAuth config;
  final BooruConfigAuth? imageConfig;

  @override
  Widget build(BuildContext context) {
    final selectionModeController = SelectionMode.of(context);

    return ListenableBuilder(
      listenable: selectionModeController,
      builder: (context, _) => ValueListenableBuilder(
        valueListenable: controller.itemsNotifier,
        builder: (_, posts, _) {
          final multiSelect = selectionModeController.isActive;
          final post = posts[index];
          return Consumer(
            builder: (_, ref, _) => PostGridItem(
              post: post,
              index: index,
              useHero: useHero,
              multiSelectEnabled: multiSelect,
              config: config,
              imageUrl: imageUrl,
              imageCacheManager: imageCacheManager,
              imageConfig: imageConfig,
              leadingIcons: leadingIcons,
              autoScrollOptions: AutoScrollOptions(
                controller: autoScrollController,
                index: index,
              ),
              onTap: (media) {
                final callback = onTap;
                if (callback != null) {
                  callback();
                  return;
                }
                goToPostDetailsPageFromController(
                  ref: ref,
                  controller: controller,
                  initialIndex: index,
                  scrollController: autoScrollController,
                  initialThumbnailUrl: media.url,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
