// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:path/path.dart' as p;

// Project imports:
import '../filesystem.dart';
import '../picker.dart';
import '../plugin_app_file_picker.dart';
import 'crash_report_writer.dart';

/// Bootstrap can fail before the application's provider overrides exist.
/// Keep diagnostic saving independent from that failed runtime.
final class FileSystemCrashReportWriter implements CrashReportWriter {
  const FileSystemCrashReportWriter({
    this.picker = const PluginAppFilePicker(),
    this.fileSystem = const IoFileSystem(),
  });

  final AppFilePicker picker;
  final AppFileSystem fileSystem;

  @override
  Future<void> save(BuildContext context, String data) async {
    try {
      final directory = await picker.pickDirectory();
      if (directory == null) return;
      await fileSystem.writeString(
        p.join(directory, 'boorusama_crash.txt'),
        data,
        flush: true,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Crash report saved'),
          duration: KurumiDurations.shortToast,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      // The failsafe tree has a Scaffold, but does not require an OKToast host
      // or a successfully initialized localization/provider scope.
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not save the crash report'),
          duration: KurumiDurations.shortToast,
        ),
      );
    }
  }
}
