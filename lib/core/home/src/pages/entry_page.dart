// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../foundation/permissions.dart';
import '../../../../foundation/platform.dart';
import '../../../bulk_downloads/providers.dart';
import '../../../changelogs/routes.dart';
import '../../../premiums/widgets.dart';

class EntryPage extends ConsumerStatefulWidget {
  const EntryPage({
    super.key,
    required this.navigationChild,
  });

  final Widget navigationChild;

  @override
  ConsumerState<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends ConsumerState<EntryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showChangelogDialogIfNeeded(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(appPlatformProvider).isMobile) {
      ref.listen(
        deviceStoragePermissionProvider,
        (previous, state) {
          final value = state.value;
          final isPermenantlyDenied =
              value?.storagePermission == PermissionStatus.permanentlyDenied;
          final isNotRead = !(value?.isNotificationRead ?? false);

          if (isPermenantlyDenied && isNotRead) {
            Kurumi.showSimpleSnackBar(
              context: context,
              action: SnackBarAction(
                label: context.t.settings.open_app_settings,
                onPressed: openAppSettings,
              ),
              behavior: SnackBarBehavior.fixed,
              content: Text(context.t.download.storage_permission_explanation),
            );
            ref
                .read(deviceStoragePermissionProvider.notifier)
                .markNotificationAsRead();
          }
        },
      );
    }

    return _NotificationScope(child: widget.navigationChild);
  }
}

class _NotificationScope extends StatelessWidget {
  const _NotificationScope({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BulkDownloadErrorScope(
      child: LayoutPreviewNotificationScope(
        child: child,
      ),
    );
  }
}
