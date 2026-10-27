import '../../../../configs/manage/providers.dart';
import '../types/post_action_snapshot.dart';
import 'post_actions.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

// Project imports:
import '../../../../bookmarks/widgets.dart';
import '../../../../configs/config/providers.dart';
import '../../../post/types.dart';
import 'post_grid_controller.dart';

class GeneralPostContextMenu extends ConsumerWidget {
  const GeneralPostContextMenu({
    super.key,
    required this.controller,
    required this.index,
    required this.child,
  });

  final PostGridController<Post> controller;
  final Widget child;

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booruConfig = ref.watchConfigAuth;
    final selectionModeController = SelectionMode.maybeOf(context);

    return ValueListenableBuilder(
      valueListenable: controller.itemsNotifier,
      builder: (context, posts, _) {
        if (index >= posts.length) return child;
        final post = posts[index];
        final snapshot = PostActionSnapshot([
          post,
        ], ref.watch(booruConfigProvider));
        return KurumiContextMenu(
          menuItemsBuilder: (context) => [
            PostContextMenuActions(
              snapshot: snapshot,
            ),
            BookmarkContextMenuSection(
              post: post,
              config: booruConfig,
            ),
            const KurumiContextMenuDivider(),
            if (selectionModeController case final controller?)
              KurumiContextMenuTile(
                title: context.t.generic.action.select,
                onTap: () {
                  controller.enable(
                    initialSelected: [index],
                  );
                },
              ),
          ],
          child: child,
        );
      },
    );
  }
}
