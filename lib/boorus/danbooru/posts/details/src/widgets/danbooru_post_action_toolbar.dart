// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/configs/config/providers.dart';
import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/posts/details/types.dart';
import '../../../../../../core/posts/details_parts/src/toolbars/customizable_post_toolbar.dart';
import '../../../../../../core/posts/details_parts/src/toolbars/viewer_toolbar_profile_actions.dart';
import '../../../../../../core/posts/details_parts/widgets.dart';
import '../../../../../../core/posts/favorites/providers.dart';
import '../../../../../../core/posts/favorites/widgets.dart';
import '../../../../../../core/posts/shares/widgets.dart';
import '../../../../../../core/posts/post/types.dart';
import '../../../../../../core/posts/votes/types.dart';
import '../../../../../../core/posts/votes/widgets.dart';
import '../../../../../../core/router.dart';
import '../../../../../../core/widgets/adaptive_button_row.dart';
import '../../../../configs/providers.dart';
import '../../../../favgroups/favgroups/routes.dart';
import '../../../../versions/routes.dart';
import '../../../votes/providers.dart';

ViewerToolbarProfileActions danbooruViewerToolbarActions(
  Ref ref,
  BooruConfigAuth auth,
) {
  final hasLogin = ref.watch(danbooruLoginDetailsProvider(auth)).hasLogin();
  return (
    visibleCount: hasLogin ? 7 : 4,
    actions: [
      if (hasLogin) ...const [
        ViewerToolbarAction.favorite,
        ViewerToolbarAction.upvote,
        ViewerToolbarAction.downvote,
      ],
      ViewerToolbarAction.bookmark,
      if (auth.anonymousReadScope == null) ViewerToolbarAction.download,
      ViewerToolbarAction.share,
      ViewerToolbarAction.comments,
      if (hasLogin) ViewerToolbarAction.favoriteGroup,
      ViewerToolbarAction.tagHistory,
    ],
  );
}

class DanbooruInheritedPostActionToolbar extends ConsumerWidget {
  const DanbooruInheritedPostActionToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.maybeOf<Post>(context);
    final controller = PostDetailsPageViewScope.of(context);

    return post != null
        ? DanbooruPostActionToolbar(
            post: post,
            onStartSlideshow: controller.startSlideshow,
          )
        : const SizedBox.shrink();
  }
}

class DanbooruPostActionToolbar extends ConsumerWidget {
  const DanbooruPostActionToolbar({
    required this.post,
    required this.onStartSlideshow,
    super.key,
  });

  final Post post;
  final void Function() onStartSlideshow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watchConfig;
    final config = ref.watchConfigAuth;
    final configViewer = ref.watchConfigViewer;
    final download = ref.watchConfigDownload;
    final params = (config, post.id);
    final isFaved = ref.watch(favoriteProvider(params));
    final postVote = ref.watch(danbooruPostVoteProvider(params));
    final voteState = postVote?.voteState ?? VoteState.unvote;
    final notifier = ref.watch(favoritesProvider(config).notifier);
    final loginDetails = ref.watch(danbooruLoginDetailsProvider(config));
    final detailsController = PostDetails.of<Post>(context).controller;
    final hasLogin = loginDetails.hasLogin();
    final scoped = PostActionToolbarScope.maybeOf(context);
    final voteId = postVote?.voteId;
    final favorite = FavoritePostButton(
      isFaved: isFaved,
      isAuthorized: hasLogin,
      addFavorite: () => notifier.add(post.id, profileId: profile.id),
      removeFavorite: () => notifier.remove(post.id, profileId: profile.id),
    );
    final favoriteAction = favorite.action(context);
    final upvote = UpvotePostButton(
      voteState: voteState,
      onUpvote: () => ref.danbooruUpvote(post.id),
      onRemoveUpvote: voteId != null
          ? () => ref.danbooruRemoveVote(post.id, voteId)
          : null,
    );
    final downvote = DownvotePostButton(
      voteState: voteState,
      onDownvote: () => ref.danbooruDownvote(post.id),
      onRemoveDownvote: voteId != null
          ? () => ref.danbooruRemoveVote(post.id, voteId)
          : null,
    );
    final share = SharePostButton(
      post: post,
      auth: config,
      configViewer: configViewer,
      download: download,
    );
    final downloadAction = DownloadPostButton.action(context, ref, post);

