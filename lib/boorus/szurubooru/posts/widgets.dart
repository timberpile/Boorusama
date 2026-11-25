// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/details_parts/types.dart';
import '../../../core/posts/details_parts/widgets.dart';
import '../../../core/posts/details_parts/src/toolbars/customizable_post_toolbar.dart';
import '../../../core/posts/details_parts/src/toolbars/viewer_toolbar_profile_actions.dart';
import '../../../core/posts/favorites/providers.dart';
import '../../../core/posts/favorites/widgets.dart';
import '../../../core/posts/shares/widgets.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/router.dart';
import '../../../core/search/search/routes.dart';
import '../configs/providers.dart';
import '../pools/widgets.dart';
import '../post_votes/widgets.dart';
import 'post_data.dart';
import 'providers.dart';

ViewerToolbarProfileActions szurubooruViewerToolbarActions(
  Ref ref,
  BooruConfigAuth auth,
) => (
  visibleCount: 5,
  actions: [
    if (ref.watch(szurubooruLoginDetailsProvider(auth)).hasLogin()) ...const [
      ViewerToolbarAction.favorite,
      ViewerToolbarAction.upvote,
      ViewerToolbarAction.downvote,
    ],
    ViewerToolbarAction.bookmark,
    if (auth.anonymousReadScope == null) ViewerToolbarAction.download,
    ViewerToolbarAction.share,
    ViewerToolbarAction.comments,
  ],
);

class SzurubooruPostActionToolbar extends ConsumerWidget {
  const SzurubooruPostActionToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);
    final controller = PostDetailsPageViewScope.of(context);
    final detailsController = PostDetails.of<Post>(context).controller;
    final profileId = ref.watchConfig.id;
    final config = ref.watchConfigAuth;
    final configViewer = ref.watchConfigViewer;
    final download = ref.watchConfigDownload;
    final isFaved = ref.watch(favoriteProvider((config, post.id)));
    final favNotifier = ref.watch(favoritesProvider(config).notifier);
    final hasLogin = ref
        .watch(szurubooruLoginDetailsProvider(config))
        .hasLogin();
    final share = SharePostButton(
      post: post,
      auth: config,
      configViewer: configViewer,
      download: download,
    );
    final downloadAction = DownloadPostButton.action(context, ref, post);
    final favorite = FavoritePostButton(
      isFaved: isFaved,
      isAuthorized: hasLogin,
      addFavorite: () => favNotifier.add(post.id, profileId: profileId),
      removeFavorite: () => favNotifier.remove(post.id, profileId: profileId),
    );

    return SliverToBoxAdapter(
      child: CommonPostButtonsBuilder(
        post: post,
        onStartSlideshow: controller.startSlideshow,
        onLoadOriginal: () => detailsController.loadOriginalImage(post),
        config: config,
        configViewer: configViewer,
        builder: (context, buttons) => CustomizablePostToolbar(
          key: ValueKey((post, config, profileId)),
          allowCustomization: PostActionToolbarScope.maybeOf(context) == null,
          maxVisibleButtons: 5,
          buttons: [
            if (hasLogin) ...[
              ViewerToolbarButtonData(
                action: ViewerToolbarAction.favorite,
                required: true,
                widget: favorite,
                title: isFaved
                    ? context.t.post.action.unfavorite
                    : context.t.post.action.favorite,
                icon: Icon(isFaved ? Icons.favorite : Icons.favorite_border),
                onTap: favorite.action(context),
              ),
              ViewerToolbarButtonData(
                action: ViewerToolbarAction.upvote,
                required: true,
                widget: SzurubooruUpvotePostButton(post: post),
                title: context.t.post.action.upvote,
                icon: const Icon(Icons.thumb_up_outlined),
                menuBuilder: (_, _) =>
                    SzurubooruUpvotePostButton(post: post, menuItem: true),
              ),
              ViewerToolbarButtonData(
                action: ViewerToolbarAction.downvote,
                required: true,
                widget: SzurubooruDownvotePostButton(post: post),
                title: context.t.post.action.downvote,
                icon: const Icon(Icons.thumb_down_outlined),
                menuBuilder: (_, _) =>
                    SzurubooruDownvotePostButton(post: post, menuItem: true),
              ),
            ],
            ViewerToolbarButtonData(
              action: ViewerToolbarAction.bookmark,
              required: true,
              widget: BookmarkPostButton(post: post, config: config),
              title: context.t.post.action.bookmark,
              icon: const Icon(Icons.bookmark_border),
              menuBuilder: (_, _) => BookmarkPostButton(
                post: post,
                config: config,
                menuItem: true,
              ),
            ),
            if (downloadAction != null)
              ViewerToolbarButtonData(
                action: ViewerToolbarAction.download,
                required: true,
                widget: DownloadPostButton(
                  post: post,
                  download: downloadAction,
                ),
                title: context.t.download.download,
                icon: const Icon(Icons.download),
                onTap: downloadAction,
                menuBuilder: (_, close) => DownloadPostButton(
                  post: post,
                  download: downloadAction,
                  menuItem: true,
                  onMenuAction: close,
                ),
              ),
            ViewerToolbarButtonData(
              action: ViewerToolbarAction.share,
              widget: share,
              title: context.t.post.action.share,
              icon: const Icon(Icons.share),
              onTap: share.action(context, ref),
            ),
            ViewerToolbarButtonData(
              action: ViewerToolbarAction.comments,
              widget: CommentPostButton(
                onPressed: () => goToCommentPage(context, ref, post),
              ),
              title: context.t.post.action.view_comments,
              icon: const Icon(Icons.comment_outlined),
              onTap: () => goToCommentPage(context, ref, post),
            ),
            ...buttons,
          ],
        ),
      ),
    );
  }
}

