// Package imports:
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../images/booru_image.dart';
import '../../../../settings/providers.dart';
import '../../../post/types.dart';
import '../../../post/widgets.dart';
import '../providers/providers.dart';
import '../types/grid_thumbnail_url_generator.dart';
import '../types/image_list_type.dart';
import 'default_image_quick_action_button.dart';
import 'default_selectable_item.dart';
import 'post_preview.dart';
import 'sliver_post_grid_image_grid_item.dart';

typedef PostGridImageBuilder = Widget Function(GridThumbnailMedia media);
typedef PostGridTooltipBuilder = Widget Function(Widget child);

abstract interface class BooruPostGridPresentation {
  PostGridItemAdditions buildGridItemAdditions(
    BuildContext context, {
    required Post post,
    required BooruConfigAuth config,
  });
}

abstract interface class BooruPostGridContextMenuPresentation {
  Widget buildGridContextMenu(
    BuildContext context, {
    required Post post,
    required int index,
    required Widget child,
  });
}

final class PostGridItemAdditions {
  const PostGridItemAdditions({
    this.quickActionButton,
    this.blockOverlay,
    this.tooltipBuilder,
    this.disablePostInteraction = false,
    this.hideScore = false,
    this.imageAspectRatio,
  });

  static const empty = PostGridItemAdditions();

  final Widget? quickActionButton;
  final BlockOverlayItem? blockOverlay;
  final PostGridTooltipBuilder? tooltipBuilder;
  final bool disablePostInteraction;
  final bool hideScore;
  final double? imageAspectRatio;
}

class PostGridItem extends ConsumerWidget {
  const PostGridItem({
    required this.post,
    required this.index,
    required this.useHero,
    required this.multiSelectEnabled,
    required this.config,
    required this.onTap,
    super.key,
    this.autoScrollOptions,
    this.leadingIcons,
    this.imageUrl,
    this.imageCacheManager,
    this.imageConfig,
    this.imageBuilder,
    this.quickActionButton,
    this.blockOverlay,
    this.presentation,
    this.additions,
    this.disablePostInteraction,
  });

  final Post post;
  final int index;
  final bool useHero;
  final bool multiSelectEnabled;
  final BooruConfigAuth config;
  final ValueChanged<GridThumbnailMedia>? onTap;
  final AutoScrollOptions? autoScrollOptions;
  final List<Widget>? leadingIcons;
  final String? imageUrl;
  final ImageCacheManager? imageCacheManager;
  final BooruConfigAuth? imageConfig;
  final PostGridImageBuilder? imageBuilder;
  final Widget? quickActionButton;
  final BlockOverlayItem? blockOverlay;
  final BooruPostPresentation? presentation;
  final PostGridItemAdditions? additions;
  final bool? disablePostInteraction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gridThumbnailUrlBuilder = ref.watch(
      gridThumbnailUrlGeneratorProvider(config),
    );
    final thumbnailSettings = ref.watch(
      gridThumbnailSettingsProvider(config),
    );
    final resolvedMedia = imageUrl != null
        ? GridThumbnailMedia(
            url: imageUrl!,
            aspectRatio: post.aspectRatio,
            placeholderUrl: post.thumbnailImageUrl,
            placeholderAspectRatio: post.aspectRatio,
          )
        : gridThumbnailUrlBuilder.resolve(
            post,
            settings: thumbnailSettings,
          );
    final resolvedAdditions = additions ?? _resolveAdditions(context, ref);
    final media = switch (resolvedAdditions.imageAspectRatio) {
      final aspectRatio? => GridThumbnailMedia(
        url: resolvedMedia.url,
        aspectRatio: aspectRatio,
        fallbackUrl: resolvedMedia.fallbackUrl,
        placeholderUrl: resolvedMedia.placeholderUrl,
        placeholderAspectRatio: resolvedMedia.placeholderAspectRatio,
        placeholderFit: resolvedMedia.placeholderFit,
      ),
      null => resolvedMedia,
    };
    final effectiveQuickAction = switch ((
      multiSelectEnabled,
      quickActionButton,
      resolvedAdditions.quickActionButton,
    )) {
      (true, _, _) => null,
      (false, final Widget quickAction, _) => quickAction,
      _ => DefaultImagePreviewQuickActionButton(
        post: post,
        defaultActionButton: resolvedAdditions.quickActionButton,
      ),
    };
    final effectiveBlockOverlay =
        blockOverlay ?? resolvedAdditions.blockOverlay;
    final image =
        imageBuilder?.call(media) ??
        _PostGridImage(
          media: media,
          imageCacheManager: imageCacheManager,
          config: imageConfig ?? config,
        );

