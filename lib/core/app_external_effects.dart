// Package imports:
import 'package:kurumi/material.dart';

// Project imports:
import '../foundation/app_update/src/widgets/app_update_lifecycle_listener.dart';
import '../foundation/networking.dart';
import 'analytics/widgets.dart';
import 'backups/auto/trigger.dart';
import 'backups/export_import/import/import_recovery_gate.dart';
import 'backups/export_import/platform/received_export_listener.dart';
import 'debug/widgets.dart';
import 'search/following_topics/src/widgets/search_refresh_lifecycle.dart';
import 'themes/colors/dynamic_color.dart';

class BoorusamaExternalEffects extends StatelessWidget {
  const BoorusamaExternalEffects({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBridge(
      child: AnalyticsScope(
        child: AutoBackupAppLifecycle(
          child: ReceivedExportListener(
            child: NetworkListener(
              child: SearchRefreshLifecycle(
                child: DiagnosticContextScope(
                  child: AppUpdateLifecycleListener(
                    child: ImportRecoveryGate(child: child),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
