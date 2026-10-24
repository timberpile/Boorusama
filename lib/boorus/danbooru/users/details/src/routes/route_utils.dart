// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../../core/configs/config/providers.dart';
import '../../../../../../core/router.dart';
import '../types/user_details.dart';

void goToUserDetailsPage(
  WidgetRef ref, {
  required UserDetails details,
}) {
  final uid = details.id;
  ref.pushRoute(
    Uri(
      pathSegments: [
        '',
        'danbooru',
        'users',
        '$uid',
      ],
      queryParameters: {
        ...details.toQueryParams(),
      },
    ).toString(),
    extra: ref.readConfig,
  );
}

void goToProfilePage(WidgetRef ref) {
  ref.pushRoute(
    Uri(
      pathSegments: [
        '',
        'danbooru',
        'profile',
      ],
    ).toString(),
  );
}
