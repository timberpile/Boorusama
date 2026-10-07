// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:like_button/like_button.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../configs/config/providers.dart';
import '../../../../settings/providers.dart';
import '../../../../themes/theme/types.dart';
import '../../../post/types.dart';
import '../../../post/src/widgets/thumbnail_overlay.dart';
import '../providers/favorites_notifier.dart';
import 'favorite_action.dart';

class QuickFavoriteButton extends ConsumerWidget {
  const QuickFavoriteButton({
    required this.isFaved,
    super.key,
    this.onFavToggle,
  });

  final Future<void> Function(bool value)? onFavToggle;
  final bool isFaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticsLevel = ref.watch(hapticFeedbackLevelProvider);

    return SizedBox.square(
      dimension: ThumbnailOverlayDimensions.favoriteTouchTarget,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width:
                ThumbnailOverlayDimensions.favoriteIcon +
                ThumbnailOverlayDimensions.favoritePadding * 2,
            height:
                ThumbnailOverlayDimensions.favoriteIcon +
                ThumbnailOverlayDimensions.favoritePadding * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.extendedColorScheme.surfaceContainerOverlay,
            ),
          ),
          LikeButton(
            size: ThumbnailOverlayDimensions.favoriteIcon,
            // Extend the touch target toward the top and left, keeping the
            // visible button at the thumbnail's bottom-right inset. LikeButton
            // owns padding taps as well as the animation and async action flow.
            padding: const EdgeInsets.only(
              top:
                  ThumbnailOverlayDimensions.favoriteTouchTarget -
                  ThumbnailOverlayDimensions.favoriteIcon -
                  ThumbnailOverlayDimensions.favoritePadding,
              left:
                  ThumbnailOverlayDimensions.favoriteTouchTarget -
                  ThumbnailOverlayDimensions.favoriteIcon -
                  ThumbnailOverlayDimensions.favoritePadding,
              bottom: ThumbnailOverlayDimensions.favoritePadding,
              right: ThumbnailOverlayDimensions.favoritePadding,
            ),
            likeCountPadding: EdgeInsets.zero,
            isLiked: isFaved,
            onTap: (isLiked) async {
              final liked = !isLiked;
              final result = await runFavoriteAction(context, () async {
                await onFavToggle?.call(liked);
              });
              if (result == null) return isLiked;

              if (liked && hapticsLevel.isBalanceAndAbove) {
                await HapticFeedback.mediumImpact();
              }

              return liked;
            },
            likeBuilder: (isLiked) {
              return Icon(
                Symbols.favorite,
                size: ThumbnailOverlayDimensions.favoriteIcon,
                color: isLiked
                    ? context.colors.upvoteColor
                    : context.extendedColorScheme.onSurfaceContainerOverlay,
                fill: isLiked ? 1 : 0,
              );
            },
          ),
        ],
      ),
    );
  }
}

class DefaultQuickFavoriteButton extends ConsumerWidget {
  const DefaultQuickFavoriteButton({
    required this.post,
    super.key,
  });

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final notifier = ref.watch(favoritesProvider(config).notifier);
    final canFavorite = ref.watch(canFavoriteProvider(config));

    return canFavorite
        ? QuickFavoriteButton(
            isFaved: ref.watch(favoriteProvider((config, post.id))),
            onFavToggle: (isFaved) async {
              if (isFaved) {
                await notifier.add(post.id);
              } else {
                await notifier.remove(post.id);
              }
            },
          )
        : const SizedBox.shrink();
  }
}
