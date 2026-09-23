// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:selection_mode/selection_mode.dart';

// Project imports:
import '../../../../../core/configs/config/providers.dart';
import '../../../../../core/posts/details/routes.dart';
import '../../../../../core/posts/listing/src/widgets/post_grid_controller.dart';
import '../../../../../core/posts/listing/widgets.dart';
import '../../../../../core/posts/post/widgets.dart';
import '../../post/types.dart';
import 'danbooru_post_grid_presentation.dart';

class DefaultDanbooruImageGridItem extends StatelessWidget {
  const DefaultDanbooruImageGridItem({
    required this.index,
    required this.autoScrollController,
    required this.controller,
    super.key,
    this.blockOverlay,
    this.onTap,
    this.useHero = true,
    this.quickActionButton,
  });

  final int index;
  final AutoScrollController autoScrollController;
  final PostGridController<Post> controller;
  final BlockOverlayItem? blockOverlay;
  final VoidCallback? onTap;
  final bool useHero;
  final Widget? quickActionButton;

  @override
  Widget build(BuildContext context) {
    final selectionModeController = SelectionMode.of(context);

    return ListenableBuilder(
      listenable: selectionModeController,
      builder: (_, _) => ValueListenableBuilder(
        valueListenable: controller.itemsNotifier,
        builder: (_, posts, _) {
          final post = posts[index];
          final multiSelect = selectionModeController.isActive;

          return Consumer(
            builder: (_, ref, _) {
              final config = ref.watchConfigAuth;
              final additions = const DanbooruPostGridPresentation()
                  .buildLegacyGridItemAdditions(
                    context,
                    post: post,
                    config: config,
                  );

              return PostGridItem(
                post: post,
                index: index,
                useHero: useHero,
                multiSelectEnabled: multiSelect,
                config: config,
                quickActionButton: quickActionButton,
                blockOverlay: blockOverlay,
                additions: additions,
                disablePostInteraction: onTap == null ? null : false,
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
              );
            },
          );
        },
      ),
    );
  }
}