    return SliverToBoxAdapter(
      child: CommonPostButtonsBuilder(
        post: post,
        onStartSlideshow: onStartSlideshow,
        onLoadOriginal: () => detailsController.loadOriginalImage(post),
        config: config,
        configViewer: configViewer,
        builder: (context, buttons) {
          return CustomizablePostToolbar(
            key: ValueKey((post, config, profile.id)),
            allowCustomization: scoped == null,
            maxVisibleButtons: hasLogin ? 7 : 4,
            buttons: [
              if (hasLogin)
                ViewerToolbarButtonData(
                  action: ViewerToolbarAction.favorite,
                  required: scoped?.groupBookmarkButton == null,
                  widget: favorite,
                  onTap: favoriteAction,
                  enabled: favoriteAction != null,
                  title: isFaved
                      ? context.t.post.action.unfavorite
                      : context.t.post.action.favorite,
                  icon: Icon(
                    isFaved ? Icons.favorite : Icons.favorite_border,
                  ),
                ),
              if (hasLogin)
                ViewerToolbarButtonData(
                  action: ViewerToolbarAction.upvote,
                  required: scoped?.groupBookmarkButton == null,
                  widget: upvote,
                  menuBuilder: (_, _) => UpvotePostButton(
                    voteState: voteState,
                    onUpvote: upvote.onUpvote,
                    onRemoveUpvote: upvote.onRemoveUpvote,
                    menuItem: true,
                  ),
                  onTap: upvote.action,
                  enabled: upvote.action != null,
                  title: context.t.post.action.upvote,
                  icon: const Icon(Icons.thumb_up_outlined),
                ),
              if (hasLogin)
                ViewerToolbarButtonData(
                  action: ViewerToolbarAction.downvote,
                  required: scoped?.groupBookmarkButton == null,
                  widget: downvote,
                  menuBuilder: (_, _) => DownvotePostButton(
                    voteState: voteState,
                    onDownvote: downvote.onDownvote,
                    onRemoveDownvote: downvote.onRemoveDownvote,
                    menuItem: true,
                  ),
                  onTap: downvote.action,
                  enabled: downvote.action != null,
                  title: context.t.post.action.downvote,
                  icon: const Icon(Icons.thumb_down_outlined),
                ),
              ViewerToolbarButtonData(
                action: ViewerToolbarAction.bookmark,
                required: true,
                menuBuilder: (_, _) => BookmarkPostButton(
                  post: post,
                  config: config,
                  menuItem: true,
                ),
                widget:
                    scoped?.bookmarkButton ??
                    BookmarkPostButton(
                      post: post,
                      config: config,
                    ),
                title: context.t.post.action.bookmark,
                icon: const Icon(Icons.bookmark_border),
              ),
              if (scoped?.groupBookmarkButton case final groupBookmark?)
                ButtonData(
                  required: true,
                  widget: groupBookmark,
                  title: context.t.content_viewer.bookmark_group,
                  icon: const Icon(Icons.bookmark_border),
                ),
              if (downloadAction != null)
                ViewerToolbarButtonData(
                  action: ViewerToolbarAction.download,
                  menuBuilder: (_, close) => DownloadPostButton(
                    post: post,
                    download: downloadAction,
                    menuItem: true,
                    onMenuAction: close,
                  ),
                  widget: DownloadPostButton(
                    post: post,
                    download: downloadAction,
                  ),
                  onTap: downloadAction,
                  title: context.t.download.download,
                  icon: const Icon(Icons.download),
                ),
              ViewerToolbarButtonData(
                action: ViewerToolbarAction.share,
                widget: share,
                onTap: share.action(context, ref),
                title: context.t.post.action.share,
                icon: const Icon(Icons.share),
              ),
              ViewerToolbarButtonData(
                action: ViewerToolbarAction.comments,
                widget: CommentPostButton(
                  onPressed: () => goToCommentPage(context, ref, post),
                ),
                title: context.t.comment.comments,
                icon: const Icon(Icons.comment_outlined),
                onTap: () => goToCommentPage(context, ref, post),
              ),
              if (hasLogin)
                ViewerToolbarSimpleButtonData(
                  action: ViewerToolbarAction.favoriteGroup,
                  icon: Icons.folder_special,
                  title: context.t.post.action.add_to_favorite_group,
                  onPressed: () => goToAddToFavoriteGroupSelectionPage(
                    context,
                    [post],
                    profile,
                  ),
                ),
              ViewerToolbarSimpleButtonData(
                action: ViewerToolbarAction.tagHistory,
                icon: Icons.history,
                title: context.t.post.action.view_tag_history,
                onPressed: () => goToPostVersionPage(ref, post),
              ),
              ...?scoped?.additionalButtons,
              ...buttons,
            ],
          );
        },
      ),
    );
  }
}
