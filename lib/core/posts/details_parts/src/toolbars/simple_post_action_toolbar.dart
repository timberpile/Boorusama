// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/providers.dart';
import '../../../../router.dart';
import '../../../../widgets/adaptive_button_row.dart';
import '../../../../widgets/booru_menu_button_row.dart';
import '../../../details/types.dart';
import '../../../favorites/providers.dart';
import '../../../favorites/types.dart';
import '../../../favorites/widgets.dart';
import '../../../post/types.dart';
import '../../../shares/widgets.dart';
import '../common_post_buttons.dart';
import 'bookmark_post_button.dart';
import 'comment_post_button.dart';
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
  final FavoritePostButton? favoriteButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booruBuilder = ref.watch(booruBuilderProvider(ref.watchConfigAuth));
    final commentPageBuilder = booruBuilder?.commentPageBuilder;
    final detailsController = PostDetails.of(context).controller;
    final auth = ref.watchConfigAuth;
    final viewer = ref.watchConfigViewer;
    final download = ref.watchConfigDownload;

    final share = SharePostButton(
      post: post,
      auth: auth,
      configViewer: viewer,
      download: download,
    );
    final downloadAction = DownloadPostButton.action(context, ref, post);
    final favoriteAction = favoriteButton?.action(context);

    return CommonPostButtonsBuilder(
      post: post,
      onStartSlideshow: onStartSlideshow,
      onLoadOriginal: () => detailsController.loadOriginalImage(post),
      config: auth,
      configViewer: viewer,
      builder: (context, buttons) {
        return BooruMenuButtonRow(
          crossAxisAlignment: CrossAxisAlignment.start,
          invokeAfterClose: true,
          maxVisibleButtons: maxVisibleButtons,
          buttons: [
            if (favoriteButton case final btn?)
              ButtonData(
                required:
                    PostActionToolbarScope.maybeOf(context)
                        ?.groupBookmarkButton ==
                    null,
                widget: btn,
                onTap: favoriteAction,
                enabled: favoriteAction != null,
                title: (btn.isFaved ?? false)
                    ? context.t.post.action.unfavorite
                    : context.t.post.action.favorite,
                icon: Icon(
                  (btn.isFaved ?? false)
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
              ),
            ButtonData(
              required: true,
              widget:
                  PostActionToolbarScope.maybeOf(context)?.bookmarkButton ??
                  BookmarkPostButton(post: post, config: auth),
              title: context.t.post.action.bookmark,
              icon: const Icon(Icons.bookmark_border),
            ),
            if (PostActionToolbarScope.maybeOf(context)?.groupBookmarkButton
                case final groupBookmark?)
              ButtonData(
                required: true,
                widget: groupBookmark,
                title: context.t.content_viewer.bookmark_group,
                icon: const Icon(Icons.bookmark_border),
              ),
            if (downloadAction != null)
              ButtonData(
                required:
                    PostActionToolbarScope.maybeOf(context)
                        ?.groupBookmarkButton ==
                    null,
                widget: DownloadPostButton(
                  post: post,
                  download: downloadAction,
                ),
                onTap: downloadAction,
                title: context.t.download.download,
                icon: const Icon(Icons.download),
              ),
            ButtonData(
              required:
                  PostActionToolbarScope.maybeOf(context)
                      ?.groupBookmarkButton ==
                  null,
              widget: share,
              onTap: share.action(context, ref),
              title: context.t.post.action.share,
              icon: const Icon(Icons.share),
            ),
            if (commentPageBuilder != null)
              ButtonData(
                widget: CommentPostButton(
                  onPressed: () => goToCommentPage(context, ref, post),
                ),
                title: context.t.comment.comments,
                icon: const Icon(Icons.comment_outlined),
                onTap: () => goToCommentPage(context, ref, post),
              ),
            ...?PostActionToolbarScope.maybeOf(context)?.additionalButtons,
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
    final needsWebsiteLogin = ref.watch(
      favoriteNeedsWebsiteLoginProvider(config),
    );
    final isAuthorized = loginDetails.hasLogin();
    final profileId = ref.watchConfig.id;
    Future<void> setFavorite(bool favorited) async {
      final confirmed = await notifier.setFavorite(
        post.id,
        favorited: favorited,
        profileId: profileId,
      );
      if (!confirmed) throw FavoriteActionFailure.unconfirmed;
    }

    return SimplePostActionToolbar<T>(
      post: post,
      maxVisibleButtons: 5,
      onStartSlideshow: PostDetailsPageViewScope.of(context).startSlideshow,
      favoriteButton:
          (!forceHideFav &&
              ((isAuthorized && canFavorite) || needsWebsiteLogin))
          ? FavoritePostButton(
              key: ValueKey((config.computeHash(), profileId, post.id)),
              isFaved: isFaved,
              isAuthorized: true,
              isCurrent: () =>
                  context.mounted &&
                  ref.readConfigAuth == config &&
                  ref.readConfig.id == profileId,
              addFavorite: () => setFavorite(true),
              removeFavorite: () => setFavorite(false),
            )
          : null,
    );
  }
}

/// Extends the standard action row without replacing its presentation or actions.
class PostActionToolbarScope extends InheritedWidget {
  const PostActionToolbarScope({
    required this.additionalButtons,
    required super.child,
    this.bookmarkButton,
    this.groupBookmarkButton,
    super.key,
  });
  final List<ButtonData> additionalButtons;
  final Widget? bookmarkButton;
  final Widget? groupBookmarkButton;
  static PostActionToolbarScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PostActionToolbarScope>();
  @override
  bool updateShouldNotify(PostActionToolbarScope oldWidget) =>
      additionalButtons != oldWidget.additionalButtons ||
      bookmarkButton != oldWidget.bookmarkButton ||
      groupBookmarkButton != oldWidget.groupBookmarkButton;
}
