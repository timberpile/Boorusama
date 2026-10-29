// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/configs/config/providers.dart';
import '../../../../../../core/posts/details/types.dart';
import '../../../../../../core/posts/details_parts/widgets.dart';
import '../../../../../../core/posts/favorites/providers.dart';
import '../../../../../../core/posts/favorites/widgets.dart';
import '../../../../../../core/posts/shares/widgets.dart';
import '../../../../../../core/posts/post/types.dart';
import '../../../../../../core/posts/votes/types.dart';
import '../../../../../../core/posts/votes/widgets.dart';
import '../../../../../../core/router.dart';
import '../../../../../../core/posts/details_parts/src/toolbars/customizable_post_toolbar.dart';
import '../../../../configs/providers.dart';
import '../../../../favgroups/favgroups/routes.dart';
import '../../../../versions/routes.dart';
import '../../../votes/providers.dart';

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
    final voteId = postVote?.voteId;

    return SliverToBoxAdapter(
      child: CommonPostButtonsBuilder(
        post: post,
        onStartSlideshow: onStartSlideshow,
        onLoadOriginal: () => detailsController.loadOriginalImage(post),
        config: config,
        configViewer: configViewer,
        builder: (context, buttons) {
          return CustomizablePostToolbar(
            key: ValueKey((post, config)),
            maxVisibleButtons: hasLogin ? 7 : 4,
            buttons: [
              if (hasLogin)
                ViewerToolbarButtonData(
                  action: ViewerToolbarAction.favorite,
                  required: true,
                  widget: FavoritePostButton(
                    isFaved: isFaved,
                    isAuthorized: loginDetails.hasLogin(),
                    addFavorite: () =>
                        notifier.add(post.id, profileId: ref.readConfig.id),
                    removeFavorite: () =>
                        notifier.remove(post.id, profileId: ref.readConfig.id),
                  ),
                  menuBuilder: (_, _) => FavoritePostButton(
                    isFaved: isFaved,
                    isAuthorized: hasLogin,
                    addFavorite: () =>
                        notifier.add(post.id, profileId: profile.id),
                    removeFavorite: () =>
                        notifier.remove(post.id, profileId: profile.id),
                    menuItem: true,
                  ),
                  title: context.t.post.action.favorite,
                  icon: const Icon(Icons.favorite_border),
                ),
              if (hasLogin)
                ViewerToolbarButtonData(
                  action: ViewerToolbarAction.upvote,
                  required: true,
                  widget: UpvotePostButton(
                    voteState: voteState,
                    onUpvote: () => ref.danbooruUpvote(post.id),
                    onRemoveUpvote: voteId != null
                        ? () => ref.danbooruRemoveVote(post.id, voteId)
                        : null,
                  ),
                  menuBuilder: (_, _) => UpvotePostButton(
                    voteState: voteState,
                    onUpvote: () => ref.danbooruUpvote(post.id),
                    onRemoveUpvote: voteId != null
                        ? () => ref.danbooruRemoveVote(post.id, voteId)
                        : null,
                    menuItem: true,
                  ),
                  enabled: !voteState.isUpvoted || voteId != null,
                  onTap: voteState.isUpvoted
                      ? (voteId == null
                            ? null
                            : () => ref.danbooruRemoveVote(post.id, voteId))
                      : () => ref.danbooruUpvote(post.id),
                  title: context.t.post.action.upvote,
                  icon: const Icon(Icons.thumb_up_outlined),
                ),
              if (hasLogin)
                ViewerToolbarButtonData(
                  action: ViewerToolbarAction.downvote,
                  required: true,
                  widget: DownvotePostButton(
                    voteState: voteState,
                    onDownvote: () => ref.danbooruDownvote(post.id),
                    onRemoveDownvote: voteId != null
                        ? () => ref.danbooruRemoveVote(post.id, voteId)
                        : null,
                  ),
                  menuBuilder: (_, _) => DownvotePostButton(
                    voteState: voteState,
                    onDownvote: () => ref.danbooruDownvote(post.id),
                    onRemoveDownvote: voteId != null
                        ? () => ref.danbooruRemoveVote(post.id, voteId)
                        : null,
                    menuItem: true,
                  ),
                  enabled: !voteState.isDownvoted || voteId != null,
                  onTap: voteState.isDownvoted
                      ? (voteId == null
                            ? null
                            : () => ref.danbooruRemoveVote(post.id, voteId))
                      : () => ref.danbooruDownvote(post.id),
                  title: context.t.post.action.downvote,
                  icon: const Icon(Icons.thumb_down_outlined),
                ),
              ViewerToolbarButtonData(
                action: ViewerToolbarAction.bookmark,
                required: true,
                widget: BookmarkPostButton(
                  post: post,
                  config: config,
                ),
                menuBuilder: (_, _) => BookmarkPostButton(
                  post: post,
                  config: config,
                  menuItem: true,
                ),
                title: context.t.post.action.bookmark,
                icon: const Icon(Icons.bookmark_border),
              ),
              ViewerToolbarButtonData(
                action: ViewerToolbarAction.download,
                widget: DownloadPostButton(post: post),
                menuBuilder: (_, close) => DownloadPostButton(
                  post: post,
                  menuItem: true,
                  onMenuAction: close,
                ),
                title: context.t.download.download,
                icon: const Icon(Icons.download),
              ),
              ViewerToolbarButtonData(
                action: ViewerToolbarAction.share,
                widget: SharePostButton(
                  post: post,
                  auth: config,
                  configViewer: configViewer,
                  download: download,
                ),
                menuBuilder: (_, _) => SharePostButton(
                  post: post,
                  auth: config,
                  configViewer: configViewer,
                  download: download,
                  menuItem: true,
                ),
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
              ...buttons,
            ],
          );
        },
      ),
    );
  }
}
