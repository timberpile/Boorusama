// Package imports:
import 'package:kurumi/cupertino.dart';

// Project imports:
import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/configs/manage/widgets.dart';
import '../../../../../../core/router.dart';
import '../pages/danbooru_favoriter_list_page.dart';
import '../pages/danbooru_voter_list_page.dart';

final danbooruFavoriterListRoutes = GoRoute(
  path: '/internal/danbooru/posts/:id/favoriter',
  name: 'favoriter_list',
  pageBuilder: (context, state) => CupertinoPage(
    key: state.pageKey,
    name: state.name,
    child: Builder(
      builder: (context) {
        final postId = int.tryParse(state.pathParameters['id'] ?? '');

        final page = postId == null
            ? const InvalidPage(message: 'Invalid post ID')
            : DanbooruFavoriterListPage(postId: postId);

        return _scopePage(state.extra, page);
      },
    ),
  ),
);

final danbooruVoterListRoutes = GoRoute(
  path: '/internal/danbooru/posts/:id/voter',
  name: 'voter_list',
  pageBuilder: (context, state) => CupertinoPage(
    key: state.pageKey,
    name: state.name,
    child: Builder(
      builder: (context) {
        final postId = int.tryParse(state.pathParameters['id'] ?? '');

        final page = postId == null
            ? const InvalidPage(message: 'Invalid post ID')
            : DanbooruVoterListPage(postId: postId);

        return _scopePage(state.extra, page);
      },
    ),
  ),
);

Widget _scopePage(Object? extra, Widget page) => switch (extra) {
  final BooruConfig config => CurrentBooruConfigScope(
    config: config,
    child: page,
  ),
  _ => page,
};
