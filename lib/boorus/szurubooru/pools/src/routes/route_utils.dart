// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../core/configs/config/providers.dart';
import '../../../../../core/router.dart';
import '../../types.dart';

void goToSzurubooruPoolPage(WidgetRef ref) {
  ref.pushRoute('/szurubooru/pools');
}

void goToSzurubooruPoolSearchPage(WidgetRef ref) {
  ref.pushRoute('/szurubooru/pools/search');
}

void goToSzurubooruPoolDetailPage(WidgetRef ref, SzurubooruPool pool) {
  ref.pushRoute(
    Uri(
      pathSegments: [
        '',
        'szurubooru',
        'pools',
        '${pool.id}',
      ],
    ).toString(),
    extra: (pool: pool, config: ref.readConfig),
  );
}
