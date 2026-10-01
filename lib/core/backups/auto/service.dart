// Package imports:
import 'package:path/path.dart' as p;

// Project imports:
import '../../../foundation/loggers.dart';
import '../export_import/export/export_service.dart';
import '../export_import/models/export_selection.dart';
import '../export_import/models/package_manifest.dart';
import '../types/backup_registry.dart';
import '../zip/types.dart';
import 'types.dart';

class AutoBackupService {
  const AutoBackupService({
    required this.exportService,
    required this.logger,
    required this.registry,
    required this.repository,
  });

  final ExportService exportService;
  final Logger logger;
  final BackupRegistry registry;
  final AutoBackupRepository repository;

  static const manifestFileName = 'auto_backup_manifest.json';
  static const backupFolderName = 'boorusama_auto_backups';

  Future<BulkExportResult> performBackup(
    AutoBackupSettings settings, {
    void Function(double progress)? onProgress,
  }) async {
    logger.verbose('AutoBackup', 'Starting auto backup');

    final backupDirPath = await _getBackupDirectoryPath(settings);
    final selection = ExportSelection.full(registry);
    final sourceIds = selection.sourceIds.toList();
    if (sourceIds.isEmpty) {
      throw StateError('No export sources are available');
    }

    onProgress?.call(0);
    final filePath = await exportService.createPackage(
      ExportRequest(
        selection: selection,
        outputPath: p.join(
          backupDirPath,
          'boorusama_backup_${DateTime.now().toUtc().microsecondsSinceEpoch}'
          '$kExportPackageExtension',
        ),
      ),
    );
    onProgress?.call(1);

    await _updateManifest(backupDirPath, filePath);
    await _cleanupOldBackups(backupDirPath, settings.maxBackups);

    logger.verbose(
      'AutoBackup',
      'Auto backup completed: ${sourceIds.length} sources exported',
    );

    return BulkExportResult(
      success: true,
      exported: sourceIds,
      failed: const [],
      skipped: const [],
      filePath: filePath,
    );
  }

  Future<String> _getBackupDirectoryPath(AutoBackupSettings settings) {
    return repository.getBackupDirectoryPath(settings.userSelectedPath);
  }

  Future<AutoBackupManifest> _loadManifest(String backupDirPath) async {
    try {
      return await repository.loadManifest(backupDirPath);
    } catch (e) {
      logger.warn('AutoBackup', 'Failed to load manifest, creating new: $e');
      return const AutoBackupManifest(backups: []);
    }
  }

  Future<void> _saveManifest(
    String backupDirPath,
    AutoBackupManifest manifest,
  ) async {
    await repository.saveManifest(backupDirPath, manifest);
  }

  Future<void> _updateManifest(
    String backupDirPath,
    String newBackupPath,
  ) async {
    final manifest = await _loadManifest(backupDirPath);
    final fileName = p.basename(newBackupPath);
    final fileSize = await repository.getFileSize(newBackupPath);

    final newEntry = AutoBackupEntry(
      fileName: fileName,
      createdAt: DateTime.now(),
      fileSize: fileSize,
    );

    final updatedManifest = manifest.copyWith(
      backups: [...manifest.backups, newEntry],
    );

    await _saveManifest(backupDirPath, updatedManifest);
  }

  Future<void> _reconcileManifest(String backupDirPath) async {
    final manifest = await _loadManifest(backupDirPath);
    final actualFiles = repository.listBackupFiles(backupDirPath).toSet();

    // Remove missing files from manifest
    final validBackups = manifest.backups
        .where((backup) => actualFiles.contains(backup.fileName))
        .toList();

    if (validBackups.length != manifest.backups.length) {
      final removedCount = manifest.backups.length - validBackups.length;
      logger.verbose(
        'AutoBackup',
        'Reconciled manifest: removed $removedCount missing entries',
      );
      await _saveManifest(
        backupDirPath,
        AutoBackupManifest(backups: validBackups),
      );
    }
  }

  Future<void> _cleanupOldBackups(String backupDirPath, int maxBackups) async {
    try {
      await _reconcileManifest(backupDirPath);
      final manifest = await _loadManifest(backupDirPath);

      if (manifest.backups.length <= maxBackups) return;

      // Sort by creation time (oldest first)
      final sortedBackups = [...manifest.backups]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final backupsToDelete = sortedBackups.take(
        sortedBackups.length - maxBackups,
      );
      final remainingBackups = sortedBackups
          .skip(sortedBackups.length - maxBackups)
          .toList();

      // Delete old backup files
      for (final backup in backupsToDelete) {
        final filePath = p.join(backupDirPath, backup.fileName);
        if (repository.fileExists(filePath)) {
          await repository.deleteFile(filePath);
          logger.verbose(
            'AutoBackup',
            'Deleted old backup: ${backup.fileName}',
          );
        }
      }

      // Update manifest with remaining backups
      final updatedManifest = manifest.copyWith(backups: remainingBackups);
      await _saveManifest(backupDirPath, updatedManifest);
    } catch (e) {
      logger.warn('AutoBackup', 'Failed to cleanup old backups: $e');
    }
  }
}
