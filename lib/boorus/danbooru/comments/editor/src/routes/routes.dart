// Package imports:
import 'package:kurumi/cupertino.dart';

// Project imports:
import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/configs/manage/widgets.dart';
import '../../../../../../core/router.dart';
import '../pages/comment_create_page.dart';
import '../pages/comment_update_page.dart';

final danbooruCommentEditorRoutes = GoRoute(
  path: '/internal/danbooru/posts/:id/comments/editor',
  name: 'comments/editor',
  pageBuilder: (context, state) => CupertinoPage(
    key: state.pageKey,
    name: state.name,
    child: Builder(
      builder: (context) {
        final postId = int.tryParse(state.pathParameters['id'] ?? '');
        final text = state.uri.queryParameters['text'];
        final commentId = int.tryParse(
          state.uri.queryParameters['comment_id'] ?? '',
        );

        final page = switch ((postId, commentId, text)) {
          (null, _, _) => const InvalidPage(message: 'Invalid post ID'),
          (final postId?, final commentId?, final text?) => CommentUpdatePage(
            postId: postId,
            commentId: commentId,
            initialContent: text,
          ),
          (final postId?, _, _) => CommentCreatePage(
            postId: postId,
            initialContent: text,
          ),
        };

        return switch (state.extra) {
          final BooruConfig config => CurrentBooruConfigScope(
            config: config,
            child: page,
          ),
          _ => page,
        };
      },
    ),
  ),
);
