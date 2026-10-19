// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../../core/router.dart';

void goToUserFeedbackPage(WidgetRef ref, int userId) {
  ref.pushRoute(
    Uri(
      pathSegments: [
        '',
        'danbooru',
        'user_feedbacks',
      ],
      queryParameters: {
        'search[user_id]': userId.toString(),
      },
    ).toString(),
  );
}