    final item = SliverPostGridImageGridItem(
      post: post,
      index: index,
      config: config,
      multiSelectEnabled: multiSelectEnabled,
      onTap:
          (disablePostInteraction ?? resolvedAdditions.disablePostInteraction)
          ? null
          : () => onTap?.call(media),
      quickActionButton: effectiveQuickAction,
      autoScrollOptions: autoScrollOptions,
      score: resolvedAdditions.hideScore ? null : post.score,
      image: image,
      leadingIcons: leadingIcons,
      blockOverlay: effectiveBlockOverlay,
    );
    final selectableItem = DefaultSelectableItem(
      index: index,
      post: post,
      item: item,
      config: config,
      indicatorSize: ref.watch(selectionIndicatorSizeProvider),
    );
    final tooltip =
        resolvedAdditions.tooltipBuilder?.call(selectableItem) ??
        DefaultTagListPrevewTooltip(
          post: post,
          config: config,
          child: selectableItem,
        );

    return HeroMode(
      enabled: useHero,
      child: KurumiHero(
        tag: postHeroTag(post),
        child: ExplicitContentBlockOverlay(
          rating: post.rating,
          child: tooltip,
        ),
      ),
    );
  }

  PostGridItemAdditions _resolveAdditions(
    BuildContext context,
    WidgetRef ref,
  ) {
    final resolvedPresentation = switch (presentation) {
      final presentation? => presentation,
      null => ref.watch(
        booruPostPresentationProvider(
          PostPresentationRequest(
            origin: post.origin,
            data: post.booruData,
          ),
        ),
      ),
    };
    if (!resolvedPresentation.supports(post.booruData)) {
      return PostGridItemAdditions.empty;
    }
    if (resolvedPresentation is! BooruPostGridPresentation) {
      return PostGridItemAdditions.empty;
    }
    final gridPresentation = resolvedPresentation as BooruPostGridPresentation;

    return gridPresentation.buildGridItemAdditions(
      context,
      post: post,
      config: config,
    );
  }
}

class _PostGridImage extends ConsumerWidget {
  const _PostGridImage({
    required this.media,
    required this.config,
    this.imageCacheManager,
  });

  final GridThumbnailMedia media;
  final ImageCacheManager? imageCacheManager;
  final BooruConfigAuth config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageBorderRadius = ref.watch(
      imageListingSettingsProvider.select((v) => v.imageBorderRadius),
    );
    final imageListType = ref.watch(
      imageListingSettingsProvider.select((v) => v.imageListType),
    );

    return BooruImage(
      config: config,
      aspectRatio: media.aspectRatio,
      imageUrl: media.url,
      fallbackUrl: media.fallbackUrl,
      borderRadius: BorderRadius.circular(imageBorderRadius),
      forceCover: imageListType == ImageListType.standard,
      fit: imageListType == ImageListType.classic ? BoxFit.contain : null,
      placeholderUrl: media.placeholderUrl,
      placeholderAspectRatio: media.placeholderAspectRatio,
      placeholderFit: media.placeholderFit,
      imageCacheManager: imageCacheManager,
    );
  }
}
