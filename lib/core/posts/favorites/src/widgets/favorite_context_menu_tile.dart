// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/widgets.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

// Project imports:
import '../../../../configs/config/providers.dart';
import '../../../post/types.dart';
import '../providers/favorites_notifier.dart';
import '../types/types.dart';
import 'favorite_action.dart';

class FavoriteContextMenuTile extends ConsumerWidget {
  const FavoriteContextMenuTile({
    required this.post,
    this.feedbackContext,
    super.key,
  });

  final Post post;
  final BuildContext? feedbackContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final loginDetails = ref.watch(booruLoginDetailsProvider(config));
    final canFavorite = ref.watch(canFavoriteProvider(config));

    if (!loginDetails.hasLogin() || !canFavorite) {
      return const SizedBox.shrink();
    }

    final notifier = ref.watch(favoritesProvider(config).notifier);
    final params = (config, post.id);
    final isFaved = ref.watch(favoriteStatusProvider(params));
    final isFavorited = isFaved ?? false;
    ref.watch(favoriteStatusLoaderProvider(params));

    return KurumiContextMenuTile(
      title: isFavorited
          ? context.t.post.action.unfavorite
          : context.t.post.action.favorite,
      enabled: isFaved != null,
      onTap: isFaved != null
          ? () {
              unawaited(
                _toggleFavorite(
                  feedbackContext ?? context,
                  notifier,
                  isFavorited: isFavorited,
                  postId: post.id,
                ),
              );
            }
          : null,
    );
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    FavoritesNotifier notifier, {
    required bool isFavorited,
    required int postId,
  }) async {
    final result = await runFavoriteAction(
      context,
      () async => isFavorited
          ? await notifier.remove(postId)
          : switch (await notifier.add(postId)) {
              AddFavoriteStatus.success ||
              AddFavoriteStatus.alreadyExists => true,
              _ => false,
            },
    );

    if (!context.mounted || result == null || result.cleanupInterrupted) return;
    final success = result.value;

    if (success) {
      Kurumi.showSuccessToast(
        context,
        context.t.favorites.update.success,
        duration: KurumiDurations.shortToast,
      );
    } else {
      Kurumi.showErrorToast(
        context,
        context.t.favorites.update.failure,
        duration: KurumiDurations.shortToast,
      );
    }
  }
}
