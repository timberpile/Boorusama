// Project imports:
import '../../../../../../core/configs/manage/widgets.dart';
import '../../../../../../core/router.dart';
import '../tag_edit_page.dart';
import 'route_utils.dart';

final danbooruTagEditRoutes = GoRoute(
  path: '/internal/danbooru/posts/:id/editor',
  name: 'tag_edit',
  pageBuilder: largeScreenCompatPageBuilderWithExtra<DanbooruTagEditRouteData>(
    errorScreenMessage: 'Invalid post',
    fullScreen: true,
    pageBuilder: (context, state, data) => CurrentBooruConfigScope(
      config: data.config,
      child: DanbooruTagEditPage(post: data.post),
    ),
  ),
);
