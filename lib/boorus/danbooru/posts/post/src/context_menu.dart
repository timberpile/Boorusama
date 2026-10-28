import '../../../configs/providers.dart';
import '../../../../../core/configs/config/types.dart';
import '../../../../../core/configs/manage/providers.dart';
import '../../../../../core/posts/listing/src/types/post_action_snapshot.dart';
import '../../../../../core/posts/listing/src/widgets/post_actions.dart';
import '../../../../../core/widgets/multi_select_button.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

// Project imports:
import '../../../../../core/bookmarks/widgets.dart';
import '../../../../../core/configs/config/providers.dart';
import '../../../favgroups/favgroups/routes.dart';
import '../../../versions/routes.dart';
import '../../listing/providers.dart';
import '../../../../../core/posts/post/types.dart';

class DanbooruPostContextMenu extends ConsumerWidget {
  const DanbooruPostContextMenu({
    super.key,
    required this.child,
    required this.post,
    required this.index,
  });

  final Widget child;
  final Post post;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booruConfig = ref.watchConfigAuth;
    final snapshot = PostActionSnapshot([post], ref.watch(booruConfigProvider));
    final selectionModeController = SelectionMode.maybeOf(context);

    return KurumiContextMenu(
      menuItemsBuilder: (context) => [
        PostContextMenuActions(
          snapshot: snapshot,
        ),
        BookmarkContextMenuSection(
          post: post,
          config: booruConfig,
        ),
        ...buildDanbooruSinglePostActions(context, ref: ref, post: post),
        if (selectionModeController case final controller?)
          KurumiContextMenuTile(
            title: context.t.generic.action.select,
            trailing: const Icon(Icons.checklist),
            onTap: () {
              controller.enable(
                initialSelected: [index],
              );
            },
          ),
      ],
      child: child,
    );
  }
}

List<Widget> buildDanbooruSinglePostActions(
  BuildContext context, {
  required WidgetRef ref,
  required Post post,
  bool popup = false,
  bool selection = false,
  bool includeFavoriteGroup = true,
}) {
  final profile = ref.watchConfig;
  final login = ref.watch(danbooruLoginDetailsProvider(profile.auth));
  final snapshot = PostActionSnapshot([post], ref.watch(booruConfigProvider));
  void execute(VoidCallback action) {
    if (!snapshot.accountsMatch(ref.read(booruConfigProvider))) {
      Kurumi.showErrorToast(context, context.t.post.action.operation_failed);
      return;
    }
    action();
  }

  Widget tile(String title, IconData icon, VoidCallback onTap) => selection
      ? MultiSelectButton(
          name: title,
          icon: Icon(icon),
          menuOnly: true,
          onPressed: () => execute(onTap),
        )
      : popup
      ? KurumiPopupMenuItem(
          title: Text(title),
          icon: Icon(icon),
          onTap: () => execute(onTap),
        )
      : KurumiContextMenuTile(
          title: title,
          trailing: Icon(icon),
          onTap: () => execute(onTap),
        );
  return [
    if (login.hasLogin() && includeFavoriteGroup)
      tile(
        context.t.post.action.add_to_favorite_group,
        Icons.folder_special,
        () => goToAddToFavoriteGroupSelectionPage(
          context,
          List.unmodifiable([post]),
          profile,
        ),
      ),
    tile(
      context.t.post.action.view_tag_history,
      Icons.history,
      () => goToPostVersionPage(ref, post),
    ),
    if (login.hasLogin())
      tile(
        context.t.generic.action.edit,
        Icons.edit_outlined,
        () => ref.danbooruEdit(post),
      ),
  ];
}
