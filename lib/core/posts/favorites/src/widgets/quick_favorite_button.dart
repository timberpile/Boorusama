// Dart imports:
import 'dart:math' as math;

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
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
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
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
            KurumiLikeButton(
              size: ThumbnailOverlayDimensions.favoriteIcon,
              // The quick-action group can constrain the 48 px touch target.
              // Use the actual slot so the icon stays centered on its background
              // while the transparent padding still handles favorite taps.
              padding: EdgeInsets.only(
                top: math.max(
                  0,
                  constraints.maxHeight -
                      ThumbnailOverlayDimensions.favoriteIcon -
                      ThumbnailOverlayDimensions.favoritePadding,
                ),
                left: math.max(
                  0,
                  constraints.maxWidth -
                      ThumbnailOverlayDimensions.favoriteIcon -
                      ThumbnailOverlayDimensions.favoritePadding,
                ),
                bottom: ThumbnailOverlayDimensions.favoritePadding,
                right: ThumbnailOverlayDimensions.favoritePadding,
              ),
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
              builder: (isLiked) {
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
