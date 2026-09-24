// Package imports:
import 'package:kurumi/cupertino.dart';

// Project imports:
import '../../../../../core/configs/config/types.dart';
import '../../../../../core/configs/manage/widgets.dart';
import '../../../../../core/router.dart';
import '../../types.dart';
import '../pool_detail_page.dart';
import '../pool_page.dart';
import '../pool_search_page.dart';

final szurubooruPoolRoutes = GoRoute(
  path: '/szurubooru/pools',
  name: 'szurubooru_pools',
  pageBuilder: (context, state) => CupertinoPage(
    key: state.pageKey,
    name: state.name,
    child: const SzurubooruPoolPage(),
  ),
  routes: [
    GoRoute(
      path: 'search',
      name: 'szurubooru_pool_search',
      builder: (context, state) => const SzurubooruPoolSearchPage(),
    ),
    GoRoute(
      path: ':id',
      name: 'szurubooru_pool_details',
      pageBuilder: (context, state) {
        final poolId = int.tryParse(state.pathParameters['id'] ?? '');

        if (poolId == null) {
          return CupertinoPage(
            key: state.pageKey,
            name: state.name,
            child: const InvalidPage(message: 'Invalid pool'),
          );
        }

        return largeScreenAwarePageBuilder(
          useDialog: true,
          builder: (context, state) {
            final page = SzurubooruPoolDetailPage(
              poolId: poolId,
              initialPool: switch (state.extra) {
                (
                  pool: final SzurubooruPool pool,
                  config: final BooruConfig _,
                ) =>
                  pool,
                final SzurubooruPool pool => pool,
                _ => null,
              },
            );

            return switch (state.extra) {
              (
                pool: final SzurubooruPool _,
                config: final BooruConfig config,
              ) =>
                CurrentBooruConfigScope(config: config, child: page),
              _ => page,
            };
          },
        )(context, state);
      },
    ),
  ],
);
