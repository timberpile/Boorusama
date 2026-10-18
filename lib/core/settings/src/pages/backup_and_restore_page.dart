import 'package:kurumi/material.dart';

// Project imports:
import '../../../backups/export_import/export_import_page.dart';

class BackupAndRestorePage extends StatelessWidget {
  const BackupAndRestorePage({
    super.key,
    this.includeAutomaticExports = true,
    this.showAppBar = true,
  });

  final bool includeAutomaticExports;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) => ExportImportPage(
    includeAutomaticExports: includeAutomaticExports,
    showAppBar: showAppBar,
  );
}
