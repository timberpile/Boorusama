// Project imports:
import '../../../../../../core/router.dart';
import '../../../../../../core/posts/post/types.dart';
import '../tag_edit_page.dart';

final danbooruTagEditRoutes = GoRoute(
  path: '/internal/danbooru/posts/:id/editor',
  name: 'tag_edit',
  pageBuilder: largeScreenCompatPageBuilderWithExtra<Post>(
    errorScreenMessage: 'Invalid post',
    fullScreen: true,
    pageBuilder: (context, state, post) => DanbooruTagEditPage(
      post: post,
    ),
  ),
);
