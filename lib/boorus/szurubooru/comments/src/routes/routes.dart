// Package imports:
import 'package:kurumi/cupertino.dart';

// Project imports:
import '../../../../../core/configs/config/types.dart';
import '../../../../../core/configs/manage/widgets.dart';
import '../../../../../core/router.dart';
import '../pages/comment_create_page.dart';
import '../pages/comment_update_page.dart';

final szurubooruCommentEditorRoutes = GoRoute(
  path: '/internal/szurubooru/posts/:id/comments/editor',
  name: 'szurubooru_comments/editor',
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
          (null, _, _) => const InvalidPage(
            message: 'Invalid post ID',
          ),
          (final int postId, null, _) => SzurubooruCommentCreatePage(
            postId: postId,
            initialContent: text,
          ),
          (_, _, null) => const InvalidPage(message: 'Invalid comment'),
          (final int postId, final int commentId, final String text) =>
            SzurubooruCommentUpdatePage(
              postId: postId,
              commentId: commentId,
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
