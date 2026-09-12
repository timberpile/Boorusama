// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/details_parts/types.dart';
import '../../../core/posts/details_parts/widgets.dart';
import '../../../core/widgets/adaptive_button_row.dart';
import '../../../core/widgets/booru_menu_button_row.dart';
import '../favorites/providers.dart';
import '../favorites/widgets.dart';
import 'types.dart';

class HydrusPostActionToolbar extends ConsumerWidget {
  const HydrusPostActionToolbar({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<HydrusPost>(context);
    final canFav = ref
        .watch(hydrusCanFavoriteProvider(ref.watchConfigAuth))
        .maybeWhen(
          data: (fav) => fav,
          orElse: () => false,
        );
    final controller = PostDetailsPageViewScope.of(context);
    final detailsController = PostDetails.of<HydrusPost>(context).controller;
    final config = ref.watchConfigAuth;

    return CommonPostButtonsBuilder(
      post: post,
      onStartSlideshow: controller.startSlideshow,
      onLoadOriginal: () => detailsController.loadOriginalImage(post.id),
      config: config,
      configViewer: ref.watchConfigViewer,
      builder: (context, buttons) {
        return SliverToBoxAdapter(
          child: BooruMenuButtonRow(
            maxVisibleButtons: 4,
            buttons: [
              if (canFav)
                ButtonData(
                  required: true,
                  widget: HydrusFavoritePostButton(post: post),
                  title: context.t.post.action.favorite,
                ),
              ButtonData(
                required: true,
                widget: BookmarkPostButton(
                  post: post,
                  config: config,
                ),
                title: context.t.post.action.bookmark,
              ),
              ButtonData(
                required: true,
                widget: DownloadPostButton(post: post),
                title: context.t.download.download,
              ),
              ...buttons,
            ],
          ),
        );
      },
    );
  }
}

final kHydrusPostDetailsUIBuilder = PostDetailsUIBuilder(
  preview: {
    DetailsPart.toolbar: (context) => const HydrusPostActionToolbar(),
  },
  full: {
    DetailsPart.toolbar: (context) => const HydrusPostActionToolbar(),
    DetailsPart.tags: (context) => const DefaultInheritedTagsTile<HydrusPost>(),
    DetailsPart.fileDetails: (context) =>
        const DefaultInheritedFileDetailsSection<HydrusPost>(
          initialExpanded: true,
        ),
  },
);
