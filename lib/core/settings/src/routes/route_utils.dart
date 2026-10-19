// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../router.dart';

void goToSettingsPage(
  WidgetRef ref, {
  String? scrollTo,
}) {
  ref.pushRoute(
    Uri(
      path: '/settings',
      queryParameters: {
        'scrollTo': ?scrollTo,
      },
    ).toString(),
  );
}

Future<void> openImageViewerSettingsPage(WidgetRef ref) {
  return ref.pushRoute(
    Uri(
      path: '/settings',
      queryParameters: {
        'initial': 'viewer',
      },
    ).toString(),
  );
}

Future<void> openDownloadSettingsPage(WidgetRef ref) {
  return ref.pushRoute(
    Uri(
      path: '/settings',
      queryParameters: {
        'initial': 'download',
      },
    ).toString(),
  );
}

Future<void> openAppearancePage(WidgetRef ref) {
  return ref.pushRoute(
    Uri(
      path: '/settings',
      queryParameters: {
        'initial': 'appearance',
      },
    ).toString(),
  );
}

Future<void> openDataAndStoragePage(WidgetRef ref) {
  return ref.pushRoute(
    Uri(
      path: '/settings',
      queryParameters: {
        'initial': 'data_and_storage',
      },
    ).toString(),
  );
}

Future<void> openTopicUpdatesSettingsPage(WidgetRef ref) {
  return ref.pushRoute(
    Uri(
      path: '/settings',
      queryParameters: {'initial': 'topic_updates'},
    ).toString(),
  );
}

/// Each explicit recovery request also opens the category in retained Settings.
Future<void> openProfilesSettingsPage(WidgetRef ref) => ref.pushRoute(
  Uri(path: '/settings', queryParameters: {'initial': 'profiles'}).toString(),
  extra: Object(),
);
