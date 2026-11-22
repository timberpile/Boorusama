// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';

// Project imports:
import '../../../../configs/auth/types.dart';
import '../../../../configs/config/providers.dart';
import '../providers/favorites_notifier.dart';
import '../types/types.dart';
import 'favorite_action.dart';

extension FavX on WidgetRef {
  void toggleFavorite(int postId) {
    final config = readConfigAuth;
    final profileId = readConfig.id;
    final feedback = context;
    bool isCurrent() =>
        feedback.mounted &&
        readConfigAuth == config &&
        readConfig.id == profileId;

    if (read(favoriteNeedsWebsiteLoginProvider(config))) {
      showFavoriteActionFailure(
        feedback,
        FavoriteActionFailure.websiteLoginRequired,
      );
      return;
    }
    guardLogin(this, () async {
      final notifier = read(favoritesProvider(config).notifier);
      final isFaved = read(favoriteProvider((config, postId)));
      final result = await runFavoriteAction(
        feedback,
        () => notifier.setFavorite(
          postId,
          favorited: !isFaved,
          profileId: profileId,
        ),
        isCurrent: isCurrent,
      );
      if (result == null ||
          result.cleanupInterrupted ||
          !feedback.mounted ||
          !isCurrent()) {
        return;
      }
      if (!result.value) {
        showFavoriteActionFailure(feedback, FavoriteActionFailure.unconfirmed);
        return;
      }
      final update = feedback.t.favorites.update;
      showSuccessSnackBar(feedback, isFaved ? update.removed : update.added);
    });
  }
}
