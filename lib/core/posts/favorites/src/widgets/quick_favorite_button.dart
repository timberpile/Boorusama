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
import '../../../../themes/colors/src/colors.dart';
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
    this.enabled = true,
    this.isCurrent,
  });

  final Future<void> Function(bool value)? onFavToggle;
  final bool isFaved;
  final bool controlled;
  final bool enabled;
  final bool Function()? isCurrent;

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
        builder: (context, constraints) => KurumiLikeButton(
          size: ThumbnailOverlayDimensions.favoriteIcon,
          // The quick-action group can constrain the 48 px touch target.
          // Fit the slot and keep the transparent padding tappable.
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
          enabled: widget.enabled,
          onTap: (isLiked) async {
            final isCurrent = widget.isCurrent;
            bool current() => mounted && (isCurrent?.call() ?? true);
            if (_likedOnTap != null || !current()) return null;
            final liked = !isLiked;
            // Keep the shared notifier's optimistic state from animating
            // this button before the callback acknowledges the mutation.
            setState(() => _likedOnTap = isLiked);
            try {
              final result = await runFavoriteAction(context, () async {
                await widget.onFavToggle?.call(liked);
              }, isCurrent: current);
              if (result == null || !current()) return null;

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
                  ? Kurumi.themeOf(context)
                            .extension<BoorusamaColors>()
                            ?.upvoteColor ??
                        Theme.of(context).colorScheme.primary
                  : context.extendedColorScheme.onSurfaceContainerOverlay,
              fill: isLiked ? 1 : 0,
              shadows: const [mediaOverlayIconShadow],
            );
          },
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
