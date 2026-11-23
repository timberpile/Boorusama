import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/configs/manage/widgets.dart';
import '../../../../../../core/router.dart';
import '../../../pool/types.dart';
import '../pool_detail_page.dart';

final danbooruPoolDetailsRoutes = GoRoute(
  path: ':id',
  name: 'pool_details',
  pageBuilder: largeScreenAwarePageBuilder(
    useDialog: true,
    builder: (context, state) => switch (state.extra) {
      (pool: final DanbooruPool pool, config: final BooruConfig config) =>
        CurrentBooruConfigScope(
          config: config,
          child: PoolDetailPage(pool: pool),
        ),
      final DanbooruPool pool => PoolDetailPage(pool: pool),
      _ => const InvalidPage(message: 'Invalid pool'),
    },
  ),
);