class SzurubooruUploaderFileDetailTile extends ConsumerWidget {
  const SzurubooruUploaderFileDetailTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);
    final uploaderName = post.uploaderName;

    return switch (uploaderName) {
      null => const SizedBox.shrink(),
      final name => UploaderFileDetailTile(
        uploaderName: name,
        onSearch: switch (ref.watch(szurubooruUploaderQueryProvider(post))) {
          final query? => () => goToSearchPage(
            ref,
            tag: query.resolveTag(),
          ),
          _ => null,
        },
      ),
    };
  }
}

class SzurubooruStatsTileSection extends ConsumerWidget {
  const SzurubooruStatsTileSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);

    return SliverToBoxAdapter(
      child: Column(
        children: [
          SimplePostStatsTile(
            totalComments: post.detailFacts.commentCount,
            favCount: post.detailFacts.favoriteCount,
            score: post.detailFacts.score,
          ),
        ],
      ),
    );
  }
}

class SzurubooruUploaderPostsSection extends ConsumerWidget {
  const SzurubooruUploaderPostsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);

    return UploaderPostsSection<Post>(
      query: ref.watch(
        szurubooruUploaderQueryProvider(post),
      ),
    );
  }
}

class SzurubooruPoolTileSection extends StatelessWidget {
  const SzurubooruPoolTileSection({super.key});

  @override
  Widget build(BuildContext context) {
    final data = InheritedPost.presentationOf(
      context,
    ).data<SzurubooruPostData>();

    return SliverToBoxAdapter(
      child: SzurubooruPoolTiles(pools: data?.pools ?? const []),
    );
  }
}

final kSzurubooruPostDetailsUIBuilder = PostDetailsUIBuilder(
  viewerToolbarProfileActions: szurubooruViewerToolbarActions,
  preview: {
    DetailsPart.toolbar: (context) => const SzurubooruPostActionToolbar(),
  },
  full: {
    DetailsPart.toolbar: (context) => const SzurubooruPostActionToolbar(),
    DetailsPart.stats: (context) => const SzurubooruStatsTileSection(),
    DetailsPart.tags: (context) => const DefaultInheritedTagsTile<Post>(),
    DetailsPart.fileDetails: (context) =>
        const DefaultInheritedFileDetailsSection<Post>(
          uploader: SzurubooruUploaderFileDetailTile(),
        ),
    DetailsPart.pool: (context) => const SzurubooruPoolTileSection(),
    DetailsPart.uploaderPosts: (context) =>
        const SzurubooruUploaderPostsSection(),
  },
);
