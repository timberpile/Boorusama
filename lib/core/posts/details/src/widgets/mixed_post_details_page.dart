// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../notes/note/widgets.dart';
import '../../../details_parts/types.dart';
import '../../../details_parts/widgets.dart';
import '../../../post/types.dart';
import '../providers/providers.dart';
import '../types/inherited_post.dart';
import '../types/post_details.dart';
import 'post_details_actions.dart';
import 'post_details_image_preloader.dart';
import 'post_details_item.dart';
import 'post_details_notes.dart';
import 'post_details_page_scaffold.dart';
import 'post_details_scope.dart';
import 'post_page_presentation_scope.dart';

class MixedPostDetailsPage extends StatelessWidget {
  const MixedPostDetailsPage({
    required this.posts,
    required this.initialIndex,
    required this.initialThumbnailUrl,
    required this.scrollController,
    required this.disclaimer,
    super.key,
  }) : assert(posts.length > 0, 'Mixed viewer requires at least one post'),
       assert(
         initialIndex >= 0 && initialIndex < posts.length,
         'Initial index must reference a post in the mixed viewer',
       );

  final List<Post> posts;
  final int initialIndex;
  final String? initialThumbnailUrl;
  final AutoScrollController? scrollController;
  final String? disclaimer;

  @override
  Widget build(BuildContext context) => PostDetailsScope<Post>(
    initialIndex: initialIndex,
    initialThumbnailUrl: initialThumbnailUrl,
    posts: posts,
    dislclaimer: disclaimer,
    scrollController: scrollController,
    child: const _MixedPostDetailsView(),
  );
}

class _MixedPostDetailsView extends ConsumerStatefulWidget {
  const _MixedPostDetailsView();

  @override
  ConsumerState<_MixedPostDetailsView> createState() =>
      _MixedPostDetailsViewState();
}

class _MixedPostDetailsViewState extends ConsumerState<_MixedPostDetailsView> {
  final _transformController = TransformationController();
  final _isInitPage = ValueNotifier(true);

  @override
  void dispose() {
    _transformController.dispose();
    _isInitPage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final details = PostDetails.of<Post>(context);

    return MixedPostDetailsImagePreloader(
      posts: details.posts,
      child: ValueListenableBuilder<Post>(
        valueListenable: details.controller.currentPost,
        builder: (context, currentPost, _) => PostPagePresentationScope(
          post: currentPost,
          builder: (context, ref, currentPresentation) => _buildViewer(
            context,
            ref,
            details,
            currentPresentation,
          ),
        ),
      ),
    );
  }

  Widget _buildViewer(
    BuildContext context,
    WidgetRef ref,
    PostDetailsData<Post> details,
    PostPagePresentation currentPresentation,
  ) {
    final posts = details.posts;
    final controller = details.controller;
    final config = currentPresentation.effectiveConfig;
    final auth = config.auth;
    final viewer = config.viewer;
    final layout = config.layout;
    final gestures = config.postGestures;
    final booruRepo = ref.watch(booruRepoProvider(auth));
    final uiBuilder = switch ((
      currentPresentation.usesGenericPresentation,
      currentPresentation.context.post,
    )) {
      (true, _) => _genericPostDetailsUiBuilder,
      (false, final UnifiedPost post) =>
        currentPresentation.context.presentation.detailsBuilder(post),
      _ => _genericPostDetailsUiBuilder,
    };

    final scaffold = PostDetailsPageScaffold<Post>(
      transformController: _transformController,
      isInitPage: _isInitPage,
      controller: controller,
      posts: posts,
      postGestureHandlerBuilder: booruRepo?.handlePostGesture,
      uiBuilder: uiBuilder,
      gestureConfig: gestures,
      layoutConfig: layout,
      viewerWarning: currentPresentation.usesGenericPresentation
          ? const PostPresentationFallbackWarning()
          : null,
      actions: defaultActions(
        note: currentPresentation.usesGenericPresentation
            ? null
            : NoteActionButtonWithProvider(
                currentPost: controller.currentPost,
                config: auth,
              ),
        fallbackMoreButton: DefaultFallbackBackupMoreButton<Post>(
          layoutConfig: layout,
          controller: controller,
          authConfig: auth,
          viewerConfig: viewer,
        ),
      ),
      itemBuilder: (context, index) {
        final post = posts[index];
        return PostPagePresentationScope(
          post: post,
          builder: (context, ref, pagePresentation) {
            final pageConfig = pagePresentation.effectiveConfig;
            final pageAuth = pageConfig.auth;
            final pageViewer = pageConfig.viewer;
            final mediaUrlResolver = ref.watch(
              mediaUrlResolverProvider(pageAuth),
            );

            return PostDetailsItem<Post>(
              index: index,
              posts: posts,
              transformController: _transformController,
              isInitPageListenable: _isInitPage,
              authConfig: pageAuth,
              viewerConfig: pageViewer,
              gestureConfig: pageConfig.postGestures,
              imageCacheManager: null,
              detailsController: controller,
              imageUrlBuilder: (post) =>
                  mediaUrlResolver.resolveMediaUrl(post, pageViewer),
              mediaAspectRatioBuilder: (post) =>
                  mediaUrlResolver.resolveMediaAspectRatio(post, pageViewer),
              videoAspectRatioBuilder: (post) =>
                  mediaUrlResolver.resolveVideoAspectRatio(post, pageViewer),
            );
          },
        );
      },
    );

    final post = currentPresentation.context.post;
    final wrapper =
        currentPresentation.context.presentation.detailsWrapperBuilder;
    final behaviorCompanion = switch ((post, wrapper)) {
      (final UnifiedPost post, final wrapper?) => wrapper(
        post: post,
        child: const SizedBox.shrink(),
      ),
      _ => null,
    };

    return CurrentPostDetailsNotes(
      post: post,
      viewerConfig: viewer,
      authConfig: auth,
      enabled: !currentPresentation.usesGenericPresentation,
      child: Stack(
        children: [
          scaffold,
          if (behaviorCompanion != null) Offstage(child: behaviorCompanion),
        ],
      ),
    );
  }
}

final _genericPostDetailsUiBuilder = PostDetailsUIBuilder(
  preview: {
    DetailsPart.info: (context) =>
        const DefaultInheritedInformationSection<Post>(showSource: true),
  },
  full: {
    DetailsPart.info: (context) =>
        const DefaultInheritedInformationSection<Post>(showSource: true),
    DetailsPart.tags: (context) => const _GenericPostTagsSection(),
    DetailsPart.fileDetails: (context) =>
        const DefaultInheritedFileDetailsSection<Post>(),
  },
);

class _GenericPostTagsSection extends StatelessWidget {
  const _GenericPostTagsSection();

  @override
  Widget build(BuildContext context) {
    final post = InheritedPost.of(context);
    final tags = post.tags.toList()..sort();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t.post.detail.widgets.tags,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final tag in tags)
                  Chip(label: Text(tag.replaceAll('_', ' '))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PostPresentationFallbackWarning extends StatelessWidget {
  const PostPresentationFallbackWarning({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.all(12),
    child: Material(
      color: Kurumi.themeOf(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.warning, fill: 1),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                context.t.post.detail.site_features_unavailable,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
