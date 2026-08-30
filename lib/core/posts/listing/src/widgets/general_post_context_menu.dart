// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

// Project imports:
import '../../../../../foundation/url_launcher.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/providers.dart';
import '../../../../downloads/downloader/providers.dart';
import '../../../../router.dart';
import '../../../../bookmarks/src/widgets/bookmark_group_actions.dart';
import '../../../../tags/show/routes.dart';
import '../../../favorites/providers.dart';
import '../../../favorites/widgets.dart';
import '../../../post/providers.dart';
import '../../../post/types.dart';
import 'post_grid_controller.dart';

class GeneralPostContextMenu extends ConsumerWidget {
  const GeneralPostContextMenu({
    super.key,
    required this.controller,
    required this.index,
    required this.child,
  });

  final PostGridController<Post> controller;
  final Widget child;

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booruConfig = ref.watchConfigAuth;
    final loginDetails = ref.watch(booruLoginDetailsProvider(booruConfig));
    final hasFavoriteActions =
        loginDetails.hasLogin() && ref.watch(canFavoriteProvider(booruConfig));
    final commentPageBuilder = ref
        .watch(booruBuilderProvider(booruConfig))
        ?.commentPageBuilder;
    final postLinkGenerator = ref.watch(postLinkGeneratorProvider(booruConfig));
    final selectionModeController = SelectionMode.maybeOf(context);
    final feedbackContext = context;

    final downloadNotifier = ref.watch(
      downloadNotifierProvider(
        ref.watch(
          downloadNotifierParamsProvider((
            booruConfig,
            ref.watchConfigDownload,
          )),
        ),
      ).notifier,
    );

    return ValueListenableBuilder(
      valueListenable: controller.itemsNotifier,
      builder: (context, posts, _) {
        final post = posts[index];
        return KurumiContextMenu(
          menuItemsBuilder: (context) => [
            KurumiContextMenuTile(
              title: context.t.download.download,
              onTap: () {
                downloadNotifier.download(post);
              },
            ),
            BookmarkContextMenuSection(
              post: post,
              config: booruConfig,
            ),
            const KurumiContextMenuDivider(),
            if (hasFavoriteActions) ...[
              FavoriteContextMenuTile(
                post: post,
                feedbackContext: feedbackContext,
              ),
              const KurumiContextMenuDivider(),
            ],
            if (commentPageBuilder != null && post.hasComment)
              KurumiContextMenuTile(
                title: context.t.post.action.view_comments,
                onTap: () {
                  goToCommentPage(context, ref, post);
                },
              ),
            if (!loginDetails.hasStrictSFW)
              KurumiContextMenuTile(
                title: context.t.post.action.view_in_browser,
                onTap: () {
                  launchExternalUrlString(postLinkGenerator.getLink(post));
                },
              ),
            KurumiContextMenuTile(
              title: context.t.post.action.view_tags,
              onTap: () {
                goToShowTaglistPage(
                  ref,
                  post,
                  auth: booruConfig,
                );
              },
            ),
            const KurumiContextMenuDivider(),
            if (selectionModeController case final controller?)
              KurumiContextMenuTile(
                title: context.t.generic.action.select,
                onTap: () {
                  controller.enable(
                    initialSelected: [index],
                  );
                },
              ),
          ],
          child: child,
        );
      },
    );
  }
}
