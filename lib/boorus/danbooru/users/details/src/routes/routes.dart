// Package imports:
import 'package:kurumi/cupertino.dart';

// Project imports:
import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/configs/manage/widgets.dart';
import '../../../../../../core/router.dart';
import '../pages/danbooru_profile_page.dart';
import '../pages/danbooru_user_details_page.dart';
import '../types/user_details.dart';

final danbooruProfileRoutes = GoRoute(
  path: '/danbooru/profile',
  name: 'profile',
  pageBuilder: (context, state) => CupertinoPage(
    key: state.pageKey,
    name: state.name,
    child: switch (state.extra) {
      final BooruConfig config => CurrentBooruConfigScope(
        config: config,
        child: const DanbooruProfilePage(),
      ),
      _ => const DanbooruProfilePage(),
    },
  ),
);

final danbooruUserDetailsRoutes = GoRoute(
  path: '/danbooru/users/:id',
  name: 'user_details',
  pageBuilder: (context, state) => CupertinoPage(
    key: state.pageKey,
    name: state.name,
    child: Builder(
      builder: (context) {
        final details = UserDetails.fromParams(
          queryParameters: state.uri.queryParameters,
          pathParameters: state.pathParameters,
        );

        final page = details == null
            ? const InvalidPage(message: 'Invalid user')
            : DanbooruUserDetailsPage(details: details);

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
