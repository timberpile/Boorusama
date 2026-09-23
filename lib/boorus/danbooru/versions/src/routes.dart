// Project imports:
import '../../../../core/configs/manage/widgets.dart';
import '../../../../core/router.dart';
import 'danbooru_post_versions_page.dart';
import 'routes/route_utils.dart';

final danbooruPostVersionRoutes = GoRoute(
  path: '/danbooru/post_versions',
  name: 'post_versions',
  pageBuilder:
      largeScreenCompatPageBuilderWithExtra<DanbooruPostVersionRouteData>(
        errorScreenMessage: 'Invalid post',
        pageBuilder: (context, state, data) => CurrentBooruConfigScope(
          config: data.config,
          child: DanbooruPostVersionsPage.post(
            post: data.post,
          ),
        ),
      ),
);
