// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

// Project imports:
import '../../../foundation/filesystem.dart';
import '../../../foundation/loggers.dart';
import '../../../foundation/platform.dart';
import '../../downloads/path/types.dart';
import '../export_import/export/export_flow_notifier.dart';
import '../sources/providers.dart';
import 'failure.dart';
import 'repo.dart';
import 'repo_android.dart';
import 'service.dart';

final autoBackupServiceProvider = Provider<AutoBackupService>((ref) {
  return AutoBackupService(
    exportService: ref.watch(exportServiceProvider),
    logger: ref.watch(loggerProvider),
    registry: ref.watch(backupRegistryProvider),
    repository: ref.watch(autoBackupRepositoryProvider),
  );
});

final autoBackupDefaultDirectoryPathProvider = FutureProvider<String?>((
  ref,
) async {
  if (isAndroid()) return null;

  final fs = ref.watch(appFileSystemProvider);
  final result = await tryGetDownloadDirectory(fs);
  final downloadsPath = switch (result) {
    DownloadDirectorySuccess(:final path) => path,
    DownloadDirectoryFailure(:final message) => throw Exception(
      message ?? 'Could not find downloads directory',
    ),
  };

  return p.join(downloadsPath, AutoBackupService.backupFolderName);
});

final autoBackupDirectoryDisplayPathProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, location) {
      return AutoBackupRepositoryAndroid.directoryDisplayPath(location);
    });

// Retain automatic failures when the transient backup operation provider closes.
final autoBackupFailureProvider =
    NotifierProvider<AutoBackupFailureNotifier, AutoBackupFailure?>(
      AutoBackupFailureNotifier.new,
    );

class AutoBackupFailureNotifier extends Notifier<AutoBackupFailure?> {
  @override
  AutoBackupFailure? build() => null;

  void clear() => state = null;

  AutoBackupFailure report(Object error) {
    final failure = AutoBackupFailure.fromError(error);
    state = failure;
    return failure;
  }
}
