// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/providers.dart';
import '../../../../router.dart';
import '../../../details/types.dart';
import '../../../favorites/providers.dart';
import '../../../favorites/widgets.dart';
import '../../../post/types.dart';
import '../../../shares/widgets.dart';
import '../common_post_buttons.dart';
import 'bookmark_post_button.dart';
import 'comment_post_button.dart';
import 'customizable_post_toolbar.dart';
import 'download_post_button.dart';

class SimplePostActionToolbar<T extends Post> extends ConsumerWidget {
  const SimplePostActionToolbar({
    required this.post,
    required this.onStartSlideshow,
    required this.favoriteButton,
    super.key,
    this.onDownload,
    this.maxVisibleButtons,
  });

  final T post;
  final int? maxVisibleButtons;
  final void Function(Post post)? onDownload;
  final void Function() onStartSlideshow;
  final Widget? favoriteButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booruBuilder = ref.watch(booruBuilderProvider(ref.watchConfigAuth));
    final commentPageBuilder = booruBuilder?.commentPageBuilder;
    final detailsController = PostDetails.of(context).controller;
    final auth = ref.watchConfigAuth;
    final viewer = ref.watchConfigViewer;
    final download = ref.watchConfigDownload;

    return CommonPostButtonsBuilder(
      post: post,
      onStartSlideshow: onStartSlideshow,
      onLoadOriginal: () => detailsController.loadOriginalImage(post),
      config: auth,
      configViewer: viewer,
      builder: (context, buttons) {
        return CustomizablePostToolbar(
          key: ValueKey((post, auth)),
          maxVisibleButtons: maxVisibleButtons,
          buttons: [
            if (favoriteButton case final btn?)
              ViewerToolbarButtonData(
                action: ViewerToolbarAction.favorite,
                required: true,
                widget: btn,
                menuBuilder: (_, _) => switch (btn) {
                  FavoritePostButton() => btn.asMenuItem(),
                  _ => btn,
                },
                title: context.t.post.action.favorite,
                icon: const Icon(Icons.favorite_border),
              ),
            ViewerToolbarButtonData(
              action: ViewerToolbarAction.bookmark,
              required: true,
              widget: BookmarkPostButton(post: post, config: auth),
              menuBuilder: (_, _) => BookmarkPostButton(
                post: post, config: auth, menuItem: true,
              ),
              title: context.t.post.action.bookmark,
              icon: const Icon(Icons.bookmark_border),
            ),
            ViewerToolbarButtonData(
              action: ViewerToolbarAction.download,
              required: true,
              widget: DownloadPostButton(post: post),
              menuBuilder: (_, close) => DownloadPostButton(
                post: post, menuItem: true, onMenuAction: close,
              ),
              title: context.t.download.download,
              icon: const Icon(Icons.download),
            ),
            ViewerToolbarButtonData(
              action: ViewerToolbarAction.share,
              required: true,
              widget: SharePostButton(
                post: post,
                auth: auth,
                configViewer: viewer,
                download: download,
              ),
              menuBuilder: (_, _) => SharePostButton(
                post: post,
                auth: auth,
                configViewer: viewer,
                download: download,
                menuItem: true,
              ),
              title: context.t.post.action.share,
              icon: const Icon(Icons.share),
            ),
            if (commentPageBuilder != null)
              ViewerToolbarButtonData(
                action: ViewerToolbarAction.comments,
                widget: CommentPostButton(
                  onPressed: () => goToCommentPage(context, ref, post),
                ),
                title: context.t.comment.comments,
                icon: const Icon(Icons.comment_outlined),
                onTap: () => goToCommentPage(context, ref, post),
              ),
            ...buttons,
          ],
        );
      },
    );
  }
}

class DefaultInheritedPostActionToolbar<T extends Post>
    extends StatelessWidget {
  const DefaultInheritedPostActionToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final post = InheritedPost.maybeOf(context);

    return SliverToBoxAdapter(
      child: post != null
          ? DefaultPostActionToolbar<Post>(post: post)
          : const SizedBox.shrink(),
    );
  }
}

class DefaultPostActionToolbar<T extends Post> extends ConsumerWidget {
  const DefaultPostActionToolbar({
    required this.post,
    super.key,
    this.forceHideFav = false,
  });

  final T post;
  final bool forceHideFav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final loginDetails = ref.watch(booruLoginDetailsProvider(config));
    final isFaved = ref.watch(favoriteProvider((config, post.id)));
    final notifier = ref.watch(favoritesProvider(config).notifier);
    final canFavorite = ref.watch(canFavoriteProvider(config));
    final isAuthorized = loginDetails.hasLogin();
    final addFavorite = canFavorite
        ? () => notifier.add(post.id, profileId: ref.readConfig.id)
        : null;
    final removeFavorite = canFavorite
        ? () => notifier.remove(post.id, profileId: ref.readConfig.id)
        : null;

    return SimplePostActionToolbar<T>(
      post: post,
      maxVisibleButtons: 5,
      onStartSlideshow: PostDetailsPageViewScope.of(context).startSlideshow,
      favoriteButton:
          (!forceHideFav &&
              isAuthorized &&
              addFavorite != null &&
              removeFavorite != null)
          ? FavoritePostButton(
              isFaved: isFaved,
              isAuthorized: isAuthorized,
              addFavorite: addFavorite,
              removeFavorite: removeFavorite,
            )
          : null,
    );
  }
}
