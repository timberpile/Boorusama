// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/details_parts/types.dart';
import '../../../core/posts/details_parts/widgets.dart';
import '../../../core/posts/favorites/providers.dart';
import '../../../core/posts/favorites/widgets.dart';
import '../../../core/posts/shares/widgets.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/router.dart';
import '../../../core/search/search/routes.dart';
import '../../../core/widgets/adaptive_button_row.dart';
import '../../../core/widgets/booru_menu_button_row.dart';
import '../configs/providers.dart';
import '../pools/widgets.dart';
import '../post_votes/widgets.dart';
import 'post_data.dart';
import 'providers.dart';

class SzurubooruPostActionToolbar extends ConsumerWidget {
  const SzurubooruPostActionToolbar({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);
    final controller = PostDetailsPageViewScope.of(context);
    final detailsController = PostDetails.of<Post>(context).controller;

    final config = ref.watchConfigAuth;
    final configViewer = ref.watchConfigViewer;
    final download = ref.watchConfigDownload;
    final isFaved = ref.watch(favoriteProvider((config, post.id)));
    final favNotifier = ref.watch(favoritesProvider(config).notifier);
    final loginDetails = ref.watch(szurubooruLoginDetailsProvider(config));

    return SliverToBoxAdapter(
      child: CommonPostButtonsBuilder(
        post: post,
        onStartSlideshow: controller.startSlideshow,
        onLoadOriginal: () => detailsController.loadOriginalImage(post),
        config: config,
        configViewer: configViewer,
        builder: (context, buttons) {
          return BooruMenuButtonRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            maxVisibleButtons: 5,
            buttons: [
              if (loginDetails.hasLogin())
                ButtonData(
                  required: true,
                  widget: FavoritePostButton(
                    isFaved: isFaved,
                    isAuthorized: loginDetails.hasLogin(),
                    addFavorite: () => favNotifier.add(post.id),
                    removeFavorite: () => favNotifier.remove(post.id),
                  ),
                  title: context.t.post.action.favorite,
                ),
              if (loginDetails.hasLogin())
                ButtonData(
                  required: true,
                  widget: SzurubooruUpvotePostButton(
                    post: post,
                  ),
                  title: context.t.post.action.upvote,
                ),
              if (loginDetails.hasLogin())
                ButtonData(
                  required: true,
                  widget: SzurubooruDownvotePostButton(
                    post: post,
                  ),
                  title: context.t.post.action.downvote,
                ),
              ButtonData(
                required: true,
                widget: BookmarkPostButton(post: post, config: config),
                title: context.t.post.action.bookmark,
              ),
              ButtonData(
                required: true,
                widget: DownloadPostButton(post: post),
                title: context.t.download.download,
              ),
              ButtonData(
                widget: SharePostButton(
                  post: post,
                  auth: config,
                  configViewer: configViewer,
                  download: download,
                ),
                title: context.t.post.action.share,
              ),
              ButtonData(
                widget: CommentPostButton(
                  onPressed: () => goToCommentPage(context, ref, post),
                ),
                title: context.t.post.action.view_comments,
                onTap: () => goToCommentPage(context, ref, post),
              ),
              ...buttons,
            ],
          );
        },
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
    final data = InheritedPost.presentationOf(
      context,
    ).data<SzurubooruPostData>();

    return SliverToBoxAdapter(
      child: Column(
        children: [
          SimplePostStatsTile(
            totalComments: data?.commentCount ?? 0,
            favCount: data?.favoriteCount ?? 0,
            score: post.score,
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
