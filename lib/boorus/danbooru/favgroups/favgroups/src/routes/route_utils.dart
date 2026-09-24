// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/configs/manage/widgets.dart';
import '../../../../../../core/posts/post/types.dart';
import '../pages/add_to_favorite_group_page.dart';
import '../pages/create_favorite_group_sheet.dart';
import '../types/danbooru_favorite_group.dart';

Future<bool?> goToAddToFavoriteGroupSelectionPage(
  BuildContext context,
  List<Post> posts,
  BooruConfig config,
) {
  return Kurumi.showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    routeSettings: const RouteSettings(
      name: 'add_to_favorite_group',
    ),
    useSafeArea: true,
    builder: (_) => CurrentBooruConfigScope(
      config: config,
      child: AddToFavoriteGroupPage(
        posts: posts,
      ),
    ),
  );
}

Future<Object?> goToFavoriteGroupCreatePage(
  BuildContext context,
  BooruConfig config, {
  bool enableManualPostInput = true,
}) {
  return Kurumi.showAppModalBottomSheet(
    context: context,
    resizeToAvoidBottomInset: true,
    routeSettings: const RouteSettings(
      name: 'favorite_group_create',
    ),
    builder: (_) => CurrentBooruConfigScope(
      config: config,
      child: EditFavoriteGroupSheet(
        title: context.t.favorite_groups.create_group,
        enableManualDataInput: enableManualPostInput,
      ),
    ),
  );
}

Future<Object?> goToFavoriteGroupEditPage(
  BuildContext context,
  DanbooruFavoriteGroup group,
  BooruConfig config,
) {
  return Kurumi.showAppModalBottomSheet(
    context: context,
    resizeToAvoidBottomInset: true,
    routeSettings: const RouteSettings(
      name: 'favorite_group_edit',
    ),
    builder: (_) => CurrentBooruConfigScope(
      config: config,
      child: EditFavoriteGroupSheet(
        initialData: group,
        title: context.t.favorite_groups.edit_group,
      ),
    ),
  );
}
