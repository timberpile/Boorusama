// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/providers.dart';
import '../../../../notes/note/widgets.dart';
import '../../../post/types.dart';
import '../../routes.dart';
import '../providers/providers.dart';
import '../types/post_details.dart';
import 'mixed_post_details_page.dart';
import 'post_details_actions.dart';
import 'post_details_image_preloader.dart';
import 'post_details_item.dart';
import 'post_details_notes.dart';
import 'post_details_page_scaffold.dart';

class MixedPostDetailsPageAdapter extends StatelessWidget {
  const MixedPostDetailsPageAdapter({
    required this.payload,
    super.key,
  });

  final DetailsRouteContext payload;

  @override
  Widget build(BuildContext context) {
    return MixedPostDetailsPage(
      posts: payload.posts.cast<Post>(),
      initialIndex: payload.initialIndex,
      initialThumbnailUrl: payload.initialThumbnailUrl,
      scrollController: payload.scrollController,
      disclaimer: payload.dislclaimer,
    );
  }
}

class DefaultPostDetailsPage<T extends Post> extends ConsumerStatefulWidget {
  const DefaultPostDetailsPage({
    super.key,
  });

  @override
  ConsumerState<DefaultPostDetailsPage<T>> createState() =>
      _DefaultPostDetailsPageState<T>();
}

class _DefaultPostDetailsPageState<T extends Post>
    extends ConsumerState<DefaultPostDetailsPage<T>> {
  final _transformController = TransformationController();
  final _isInitPage = ValueNotifier(true);

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = PostDetails.of(context);
    final posts = data.posts;
    final controller = data.controller;
    final auth = ref.watchConfigAuth;
    final viewer = ref.watchConfigViewer;
    final layout = ref.watchLayoutConfigs;
    final gestures = ref.watchPostGestures;
    final booruBuilder = ref.watch(booruBuilderProvider(auth));
    final booruRepo = ref.watch(booruRepoProvider(auth));
    final uiBuilder = booruBuilder?.postDetailsUIBuilder;
    final mediaUrlResolver = ref.watch(mediaUrlResolverProvider(auth));

    return PostDetailsImagePreloader(
      authConfig: auth,
      posts: posts,
      imageUrlBuilder: (post) => mediaUrlResolver.resolveMediaUrl(post, viewer),
      child: PostDetailsNotes(
        posts: posts,
        viewerConfig: viewer,
        authConfig: auth,
        child: PostDetailsPageScaffold(
          transformController: _transformController,
          isInitPage: _isInitPage,
          controller: controller,
          posts: posts,
          postGestureHandlerBuilder: booruRepo?.handlePostGesture,
          uiBuilder: uiBuilder,
          gestureConfig: gestures,
          layoutConfig: layout,
          actions: defaultActions(
            note: NoteActionButtonWithProvider(
              currentPost: controller.currentPost,
              config: auth,
            ),
            fallbackMoreButton: DefaultFallbackBackupMoreButton(
              layoutConfig: layout,
              controller: controller,
              authConfig: auth,
              viewerConfig: viewer,
            ),
          ),
          itemBuilder: (context, index) {
            return PostDetailsItem(
              index: index,
              posts: posts,
              transformController: _transformController,
              isInitPageListenable: _isInitPage,
              authConfig: auth,
              viewerConfig: viewer,
              gestureConfig: gestures,
              imageCacheManager: null,
              detailsController: controller,
              imageUrlBuilder: (post) =>
                  mediaUrlResolver.resolveMediaUrl(post, viewer),
              mediaAspectRatioBuilder: (post) =>
                  mediaUrlResolver.resolveMediaAspectRatio(post, viewer),
              videoAspectRatioBuilder: (post) =>
                  mediaUrlResolver.resolveVideoAspectRatio(post, viewer),
            );
          },
        ),
      ),
    );
  }
}
