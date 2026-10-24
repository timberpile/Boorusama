// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../../core/router.dart';

void goToArtistSearchPage(WidgetRef ref) {
  ref.pushRoute(
    Uri(
      pathSegments: [
        '',
        'danbooru',
        'artists',
      ],
    ).toString(),
  );
}
