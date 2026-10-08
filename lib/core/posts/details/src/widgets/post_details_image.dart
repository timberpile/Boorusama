// Package imports:
import 'package:cache_manager/cache_manager.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../images/booru_image.dart';
import '../../../../notes/note/providers.dart';
import '../../../../notes/note/types.dart';
import '../../../../notes/note/widgets.dart';
import '../../../listing/providers.dart';
import '../../../listing/types.dart';
import '../../../post/types.dart';
import '../providers/note_overlay_provider.dart';
import 'progressive_post_image.dart';

typedef PostDetailsPlaceholderMediaBuilder<T extends Post> =
    GridThumbnailMedia Function(T post);

class PostDetailsImage<T extends Post> extends StatelessWidget {
  const PostDetailsImage({
    required this.config,
    required this.imageUrlBuilder,
    required this.mediaAspectRatioBuilder,
    required this.placeholderMediaBuilder,
    required this.post,
    super.key,
    this.heroTag,
    this.imageCacheManager,
    this.imageController,
    this.onRepresentationChanged,
  });

  final BooruConfigAuth config;
  final String? heroTag;
  final String Function(T post)? imageUrlBuilder;
  final double? Function(T post)? mediaAspectRatioBuilder;
  final PostDetailsPlaceholderMediaBuilder<T>? placeholderMediaBuilder;
  final ImageCacheManager? imageCacheManager;
  final ExtendedImageController? imageController;
  final ValueChanged<bool>? onRepresentationChanged;
  final T post;

  @override
  Widget build(BuildContext context) {
    final aspectRatio =
        _postAspectRatio(post) ??
        mediaAspectRatioBuilder?.call(post) ??
        post.effectiveSampleAspectRatio;

    return aspectRatio != null
        ? AspectRatio(
            aspectRatio: aspectRatio,
            child: Consumer(
              builder: (_, ref, _) => Stack(
                children: [
                  RawPostDetailsImage(
                    config: config,
                    post: post,
                    heroTag: heroTag,
                    imageUrlBuilder: imageUrlBuilder,
                    mediaAspectRatioBuilder: mediaAspectRatioBuilder,
                    placeholderMediaBuilder: placeholderMediaBuilder,
                    imageCacheManager: imageCacheManager,
                    imageController: imageController,
                    onRepresentationChanged: onRepresentationChanged,
                  ),
                  ..._buildNotes(ref),
                ],
              ),
            ),
          )
        : RawPostDetailsImage(
            config: config,
            post: post,
            heroTag: heroTag,
            imageUrlBuilder: imageUrlBuilder,
            mediaAspectRatioBuilder: mediaAspectRatioBuilder,
            placeholderMediaBuilder: placeholderMediaBuilder,
            imageCacheManager: imageCacheManager,
            imageController: imageController,
            onRepresentationChanged: onRepresentationChanged,
          );
  }

  List<Widget> _buildNotes(WidgetRef ref) {
    final params = (config, post);
    final noteState = ref.watch(notesControllerProvider(post));
    final notes = ref.watch(currentNotesProvider(params)) ?? <Note>[].lock;
    final noteOverlayNotifier = ref.watch(noteOverlayProvider(params).notifier);

    return [
      if (noteState.enableNotes)
        ...notes.map(
          (note) => LayoutBuilder(
            builder: (context, constraints) => PostNote(
              note: note.adjust(
                width: post.width,
                height: post.height,
                widthConstraint: constraints.maxWidth,
                heightConstraint: constraints.maxHeight,
              ),
              onShow: () {
                noteOverlayNotifier.setVisible(true);
              },
              onHide: () {
                noteOverlayNotifier.setVisible(false);
              },
            ),
          ),
        ),
    ];
  }
}

class RawPostDetailsImage<T extends Post> extends ConsumerWidget {
  const RawPostDetailsImage({
    required this.config,
    required this.post,
    super.key,
    this.heroTag,
    this.imageUrlBuilder,
    this.mediaAspectRatioBuilder,
    this.placeholderMediaBuilder,
    this.imageCacheManager,
    this.imageController,
    this.onRepresentationChanged,
    this.fit,
  });

  final BooruConfigAuth config;
  final String? heroTag;
  final String Function(T post)? imageUrlBuilder;
  final double? Function(T post)? mediaAspectRatioBuilder;
  final PostDetailsPlaceholderMediaBuilder<T>? placeholderMediaBuilder;
  final ImageCacheManager? imageCacheManager;
  final ExtendedImageController? imageController;
  final ValueChanged<bool>? onRepresentationChanged;
  final T post;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = imageUrlBuilder != null
        ? imageUrlBuilder!(post)
        : post.thumbnailImageUrl;
    final aspectRatio =
        _postAspectRatio(post) ??
        mediaAspectRatioBuilder?.call(post) ??
        post.effectiveThumbnailAspectRatio;

    if (imageUrl.isEmpty) {
      return NullableAspectRatio(
        aspectRatio: aspectRatio,
        child: const KurumiImagePlaceholder(
          borderRadius: BorderRadius.zero,
        ),
      );
    }

    final gridThumbnailUrlBuilder = ref.watch(
      gridThumbnailUrlGeneratorProvider(config),
    );
    final gridThumbnailSettings = ref.watch(
      gridThumbnailSettingsProvider(config),
    );
    final gridMedia = gridThumbnailUrlBuilder.resolve(
      post,
      settings: gridThumbnailSettings,
    );
    final placeholderMedia = placeholderMediaBuilder?.call(post) ?? gridMedia;
    final image = ProgressivePostImage(
      mediaIdentity: postViewerIdentity(post),
      config: config,
      imageUrl: imageUrl,
      lowerMedia: placeholderMedia,
      aspectRatio: aspectRatio,
      geometryAspectRatio: post.width > 0 && post.height > 0
          ? post.width / post.height
          : null,
      fit: fit,
      imageCacheManager: imageCacheManager,
      controller: imageController,
      onRepresentationChanged: onRepresentationChanged,
    );

    return KurumiHero(
      tag: heroTag,
      child: aspectRatio != null
          ? AspectRatio(
              aspectRatio: aspectRatio,
              child: image,
            )
          : LayoutBuilder(
              builder: (context, constraints) => image,
            ),
    );
  }
}

// Representation metadata may describe a crop. Keep known full-post geometry
// stable while thumbnail, sample and original providers replace each other.
double? _postAspectRatio(Post post) =>
    post.width > 0 && post.height > 0 ? post.width / post.height : null;
