import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/backups/auto/repo_io.dart';
import 'package:boorusama/core/backups/auto/providers.dart';
import 'package:boorusama/core/backups/zip/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/core/backups/auto/service.dart';
import 'package:boorusama/core/backups/auto/types.dart';
import 'package:boorusama/core/backups/export_import/export/export_service.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/core/backups/export_import/sources/export_import_source.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late AutoBackupRepositoryIo repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('auto_backup_service_');
    repository = const AutoBackupRepositoryIo(IoFileSystem());
  });

  tearDown(() => directory.delete(recursive: true));

  test('defaults to 30 retained backups while honoring saved values', () {
    expect(const AutoBackupSettings().maxBackups, 30);
    expect(AutoBackupSettings.parse(<String, dynamic>{}).maxBackups, 30);
    expect(AutoBackupSettings.parse({'maxBackups': 0}).maxBackups, 30);

    for (final count in [1, 2, 3, 4, 5, 12, 30, 60, 90, 120]) {
      final restored = AutoBackupSettings.parse({'maxBackups': count});
      expect(restored.maxBackups, count);
      expect(
        AutoBackupSettings.parse(restored.toJson()).maxBackups,
        count,
      );
    }
  });

  test('automatic backup creates a full export with credentials', () async {
    final sources = [_FakeSource('first'), _FakeSource('second')];
    final registry = _registryFor(sources);
    final service = AutoBackupService(
      exportService: _exportService(sources),
      logger: const _Logger(),
      registry: registry,
      repository: repository,
    );

    final result = await service.performBackup(
      AutoBackupSettings(userSelectedPath: directory.path),
    );
    final staged = await const ExportPackageReader(
      fs: IoFileSystem(),
    ).stage(result.filePath);
    addTearDown(staged.dispose);

    expect(result.success, isTrue);
    expect(
      p.basename(result.filePath),
      matches(
        RegExp(r'^boorusama-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}Z\.bsexport$'),
      ),
    );
    expect(staged.manifest.sources.map((source) => source.id), {
      'first',
      'second',
    });
    expect(
      sources.map((source) => source.lastRequest?.includeCredentials),
      everyElement(isTrue),
    );
  });

  test('successful backup retains only the newest configured files', () async {
    final sources = [_FakeSource('source')];
    final registry = _registryFor(sources);
    final backupDirectory = await repository.getBackupDirectoryPath(
      directory.path,
    );
    final legacyPath = p.join(backupDirectory, 'legacy.zip');
    final previousPath = p.join(backupDirectory, 'previous.bsexport');
    File(legacyPath).writeAsStringSync('legacy');
    File(previousPath).writeAsStringSync('previous');
    await repository.saveManifest(
      backupDirectory,
      AutoBackupManifest(
        backups: [
          AutoBackupEntry(
            fileName: p.basename(legacyPath),
            createdAt: DateTime.utc(2024),
            fileSize: File(legacyPath).lengthSync(),
          ),
          AutoBackupEntry(
            fileName: p.basename(previousPath),
            createdAt: DateTime.utc(2025),
            fileSize: File(previousPath).lengthSync(),
          ),
        ],
      ),
    );
    final service = AutoBackupService(
      exportService: _exportService(sources),
      logger: const _Logger(),
      registry: registry,
      repository: repository,
    );

    final result = await service.performBackup(
      AutoBackupSettings(maxBackups: 1, userSelectedPath: directory.path),
    );
    final manifest = await repository.loadManifest(backupDirectory);

    expect(manifest.backups.map((entry) => entry.fileName), [
      p.basename(result.filePath),
    ]);
    expect(File(legacyPath).existsSync(), isFalse);
    expect(File(previousPath).existsSync(), isFalse);
    expect(File(result.filePath).existsSync(), isTrue);
  });

  test('successful backup retains 30 entries and removes the oldest', () async {
    final sources = [_FakeSource('source')];
    final backupDirectory = await repository.getBackupDirectoryPath(
      directory.path,
    );
    final existing = <AutoBackupEntry>[];
    for (var day = 1; day <= 30; day++) {
      final fileName = 'previous-$day.bsexport';
      final file = File(p.join(backupDirectory, fileName))
        ..writeAsStringSync('backup $day');
      existing.add(
        AutoBackupEntry(
          fileName: fileName,
          createdAt: DateTime.utc(2025, 1, day),
          fileSize: file.lengthSync(),
        ),
      );
    }
    await repository.saveManifest(
      backupDirectory,
      AutoBackupManifest(backups: existing),
    );

    final service = AutoBackupService(
      exportService: _exportService(sources),
      logger: const _Logger(),
      registry: _registryFor(sources),
      repository: repository,
    );
    final result = await service.performBackup(
      AutoBackupSettings(maxBackups: 30, userSelectedPath: directory.path),
    );
    final manifest = await repository.loadManifest(backupDirectory);
    final names = manifest.backups.map((entry) => entry.fileName).toSet();

    expect(names, hasLength(30));
    expect(names, isNot(contains('previous-1.bsexport')));
    expect(names, containsAll(existing.skip(1).map((entry) => entry.fileName)));
    expect(names, contains(p.basename(result.filePath)));
    expect(
      File(p.join(backupDirectory, 'previous-1.bsexport')).existsSync(),
      isFalse,
    );
    expect(File(result.filePath).existsSync(), isTrue);
  });

  test(
    'automatic export uses the next suffix when names are occupied',
    () async {
      final sources = [_FakeSource('source')];
      final service = AutoBackupService(
        exportService: _exportService(sources),
        logger: const _Logger(),
        registry: _registryFor(sources),
        repository: const _OccupiedExportNameRepository(),
      );

      final result = await service.performBackup(
        AutoBackupSettings(userSelectedPath: directory.path),
      );

      expect(
        p.basename(result.filePath),
        matches(
          RegExp(
            r'^boorusama-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}Z-3\.bsexport$',
          ),
        ),
      );
      expect(File(result.filePath).existsSync(), isTrue);
    },
  );

  test('overlapping automatic exports keep separate packages', () async {
    final sources = [_FakeSource('source')];
    final service = AutoBackupService(
      exportService: _exportService(sources),
      logger: const _Logger(),
      registry: _registryFor(sources),
      repository: repository,
      now: () => DateTime.utc(2026, 10, 3, 12, 5, 6),
    );
    final settings = AutoBackupSettings(
      maxBackups: 2,
      userSelectedPath: directory.path,
    );

    final results = await Future.wait([
      service.performBackup(settings),
      service.performBackup(settings),
    ]);

    expect(results.map((result) => p.basename(result.filePath)).toSet(), {
      'boorusama-2026-10-03_12-05-06Z.bsexport',
      'boorusama-2026-10-03_12-05-06Z-2.bsexport',
    });
    for (final result in results) {
      expect(File(result.filePath).existsSync(), isTrue);
    }
  });
  for (final operation in ['read', 'write', 'delete']) {
    test('$operation failure never reports a successful backup', () async {
      final sources = [_FakeSource('source')];
      final failing = _FailingRepository(operation);
      final backupDirectory = await failing.getBackupDirectoryPath(
        directory.path,
      );
      File(
        p.join(backupDirectory, 'previous.bsexport'),
      ).writeAsStringSync('previous');
      await repository.saveManifest(
        backupDirectory,
        AutoBackupManifest(
          backups: [
            AutoBackupEntry(
              fileName: 'previous.bsexport',
              createdAt: DateTime.utc(2024),
              fileSize: 8,
            ),
          ],
        ),
      );
      final service = AutoBackupService(
        exportService: _exportService(sources),
        logger: const _Logger(),
        registry: _registryFor(sources),
        repository: failing,
      );
      await expectLater(
        service.performBackup(
          AutoBackupSettings(userSelectedPath: directory.path, maxBackups: 1),
        ),
        throwsStateError,
      );
      expect(
        File(p.join(backupDirectory, 'previous.bsexport')).existsSync(),
        isTrue,
      );
    });
  }
  test(
    'automatic failure survives operation disposal without advancing backup time',
    () async {
      final sources = [_FakeSource('source')];
      final settings = AutoBackupSettings(
        enabled: true,
        userSelectedPath: directory.path,
        lastBackupTime: DateTime.utc(2024),
      );
      final service = AutoBackupService(
        exportService: _exportService(sources),
        logger: const _Logger(),
        registry: _registryFor(sources),
        repository: const _FailingRepository('write'),
      );
      final container = ProviderContainer(
        overrides: [
          autoBackupServiceProvider.overrideWithValue(service),
          loggerProvider.overrideWithValue(const _Logger()),
          settingsNotifierProvider.overrideWith(
            () => SettingsNotifier(
              Settings.defaultSettings.copyWith(autoBackup: settings),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final operation = container
          .read(backupProvider.notifier)
          .performAutoBackupIfNeeded(settings);
      await container.pump();
      await operation;
      await container.pump();
      expect(container.read(autoBackupFailureProvider), isTrue);
      expect(
        container.read(settingsProvider).autoBackup.lastBackupTime,
        DateTime.utc(2024),
      );
    },
  );
}

BackupRegistry _registryFor(List<_FakeSource> sources) {
  final registry = BackupRegistry();
  for (final source in sources) {
    registry.registerDescriptor(source.selectionDescriptor);
  }
  return registry;
}

final class _OccupiedExportNameRepository extends AutoBackupRepositoryIo {
  const _OccupiedExportNameRepository() : super(const IoFileSystem());

  @override
  bool fileExists(String path) {
    final name = p.basename(path);
    if (RegExp(
      r'^boorusama-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}Z(?:-2)?\.bsexport$',
    ).hasMatch(name)) {
      return true;
    }
    return super.fileExists(path);
  }
}

ExportService _exportService(List<_FakeSource> sources) => ExportService(
  sources: () => sources,
  writer: const ExportPackageWriter(fs: IoFileSystem()),
  appVersion: '1.0.0',
);

final class _FakeSource implements ExportImportSource {
  _FakeSource(this.id);

  @override
  final String id;

  ExportSourceRequest? lastRequest;

  @override
  int get priority => 0;

  @override
  int get schemaVersion => 1;

  @override
  ExportSelectionDescriptor get selectionDescriptor =>
      ExportSelectionDescriptor.leaf(id: id);

  @override
  Future<ExportSourceSnapshot> capture(ExportSourceRequest request) async {
    lastRequest = request;
    return ExportSourceSnapshot.json(
      sourceId: id,
      schemaVersion: schemaVersion,
      json: jsonEncode({'credentials': request.includeCredentials}),
    );
  }
}

final class _Logger implements Logger {
  const _Logger();

  @override
  String getDebugName() => 'auto backup test';

  @override
  void debug(String serviceName, String message) {}

  @override
  void error(String serviceName, String message) {}

  @override
  void info(String serviceName, String message) {}

  @override
  void verbose(String serviceName, String message) {}

  @override
  void warn(String serviceName, String message) {}
}

class _FailingRepository extends AutoBackupRepositoryIo {
  const _FailingRepository(this.operation) : super(const IoFileSystem());
  final String operation;

  @override
  Future<AutoBackupManifest> loadManifest(String directory) {
    if (operation == 'read') throw StateError('read failed');
    return super.loadManifest(directory);
  }

  @override
  Future<String> writeBackup(
    String destination,
    Future<String> Function(String) createPackage,
  ) {
    if (operation == 'write') throw StateError('write failed');
    return super.writeBackup(destination, createPackage);
  }

  @override
  Future<void> deleteFile(String path) {
    if (operation == 'delete') throw StateError('delete failed');
    return super.deleteFile(path);
  }
}
