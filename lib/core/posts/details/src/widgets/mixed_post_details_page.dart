// Dart imports:
import 'dart:async';

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

sealed class PostRecoveryResult {
  const PostRecoveryResult();
}

final class PostRecoverySuccess extends PostRecoveryResult {
  const PostRecoverySuccess(this.post);

  final Post post;
}

final class PostRecoveryFailure extends PostRecoveryResult {
  const PostRecoveryFailure(this.reason);

  final PostPresentationFallbackReason reason;
}

typedef PostRecoveryCallback = Future<PostRecoveryResult> Function();
typedef PostRecoveryBuilder =
    PostRecoveryCallback? Function(Post post, BooruConfig config);

class MixedPostDetailsPage extends StatefulWidget {
  const MixedPostDetailsPage({
    required this.posts,
    required this.initialIndex,
    required this.initialThumbnailUrl,
    required this.scrollController,
    required this.disclaimer,
    this.fallbackUiBuilderDecorator,
    this.postRecoveryBuilder,
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
  final PostDetailsUIBuilder Function(PostDetailsUIBuilder, Post)?
  fallbackUiBuilderDecorator;
  final PostRecoveryBuilder? postRecoveryBuilder;

  @override
  State<MixedPostDetailsPage> createState() => _MixedPostDetailsPageState();
}

class _MixedPostDetailsPageState extends State<MixedPostDetailsPage> {
  late final List<Post> _posts = widget.posts.toList();

  @override
  Widget build(BuildContext context) => PostDetailsScope<Post>(
    initialIndex: widget.initialIndex,
    initialThumbnailUrl: widget.initialThumbnailUrl,
    posts: _posts,
    dislclaimer: widget.disclaimer,
    scrollController: widget.scrollController,
    child: _MixedPostDetailsView(
      fallbackUiBuilderDecorator: widget.fallbackUiBuilderDecorator,
      postRecoveryBuilder: widget.postRecoveryBuilder,
    ),
  );
}

class _MixedPostDetailsView extends ConsumerStatefulWidget {
  const _MixedPostDetailsView({
    required this.fallbackUiBuilderDecorator,
    required this.postRecoveryBuilder,
  });

  final PostDetailsUIBuilder Function(PostDetailsUIBuilder, Post)?
  fallbackUiBuilderDecorator;
  final PostRecoveryBuilder? postRecoveryBuilder;

  @override
  ConsumerState<_MixedPostDetailsView> createState() =>
      _MixedPostDetailsViewState();
}

class _MixedPostDetailsViewState extends ConsumerState<_MixedPostDetailsView> {
  final _transformController = TransformationController();
  final _isInitPage = ValueNotifier(true);
  final _fallbackReasons = <int, PostPresentationFallbackReason>{};
  final _recovering = <int>{};

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
    final currentPost = currentPresentation.context.post;
    final currentIndex = controller.currentPage.value;
    final fallbackReason =
        _fallbackReasons[currentIndex] ?? currentPresentation.fallbackReason;
    final recovery = switch ((
      fallbackReason,
      currentPresentation.config,
      widget.postRecoveryBuilder,
      _recovering.contains(currentIndex),
    )) {
      (
        final PostPresentationFallbackReason _,
        final config?,
        final builder?,
        false,
      ) =>
        builder(currentPost, config),
      _ => null,
    };
    final uiBuilder = currentPresentation.usesGenericPresentation
        ? widget.fallbackUiBuilderDecorator?.call(
                _genericPostDetailsUiBuilder,
                currentPost,
              ) ??
              _genericPostDetailsUiBuilder
        : currentPresentation.context.presentation.detailsBuilder(currentPost);

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
          ? PostPresentationFallbackWarning(
              reason: fallbackReason!,
              onRetry: recovery == null
                  ? null
                  : () => unawaited(
                      _recoverPost(
                        details: details,
                        index: currentIndex,
                        recovery: recovery,
                      ),
                    ),
            )
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

    final post = currentPost;
    final wrapper =
        currentPresentation.context.presentation.detailsWrapperBuilder;
    final behaviorCompanion = wrapper == null
        ? null
        : wrapper(
            post: post,
            child: const SizedBox.shrink(),
          );

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

  Future<void> _recoverPost({
    required PostDetailsData<Post> details,
    required int index,
    required PostRecoveryCallback recovery,
  }) async {
    setState(() => _recovering.add(index));
    late final PostRecoveryResult result;
    try {
      result = await recovery();
    } catch (_) {
      result = const PostRecoveryFailure(
        PostPresentationFallbackReason.refreshFailed,
      );
    }
    if (!mounted) return;

    switch (result) {
      case PostRecoverySuccess(:final post):
        details.controller.replacePost(index, post);
        setState(() {
          _fallbackReasons.remove(index);
          _recovering.remove(index);
        });
      case PostRecoveryFailure(:final reason):
        setState(() {
          _fallbackReasons[index] = reason;
          _recovering.remove(index);
        });
    }
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
  const PostPresentationFallbackWarning({
    required this.reason,
    this.onRetry,
    super.key,
  });

  final PostPresentationFallbackReason reason;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = switch (reason) {
      PostPresentationFallbackReason.missingProfile =>
        context.t.post.detail.fallback.missing_profile,
      PostPresentationFallbackReason.ambiguousProfile =>
        context.t.post.detail.fallback.ambiguous_profile,
      PostPresentationFallbackReason.unavailableEngine =>
        context.t.post.detail.fallback.unavailable_engine,
      PostPresentationFallbackReason.malformedData =>
        context.t.post.detail.fallback.malformed_data,
      PostPresentationFallbackReason.unsupportedVersion =>
        context.t.post.detail.fallback.unsupported_version,
      PostPresentationFallbackReason.removedUpstreamPost =>
        context.t.post.detail.fallback.removed_upstream_post,
      PostPresentationFallbackReason.refreshFailed =>
        context.t.post.detail.fallback.refresh_failed,
      PostPresentationFallbackReason.incompatiblePresentation =>
        context.t.post.detail.site_features_unavailable,
    };

    return SafeArea(
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
                  message,
                  textAlign: TextAlign.center,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onRetry,
                  child: Text(context.t.generic.action.retry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
