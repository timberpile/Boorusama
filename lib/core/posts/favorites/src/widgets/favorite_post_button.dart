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
    this.menuItem = false,
    super.key,
  });

  final bool menuItem;
  final bool? isFaved;
  final bool isAuthorized;
  final Future<void> Function() addFavorite;
  final Future<void> Function() removeFavorite;

  FavoritePostButton asMenuItem() => FavoritePostButton(
    isFaved: isFaved,
    isAuthorized: isAuthorized,
    addFavorite: addFavorite,
    removeFavorite: removeFavorite,
    menuItem: true,
  );

  @override
  Widget build(BuildContext context) {
    // Menu rows are disposed after activation; keep async feedback on the route.
    final feedback = menuItem
        ? Scaffold.maybeOf(context)?.context ?? Navigator.of(context).context
        : context;
    final onPressed = isFaved == null
        ? null
        : () {
            if (!isAuthorized) {
              Kurumi.showSimpleSnackBar(
                context: feedback,
                content: Text(context.t.post.detail.login_required_notice),
                duration: KurumiDurations.shortToast,
              );
              return;
            }
            unawaited(
              runFavoriteAction(
                feedback,
                isFaved! ? removeFavorite : addFavorite,
              ),
            );
          };
    final icon = (isFaved ?? false)
        ? Icon(
            Symbols.favorite,
            fill: 1,
            color: context.colors.upvoteColor,
            size: 20,
          )
        : const Icon(Symbols.favorite, size: 20);
    if (menuItem) {
      return KurumiPopupMenuItem(
        title: Text(
          (isFaved ?? false)
              ? context.t.post.action.unfavorite
              : context.t.post.action.favorite,
        ),
        icon: icon,
        onTap: onPressed,
      );
    }
    return KurumiTooltip(
      message: context.t.post.action.favorite,
      child: IconButton(
        splashRadius: 16,
        onPressed: onPressed,
        icon: icon,
      ),
    );
  }
}
