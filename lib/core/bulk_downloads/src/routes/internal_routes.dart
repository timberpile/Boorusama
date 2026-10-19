// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../downloads/downloader/providers.dart';
import '../../../router.dart';
import '../../../navigation/operation_source_picker.dart';
import '../../../configs/manage/widgets.dart';
import '../../../configs/config/types.dart';
import '../pages/create_download_options_sheet.dart';

Future<void> goToBulkDownloadCompletedPage(WidgetRef ref) async {
  await ref.pushRoute(
    Uri(
      pathSegments: [
        '',
        'bulk_downloads',
        'completed',
      ],
    ).toString(),
  );
}

Future<void> goToBulkDownloadSavedTasksPage(WidgetRef ref) async {
  await ref.pushRoute(
    Uri(
      pathSegments: [
        '',
        'bulk_downloads',
        'saved',
      ],
    ).toString(),
  );
}

Future<void> goToNewBulkDownloadTaskPage(
  WidgetRef ref,
  BuildContext context, {
  required List<String>? initialValue,
  bool showStartNotification = true,
}) async {
  final source = await chooseOperationSource(ref);
  if (!context.mounted || source == null) return;
  final config = source.auth;

  if (!config.booruType.canDownloadMultipleFiles) {
    showBulkDownloadUnsupportErrorToast(context);
    return;
  }

  Kurumi.showAppModalBottomSheet(
    context: context,
    routeSettings: const RouteSettings(name: 'bulk_download_create'),
    builder: (_) => CurrentBooruConfigScope(
      config: source,
      child: CreateDownloadOptionsSheet(
        initialValue: initialValue,
        showStartNotification: showStartNotification,
      ),
    ),
  );
}
