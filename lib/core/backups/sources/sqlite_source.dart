// Dart imports:
import 'dart:io';

// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kurumi/material.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:sqlite3/sqlite3.dart';

// Project imports:
import '../../../foundation/filesystem.dart';
import '../../../foundation/data_mutation_coordinator.dart';
import '../preparation/version_checking.dart';
import '../types/backup_data_source.dart';
import '../utils/backup_utils.dart';
import '../utils/db_transfer.dart';

abstract class SqliteBackupSource implements BackupDataSource {
  SqliteBackupSource({
    required this.id,
    required this.priority,
    required this.ref,
    required this.dbPathGetter,
    required this.dbFileName,
    required this.onImportComplete,
    required this.initializeDatabase,
  });

  @override
  final String id;

  @override
  final int priority;

  final Ref ref;
  final Future<String> Function() dbPathGetter;
  final String dbFileName;
  final void Function() onImportComplete;
  final void Function(Database db) initializeDatabase;

  Future<String> ensureInitializedForExport() => ref
      .read(dataMutationCoordinatorProvider)
      .runExclusive(_ensureInitializedForExport);

  Future<void> captureDatabase(String outputPath) =>
      ref.read(dataMutationCoordinatorProvider).runExclusive(() async {
        final dbPath = await _ensureInitializedForExport();
        await ref.read(appFileSystemProvider).copyFile(dbPath, outputPath);
      });

  Future<String> _ensureInitializedForExport() async {
    final dbPath = await dbPathGetter();
    final fs = ref.read(appFileSystemProvider);
    var isMissing = false;
    try {
      if (await fs.fileSize(dbPath) == 0) {
        throw StateError('Invalid database source: $id');
      }
    } on FileSystemException catch (error) {
      // Unlike exists/type probes, length preserves lookup errors. Only an
      // absent file (or absent parent on Windows) permits first-use creation.
      final code = error.osError?.errorCode;
      if (code != 2 && !(Platform.isWindows && code == 3)) rethrow;
      isMissing = true;
    }
    Directory? initializationDirectory;
    try {
      if (isMissing) {
        await fs.createDirectory(p.dirname(dbPath), recursive: true);
        initializationDirectory = await Directory(
          p.dirname(dbPath),
        ).createTemp('.${dbFileName}_initialization_');
      }
      final initializationPath = initializationDirectory == null
          ? dbPath
          : p.join(initializationDirectory.path, dbFileName);
      final db = sqlite3.open(
        initializationPath,
        mode: isMissing ? OpenMode.readWriteCreate : OpenMode.readOnly,
      );
      try {
        // Repository providers can fall back to empty implementations on failure;
        // export must propagate failures and use the real first-use schema.
        if (isMissing) initializeDatabase(db);
        final integrity = db.select('PRAGMA quick_check');
        if (integrity.length != 1 || integrity.single.values.single != 'ok') {
          throw StateError('Invalid database source: $id');
        }
      } finally {
        db.close();
      }
      if (isMissing) {
        // Publish only a complete schema. Preserve a source independently
        // initialized while staging, without yielding between probe and rename.
        if (File(dbPath).existsSync()) return _ensureInitializedForExport();
        File(initializationPath).renameSync(dbPath);
      }
      return dbPath;
    } finally {
      if (initializationDirectory != null) {
        try {
          await initializationDirectory.delete(recursive: true);
        } on FileSystemException {
          // An unremovable staging directory cannot become a live source;
          // preserve the original initialization error for the caller.
        }
      }
    }
  }

  @override
  BackupCapabilities get capabilities => BackupCapabilities(
    server: ServerCapability(
      export: _serveDatabase,
      prepareImport: _prepareServerImport,
    ),
    file: FileCapability(
      export: (path, {options}) async {
        await _exportToFile(path, options: options);
        return null;
      },
      prepareImport: _prepareFileImport,
    ),
    // No clipboard support for binary files
  );

  Future<shelf.Response> _serveDatabase(shelf.Request request) async {
    final dbPath = await dbPathGetter();
    final fs = ref.read(appFileSystemProvider);
    return createDbStreamResponse(
      fs: fs,
      filePath: dbPath,
      fileName: dbFileName,
    );
  }

  Future<ImportPreparation> _prepareServerImport(
    String serverUrl,
    BuildContext? uiContext,
  ) async {
    return ImportPreparation(
      versionCheck: const VersionCheckInfo(
        result: VersionCheckResult.compatible,
        currentVersion: null,
        importVersion: null,
      ),
      executeImport: () => _executeServerImport(serverUrl),
    );
  }

  Future<void> _executeServerImport(String serverUrl) async {
    final dio = Dio(BaseOptions(baseUrl: serverUrl));
    final dbPath = await dbPathGetter();
    final fs = ref.read(appFileSystemProvider);

    await downloadAndReplaceDb(
      fs: fs,
      dio: dio,
      url: '/$id',
      filePath: dbPath,
    );

    onImportComplete();
  }

  Future<void> _exportToFile(
    String directoryPath, {
    BackupExportOptions? options,
  }) async {
    await BackupUtils.ensureStoragePermissions(ref);

    final dbPath = await dbPathGetter();
    final fs = ref.read(appFileSystemProvider);

    if (!fs.fileExistsSync(dbPath)) {
      return;
    }

    final timestamp = DateFormat('yyyy.MM.dd.HH.mm.ss').format(DateTime.now());
    final fileName = 'boorusama_${id}_$timestamp.db';
    final destinationPath = p.join(directoryPath, fileName);

    await fs.copyFile(dbPath, destinationPath);
  }

  Future<ImportPreparation> _prepareFileImport(
    String filePath,
    BuildContext? uiContext,
  ) async {
    // Validate SQLite header
    final fs = ref.read(appFileSystemProvider);
    final bytes = await fs.openRead(filePath, start: 0, end: 16).first;
    final header = bytes.take(16).toList();

    if (!_isSQLiteFile(header)) {
      throw Exception(
        'Invalid SQLite file: $filePath',
      );
    }

    return ImportPreparation(
      versionCheck: const VersionCheckInfo(
        result: VersionCheckResult.compatible,
        currentVersion: null,
        importVersion: null,
      ),
      executeImport: () => _executeFileImport(filePath),
    );
  }

  Future<void> _executeFileImport(String sourcePath) async {
    await BackupUtils.ensureStoragePermissions(ref);

    final dbPath = await dbPathGetter();

    final fs = ref.read(appFileSystemProvider);
    await BackupUtils.replaceFile(fs, sourcePath, dbPath);
    onImportComplete();
  }

  // SQLite files start with "SQLite format 3\0"
  bool _isSQLiteFile(List<int> header) {
    const sqliteHeader = [
      0x53,
      0x51,
      0x4C,
      0x69,
      0x74,
      0x65,
      0x20,
      0x66,
      0x6F,
      0x72,
      0x6D,
      0x61,
      0x74,
      0x20,
      0x33,
      0x00,
    ];
    if (header.length < 16) return false;
    for (var i = 0; i < 16; i++) {
      if (header[i] != sqliteHeader[i]) return false;
    }
    return true;
  }
}
