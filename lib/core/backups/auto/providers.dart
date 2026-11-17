// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

// Project imports:
import '../../../foundation/filesystem.dart';
import '../../../foundation/loggers.dart';
import '../../../foundation/platform.dart';
import '../../downloads/path/types.dart';
import '../../settings/providers.dart';
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
    registry: ref.watch(exportSourceCatalogProvider),
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

  var _revision = 0;
  int get revision => _revision;
  int invalidateOlderOperations() => ++_revision;

  void clear() {
    _revision++;
    state = null;
  }

  AutoBackupFailure report(Object error, {int? revision}) {
    final failure = AutoBackupFailure.fromError(error);
    if (revision == null || revision == _revision) {
      _revision++;
      state = failure;
    }
    return failure;
  }
}

final autoBackupDirectoryRecoveryProvider = Provider(
  (ref) => AutoBackupDirectoryRecovery(ref),
  dependencies: [
    settingsNotifierProvider,
    settingsProvider,
    autoBackupRepositoryProvider,
    autoBackupFailureProvider,
  ],
);

class AutoBackupDirectoryRecovery {
  AutoBackupDirectoryRecovery(this.ref) {
    ref.onDispose(() => _active = false);
  }
  final Ref ref;
  var _active = true;
  var _request = 0;

  Future<bool> selectDirectory(String location) async {
    final request = ++_request;
    final failure = ref.read(autoBackupFailureProvider.notifier);
    final previous = ref.read(autoBackupFailureProvider);
    final revision = failure.invalidateOlderOperations();
    final saved = await ref
        .read(settingsNotifierProvider.notifier)
        .updateWith(
          (settings) => settings.copyWith(
            autoBackup: settings.autoBackup.copyWith(
              userSelectedPath: () => location,
            ),
          ),
        );
    bool current() =>
        _active &&
        request == _request &&
        failure.revision == revision &&
        ref.read(settingsProvider).autoBackup.userSelectedPath == location;
    if (!saved || !current()) return false;
    try {
      await ref
          .read(autoBackupRepositoryProvider)
          .getBackupDirectoryPath(location);
      if (!current()) return false;
      final diagnostic = ref.read(autoBackupFailureProvider);
      if (identical(diagnostic, previous) &&
          (diagnostic?.requiresFolderAccess ?? false)) {
        failure.clear();
      }
      return true;
    } catch (error) {
      if (current()) {
        final diagnostic = ref.read(autoBackupFailureProvider);
        if (diagnostic == null || diagnostic.requiresFolderAccess) {
          failure.report(error, revision: revision);
        }
      }
      return false;
    }
  }
}
