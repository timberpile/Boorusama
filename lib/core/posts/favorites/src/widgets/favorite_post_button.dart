// Dart imports:
import 'dart:async';

// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../themes/theme/types.dart';
import 'favorite_action.dart';

class FavoritePostButton extends StatelessWidget {
  const FavoritePostButton({
    required this.isFaved,
    required this.isAuthorized,
    required this.addFavorite,
    required this.removeFavorite,
    this.isCurrent,
    super.key,
  });

  final bool? isFaved;
  final bool isAuthorized;
  final Future<void> Function() addFavorite;
  final Future<void> Function() removeFavorite;
  final bool Function()? isCurrent;

  VoidCallback? action(BuildContext context) => isFaved == null
      ? null
      : () {
          if (!context.mounted || isCurrent?.call() == false) return;
          if (!isAuthorized) {
            Kurumi.showSimpleSnackBar(
              context: context,
              content: Text(context.t.post.detail.login_required_notice),
              duration: KurumiDurations.shortToast,
            );
            return;
          }
          unawaited(
            runFavoriteAction(
              context,
              isFaved! ? removeFavorite : addFavorite,
              isCurrent: isCurrent,
            ),
          );
        };

  @override
  Widget build(BuildContext context) {
    final isFavorited = isFaved ?? false;
    return KurumiTooltip(
      message: isFavorited
          ? context.t.post.action.unfavorite
          : context.t.post.action.favorite,
      child: IconButton(
        splashRadius: 16,
        onPressed: action(context),
        icon: isFavorited
            ? Icon(
                Symbols.favorite,
                fill: 1,
                color: context.colors.upvoteColor,
                size: 20,
              )
            : const Icon(
                Symbols.favorite,
                size: 20,
              ),
      ),
    );
  }
}
