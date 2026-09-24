// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/configs/config/types.dart';
import '../../../favgroups/routes.dart';
import '../../../favgroups/types.dart';
import '../pages/favorite_group_delete_confirmation_dialog.dart';
import '../widgets/modal_favorite_group_action.dart';

void showFavgroupEditSheet(
  BuildContext context,
  DanbooruFavoriteGroup favGroup,
  BooruConfig config,
) {
  Kurumi.showModalBottomSheet(
    context: context,
    routeSettings: const RouteSettings(name: 'favorite_groups_action'),
    builder: (_) => ModalFavoriteGroupAction(
      onDelete: () => showDialog(
        context: context,
        routeSettings: const RouteSettings(name: 'favorite_groups_delete'),
        builder: (context) => FavoriteGroupDeleteConfirmationDialog(
          favGroup: favGroup,
        ),
      ),
      onEdit: () => goToFavoriteGroupEditPage(context, favGroup, config),
    ),
  );
}
