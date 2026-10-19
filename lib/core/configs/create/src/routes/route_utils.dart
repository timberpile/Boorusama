// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../router.dart';
import '../../../config/types.dart';
import '../types/edit_booru_config_id.dart';

void goToUpdateBooruConfigPage(
  WidgetRef ref, {
  required BooruConfig config,
  String? initialTab,
}) {
  ref.pushRoute(
    Uri(
      path: '/boorus/${config.id}/update',
      queryParameters: {
        'q': ?initialTab,
      },
    ).toString(),
  );
}

void goToAddBooruConfigPage(
  WidgetRef ref, {
  EditBooruConfigId? initialConfigId,
}) {
  ref.pushRoute(
    Uri(
      path: '/boorus/add',
      queryParameters: {
        ...?initialConfigId?.toQueryParameters(),
      },
    ).toString(),
  );
}
