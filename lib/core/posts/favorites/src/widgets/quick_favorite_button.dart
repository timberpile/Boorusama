// Dart imports:
import 'dart:async';
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
import '../types/types.dart';
import 'favorite_action.dart';

class QuickFavoriteButton extends ConsumerStatefulWidget {
  const QuickFavoriteButton({
    required this.isFaved,
    super.key,
    this.onFavToggle,
    this.controlled = false,
  });

  final Future<void> Function(bool value)? onFavToggle;
  final bool isFaved;
  final bool controlled;

  @override
  ConsumerState<QuickFavoriteButton> createState() =>
      _QuickFavoriteButtonState();
}

class _QuickFavoriteButtonState extends ConsumerState<QuickFavoriteButton> {
  bool? _likedOnTap;

  @override
  Widget build(BuildContext context) {
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
              isLiked: _likedOnTap ?? widget.isFaved,
              controlled: widget.controlled,
              onTap: (isLiked) async {
                if (_likedOnTap != null) return null;
                final liked = !isLiked;
                // Keep the shared notifier's optimistic state from animating
                // this button before the callback acknowledges the mutation.
                setState(() => _likedOnTap = isLiked);
                try {
                  final result = await runFavoriteAction(context, () async {
                    await widget.onFavToggle?.call(liked);
                  }, isCurrent: () => mounted);
                  if (result == null || !mounted) return null;

                  if (liked && hapticsLevel.isBalanceAndAbove) {
                    unawaited(HapticFeedback.mediumImpact());
                  }

                  return liked;
                } finally {
                  if (mounted) setState(() => _likedOnTap = null);
                }
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
    final profileId = ref.watchConfig.id;

    return canFavorite
        ? QuickFavoriteButton(
            key: ValueKey((config.computeHash(), profileId, post.id)),
            isFaved: ref.watch(favoriteProvider((config, post.id))),
            controlled: true,
            onFavToggle: (isFaved) async {
              final confirmed = await notifier.setFavorite(
                post.id,
                favorited: isFaved,
                profileId: profileId,
              );
              if (!confirmed) {
                throw FavoriteActionFailure.unconfirmed;
              }
            },
          )
        : const SizedBox.shrink();
  }
}
