// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../../../downloads/filename/types.dart';
import '../../../posts/details/types.dart';
import '../../../posts/details_parts/types.dart';
import '../../../posts/details_parts/widgets.dart';
import '../../../posts/details/widgets.dart';
import '../../../posts/listing/providers.dart';
import '../../../posts/post/types.dart';
import '../../../posts/shares/widgets.dart';
import '../../../widgets/adaptive_button_row.dart';
import '../../../widgets/booru_menu_button_row.dart';
import '../data/providers.dart';
import '../providers/bookmark_provider.dart';

class BookmarkDetailsPage extends StatelessWidget {
  BookmarkDetailsPage({
    required this.initialIndex,
    required this.initialThumbnailUrl,
    required PostGridController<Post> controller,
    super.key,
  }) : posts = List.unmodifiable(controller.items);

  final int initialIndex;
  final String? initialThumbnailUrl;
  final List<Post> posts;

  @override
  Widget build(BuildContext context) => MixedPostDetailsPage(
    posts: posts,
    initialIndex: initialIndex,
    initialThumbnailUrl: initialThumbnailUrl,
    scrollController: null,
    disclaimer: null,
    fallbackUiBuilderDecorator: _withBookmarkToolbar,
  );
}

PostDetailsUIBuilder _withBookmarkToolbar(
  PostDetailsUIBuilder builder,
  Post post,
) => PostDetailsUIBuilder(
  previewAllowedParts: builder.previewAllowedParts,
  preview: {
    ...builder.preview,
    DetailsPart.toolbar: (_) => const BookmarkPostActionToolbar(),
  },
  full: {
    ...builder.full,
    DetailsPart.toolbar: (_) => const BookmarkPostActionToolbar(),
  },
);

class BookmarkPostActionToolbar extends ConsumerWidget {
  const BookmarkPostActionToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);
    final pageController = PostDetailsPageViewScope.of(context);
    final detailsController = PostDetails.of<Post>(context).controller;
    final bookmark = ref
        .watch(bookmarkProvider)
        .valueOrNull
        ?.bookmarkForPost(post);
    final config = switch (const PostOriginResolver().resolve(
      post.origin,
      ref.watch(booruConfigProvider),
    )) {
      ResolvedPostOrigin(:final config) => config,
      _ => null,
    };

    return SliverToBoxAdapter(
      child: CommonPostButtonsBuilder(
        post: post,
        onStartSlideshow: pageController.startSlideshow,
        onLoadOriginal: () => detailsController.loadOriginalImage(post),
        config: config?.auth,
        configViewer: config?.viewer,
        copy: false,
        builder: (context, buttons) => BooruMenuButtonRow(
          crossAxisAlignment: CrossAxisAlignment.start,
          maxVisibleButtons: 4,
          buttons: [
            if (config != null)
              ButtonData(
                required: true,
                widget: BookmarkPostButton(
                  post: post,
                  config: config.auth,
                ),
                title: context.t.post.action.bookmark,
              ),
            if (config != null && bookmark != null)
              ButtonData(
                required: true,
                widget: IconButton(
                  splashRadius: 16,
                  onPressed: () => ref.bookmarks.downloadBookmarks(
                    config.auth,
                    config.download,
                    [bookmark],
                  ),
                  icon: const Icon(Symbols.download),
                ),
                title: context.t.download.download,
              ),
            if (config != null)
              ButtonData(
                required: true,
                widget: SharePostButton(
                  post: post,
                  auth: config.auth,
                  configViewer: config.viewer,
                  download: config.download,
                  imageCacheManager: ref.watch(
                    bookmarkImageCacheManagerProvider,
                  ),
                  filenameBuilder: fallbackFileNameBuilder,
                ),
                title: context.t.post.action.share,
              ),
            ...buttons,
          ],
        ),
      ),
    );
  }
}
