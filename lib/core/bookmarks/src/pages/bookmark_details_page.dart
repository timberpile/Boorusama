import '../../../posts/details/src/types/viewer_entry.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../boorus/engine/providers.dart';
import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../../../content/content_access_provider.dart';
import '../../../content/content_media_access.dart';
import '../../../content/content_media_failures.dart';
import '../../../downloads/filename/types.dart';
import '../../../posts/details/types.dart';
import '../../../posts/details/src/providers/viewer_source_access_provider.dart';
import '../../../posts/details_parts/types.dart';
import '../../../posts/details_parts/widgets.dart';
import '../../../posts/details/widgets.dart';
import '../../../posts/listing/providers.dart';
import '../../../posts/post/types.dart';
import '../../../posts/shares/widgets.dart';
import '../../../widgets/adaptive_button_row.dart';
import '../../../widgets/booru_menu_button_row.dart';
import '../providers/bookmark_provider.dart';
import '../providers/bookmark_hydration_provider.dart';
import '../services/bookmark_hydration_service.dart';
import '../types/bookmark.dart';

class BookmarkDetailsPage extends ConsumerStatefulWidget {
  BookmarkDetailsPage({
    required this.initialIndex,
    required this.initialThumbnailUrl,
    required PostGridController<Post> controller,
    this.entries,
    super.key,
  }) : posts = List.unmodifiable(controller.items);

  final int initialIndex;
  final String? initialThumbnailUrl;
  final List<Post> posts;
  final List<ViewerEntry>? entries;

  @override
  ConsumerState<BookmarkDetailsPage> createState() =>
      _BookmarkDetailsPageState();
}

class _BookmarkDetailsPageState extends ConsumerState<BookmarkDetailsPage> {
  late final List<ViewerEntry> _entries;

  @override
  void initState() {
    super.initState();
    // Capture the actor once, including for legacy callers without entries.
    // Later profile changes revoke this route instead of borrowing an account.
    _entries =
        widget.entries ??
        List.unmodifiable([
          for (final (index, post) in widget.posts.indexed)
            PostViewerEntry(
              post: post,
              occurrenceId: ('bookmark-route', index),
              source:
                  bindViewerOrigin(ref, post.origin) ??
                  const ViewerSourceBinding(BooruConfig.empty),
            ),
        ]);
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(bookmarkProvider).valueOrNull;

    return MixedPostDetailsPage(
      posts: widget.posts,
      entries: _entries,
      initialIndex: widget.initialIndex,
      initialThumbnailUrl: widget.initialThumbnailUrl,
      scrollController: null,
      disclaimer: null,
      fallbackUiBuilderDecorator: _withBookmarkToolbar,
      postRecoveryBuilder: (post, config) {
        final repositoryAvailable =
            ref.read(booruRepoProvider(config.auth)) != null;
        if (!repositoryAvailable) return null;
        if (library == null) {
          // Keep the first frame silent while the bookmark library is loading.
          final pendingLibrary = ref.read(bookmarkProvider.future);
          return () async {
            final loadedLibrary = await pendingLibrary;
            if (!ref.context.mounted) {
              return const PostRecoveryFailure(
                PostPresentationFallbackReason.refreshFailed,
              );
            }
            final bookmark = loadedLibrary.bookmarkForPost(post);
            final postId = bookmark?.postId;
            if (bookmark == null || postId == null || postId <= 0) {
              return const PostRecoveryFailure(
                PostPresentationFallbackReason.incompatiblePresentation,
              );
            }
            return _recoverBookmarkPost(
              ref,
              bookmark: bookmark,
              config: config,
            );
          };
        }
        final bookmark = library.bookmarkForPost(post);
        final postId = bookmark?.postId;
        if (bookmark == null || postId == null || postId <= 0) return null;

        return () => _recoverBookmarkPost(
          ref,
          bookmark: bookmark,
          config: config,
        );
      },
    );
  }
}

Future<PostRecoveryResult> _recoverBookmarkPost(
  WidgetRef ref, {
  required PostBookmark bookmark,
  required BooruConfig config,
}) async {
  final started =
      config.anonymousReadScope?.key ??
      ref.read(contentProfileAccessProvider(config.id))?.key;
  bool current() =>
      ref.context.mounted &&
      started != null &&
      ref.read(contentAccessContextProvider(started))?.config?.auth ==
          config.auth;
  if (!current())
    return const PostRecoveryFailure(
      PostPresentationFallbackReason.refreshFailed,
    );
  try {
    final result = await ref
        .read(bookmarkRecoveryServiceProvider)
        .recover(bookmark, config);
    switch (result) {
      case BookmarkRecoverySuccess(:final post):
        if (!current())
          return const PostRecoveryFailure(
            PostPresentationFallbackReason.refreshFailed,
          );
        await ref
            .read(bookmarkProvider.notifier)
            .upgradeBookmarkSnapshot(bookmark, post, canUpgrade: current);
        if (!current())
          return const PostRecoveryFailure(
            PostPresentationFallbackReason.refreshFailed,
          );
        return PostRecoverySuccess(post);
      case BookmarkRecoveryRemoved():
        return const PostRecoveryFailure(
          PostPresentationFallbackReason.removedUpstreamPost,
        );
      case BookmarkRecoverySkipped():
        return const PostRecoveryFailure(
          PostPresentationFallbackReason.refreshFailed,
        );
      case BookmarkRecoveryFailed() ||
          BookmarkRecoveryRateLimited() ||
          BookmarkRecoveryCancelled():
        return const PostRecoveryFailure(
          PostPresentationFallbackReason.refreshFailed,
        );
    }
  } catch (_) {
    return const PostRecoveryFailure(
      PostPresentationFallbackReason.refreshFailed,
    );
  }
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
        ?.storedBookmarkForPost(post);
    final required = ref.watch(contentAccessRequiredProvider);
    final access = ref.watch(currentContentAccessKeyProvider);
    final resolvedConfig = required
        ? access == null
              ? null
              : ref.watch(contentAccessContextProvider(access))?.config
        : switch (const PostOriginResolver().resolve(
            post.origin,
            ref.watch(booruConfigProvider),
            allowProfileHintFallback: false,
          )) {
            ResolvedPostOrigin(:final config) => config,
            _ => null,
          };
    final failed =
        access != null &&
        bookmark != null &&
        ref.watch(contentMediaFailuresProvider).containsKey((
          access: access,
          bookmarkId: bookmark.id,
        ));
    final visible =
        access == null ||
        ref
                .watch(
                  contentPostVisibilityProvider((access: access, post: post)),
                )
                .asData
                ?.value ==
            true;
    final config = failed || !visible ? null : resolvedConfig;

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
            if (config != null &&
                config.anonymousReadScope == null &&
                bookmark != null)
              ButtonData(
                required: true,
                widget: IconButton(
                  splashRadius: 16,
                  onPressed: () async {
                    await ref.bookmarks.downloadBookmarks(
                      config.auth,
                      config.download,
                      [bookmark.copyWith(post: post)],
                    );
                  },
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
