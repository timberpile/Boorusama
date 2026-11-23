// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../configs/config/providers.dart';
import '../../../../configs/manage/providers.dart';
import '../../../post/types.dart';
import '../providers/favorites_notifier.dart';
import '../types/types.dart';
import 'favorite_action.dart';

class FavoriteContextMenuTile extends ConsumerWidget {
  const FavoriteContextMenuTile({
    required this.post,
    this.feedbackContext,
    this.popup = false,
    this.canExecute,
    super.key,
  });

  final Post post;
  final bool popup;
  final bool Function()? canExecute;
  final BuildContext? feedbackContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileId = ref.watchConfig.id;
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
    final isLoading = ref.watch(favoriteLookupPendingProvider(params));
    bool isCurrent() =>
        context.mounted &&
        ref.readConfig.id == profileId &&
        ref.readConfigAuth == config;
    final feedback = feedbackContext ?? context;
    bool canShowFeedback() {
      if (!feedback.mounted) return false;
      if (context.mounted) return isCurrent();
      // A popup can close while the action is pending. Its caller can provide
      // a longer-lived feedback context for the same profile.
      final container = ProviderScope.containerOf(feedback, listen: false);
      return container.read(currentReadOnlyBooruConfigProvider).id ==
              profileId &&
          container.read(currentReadOnlyBooruConfigAuthProvider) == config;
    }

    final title = isFavorited
        ? context.t.post.action.unfavorite
        : context.t.post.action.favorite;
    void toggle() {
      if (isLoading || !isCurrent()) return;
      if (canExecute?.call() == false) {
        Kurumi.showErrorToast(
          feedback,
          feedback.t.post.action.operation_failed,
        );
        return;
      }
      unawaited(
        _toggleFavorite(
          feedback,
          notifier,
          isFavorited: isFavorited,
          postId: post.id,
          profileId: profileId,
          isCurrent: canShowFeedback,
        ),
      );
    }

    if (popup && isLoading) return const SizedBox.shrink();
    return popup
        ? KurumiPopupMenuItem(
            title: Text(title),
            icon: Icon(isFavorited ? Icons.favorite : Icons.favorite_border),
            onTap: toggle,
          )
        : KurumiContextMenuTile(
            title: title,
            leading: Icon(
              isFavorited ? Icons.favorite : Icons.favorite_border,
            ),
            enabled: !isLoading,
            onTap: toggle,
          );
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    FavoritesNotifier notifier, {
    required bool isFavorited,
    required int postId,
    required String profileId,
    required bool Function() isCurrent,
  }) async {
    final result = await runFavoriteAction(
      context,
      () async => isFavorited
          ? await notifier.remove(postId, profileId: profileId)
          : switch (await notifier.add(postId, profileId: profileId)) {
              AddFavoriteStatus.success ||
              AddFavoriteStatus.alreadyExists => true,
              _ => false,
            },
      isCurrent: isCurrent,
    );

    if (!context.mounted ||
        !isCurrent() ||
        result == null ||
        result.cleanupInterrupted) {
      return;
    }
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
