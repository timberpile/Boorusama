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
    super.key,
  });

  final bool? isFaved;
  final bool isAuthorized;
  final Future<void> Function() addFavorite;
  final Future<void> Function() removeFavorite;

  @override
  Widget build(BuildContext context) {
    return KurumiTooltip(
      message: context.t.post.action.favorite,
      child: IconButton(
        splashRadius: 16,
        onPressed: isFaved != null
            ? () {
                if (!isAuthorized) {
                  Kurumi.showSimpleSnackBar(
                    context: context,
                    content: Text(
                      context.t.post.detail.login_required_notice,
                    ),
                    duration: KurumiDurations.shortToast,
                  );

                  return;
                }
                if (isFaved!) {
                  unawaited(runFavoriteAction(context, removeFavorite));
                } else {
                  unawaited(runFavoriteAction(context, addFavorite));
                }
              }
            : null,
        icon: (isFaved ?? false)
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
