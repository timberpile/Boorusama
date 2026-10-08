// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../configs/auth/types.dart';
import '../../../../configs/config/providers.dart';
import '../providers/favorites_notifier.dart';
import 'favorite_action.dart';

extension FavX on WidgetRef {
  void toggleFavorite(int postId) {
    guardLogin(this, () async {
      final config = readConfigAuth;
      final notifier = read(favoritesProvider(config).notifier);
      final isFaved = read(favoriteProvider((config, postId)));
      if (isFaved) {
        final result = await runFavoriteAction(
          context,
          () => notifier.remove(postId),
        );
        if (result == null || result.cleanupInterrupted) return;
        if (context.mounted) {
          showSuccessSnackBar(
            context,
            'Removed from favorites',
          );
        }
      } else {
        final result = await runFavoriteAction(
          context,
          () => notifier.add(postId),
        );
        if (result == null || result.cleanupInterrupted) return;
        if (context.mounted) {
          showSuccessSnackBar(
            context,
            'Added to favorites',
          );
        }
      }
    });
  }
}
