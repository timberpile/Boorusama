import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:boorusama/core/backups/export_import/export/export_service.dart';
import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/core/backups/export_import/sources/export_import_source.dart';
import 'package:boorusama/core/backups/export_import/sources/legacy_sqlite_source_adapter.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/sources/sqlite_source.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';
import 'package:boorusama/core/bulk_downloads/src/data/repo_sqlite.dart';
import 'package:boorusama/core/search/histories/src/data/repo_sqlite.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/device_info.dart';

void main() {
  late Directory directory;
  late ProviderContainer container;
  late List<SqliteBackupSource> sources;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    directory = await Directory.systemTemp.createTemp('empty_sqlite_export_');
    container = ProviderContainer(
      overrides: [
        appFileSystemProvider.overrideWithValue(
          _TestFileSystem(directory.path),
        ),
        deviceInfoProvider.overrideWithValue(const DeviceInfo()),
      ],
    );
    sources = [
      container.read(searchHistoryBackupSourceProvider),
      container.read(downloadsBackupSourceProvider),
    ];
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    container.dispose();
    await directory.delete(recursive: true);
  });

  for (final id in ['search_histories', 'downloads']) {
    test('captures unused $id with its real empty schema', () async {
      final source = sources.singleWhere((source) => source.id == id);
      final snapshot = await LegacySqliteSourceAdapter(source).capture(
        ExportSourceRequest(
          selection: ExportNodeSelection.leaf(id),
          includeCredentials: false,
        ),
      );
      final output = '${directory.path}/captured.db';
      await snapshot.parts.values.single(output);
      final db = sqlite3.open(output, mode: OpenMode.readOnly);
      try {
        expect(db.select('PRAGMA integrity_check').single.values.single, 'ok');
        expect(db.select('SELECT * FROM ${_table(id)}'), isEmpty);
        if (id == 'downloads') expect(db.userVersion, 1);
      } finally {
        db.close();
      }
    });

    test('custom export includes individually selected unused $id', () async {
      final source = sources.singleWhere((source) => source.id == id);
      final output = await _service([source]).createPackage(
        ExportRequest(
          selection: ExportSelection.custom({id: ExportNodeSelection.leaf(id)}),
          outputPath: '${directory.path}/custom.bsexport',
        ),
      );
      final staged = await const ExportPackageReader(
        fs: IoFileSystem(),
      ).stage(output);
      addTearDown(staged.dispose);
      expect(staged.manifest.sources.single.id, id);
      final db = sqlite3.open(
        staged.pathFor(staged.manifest.sources.single.parts.single.path),
        mode: OpenMode.readOnly,
      );
      try {
        expect(db.select('SELECT * FROM ${_table(id)}'), isEmpty);
      } finally {
        db.close();
      }
    });

    test('preserves populated $id during capture', () async {
      final source = sources.singleWhere((source) => source.id == id);
      final sourcePath = await source.dbPathGetter();
      await Directory('${directory.path}/data').create();
      _populate(sourcePath, id);
      final snapshot = await LegacySqliteSourceAdapter(source).capture(
        ExportSourceRequest(
          selection: ExportNodeSelection.leaf(id),
          includeCredentials: false,
        ),
      );
      final output = '${directory.path}/populated.db';
      await snapshot.parts.values.single(output);
      final db = sqlite3.open(output, mode: OpenMode.readOnly);
      try {
        for (final table in _tables(id)) {
          expect(db.select('SELECT * FROM $table'), hasLength(1));
        }
      } finally {
        db.close();
      }
    });

    for (final contents in [
      <int>[],
      [1, 2, 3, 4],
    ]) {
      test(
        'rejects ${contents.isEmpty ? 'zero-byte' : 'corrupt'} $id without replacing it',
        () async {
          final source = sources.singleWhere((source) => source.id == id);
          final sourcePath = await source.dbPathGetter();
          await Directory('${directory.path}/data').create();
          await File(sourcePath).writeAsBytes(contents);
          final output = '${directory.path}/invalid.bsexport';
          await expectLater(
            _service([source]).createPackage(
              ExportRequest(
                selection: ExportSelection.custom({
                  id: ExportNodeSelection.leaf(id),
                }),
                outputPath: output,
              ),
            ),
            throwsA(anything),
          );
          expect(File(sourcePath).readAsBytesSync(), contents);
          expect(File(output).existsSync(), isFalse);
        },
      );
    }
  }

  test('full empty export replaces populated history and downloads', () async {
    final registry = BackupRegistry();
    for (final source in sources) {
      registry.registerDescriptor(
        LegacySqliteSourceAdapter(source).selectionDescriptor,
      );
    }
    final output = await _service(sources).createPackage(
      ExportRequest(
        selection: ExportSelection.full(registry),
        outputPath: '${directory.path}/full.bsexport',
        recommendedActions: const {
          'search_histories': ImportAction.replace,
          'downloads': ImportAction.replace,
        },
      ),
    );
    final staged = await const ExportPackageReader(
      fs: IoFileSystem(),
    ).stage(output);
    addTearDown(staged.dispose);
    expect(staged.manifest.sources.map((source) => source.id).toSet(), {
      'search_histories',
      'downloads',
    });
    for (final source in sources) {
      _populate(await source.dbPathGetter(), source.id);
      final part = staged.manifest.sources
          .singleWhere((entry) => entry.id == source.id)
          .parts
          .single;
      final transactionProvider = Provider(
        (ref) => PackageTransactionSource(
          source: source,
          incomingPath: '${staged.directoryPath}/${part.path}',
          fs: ref.read(appFileSystemProvider),
          ref: ref,
          credentialsIncluded: false,
        ),
      );
      final transaction = container.read(transactionProvider);
      await transaction.prepare(null);
      await transaction.apply(
        ResolvedImportSource(
          id: source.id,
          action: ImportAction.replace,
          items: const [],
        ),
      );
      final db = sqlite3.open(await source.dbPathGetter());
      try {
        for (final table in _tables(source.id)) {
          expect(db.select('SELECT * FROM $table'), isEmpty);
        }
      } finally {
        db.close();
      }
    }
  });

  test(
    'failed first-use initialization cannot export a partial schema on retry',
    () async {
      final initializationError = StateError(
        'schema initialization interrupted',
      );
      var interrupted = true;
      final sourceProvider = Provider(
        (ref) => _InitializationSource(
          ref: ref,
          path: '${directory.path}/data/partial.db',
          initialize: (db) {
            if (interrupted) {
              db.execute('CREATE TABLE first_table (id INTEGER PRIMARY KEY)');
              throw initializationError;
            }
            DownloadRepositorySqlite(db).initialize();
          },
        ),
      );
      final source = container.read(sourceProvider);
      final output = '${directory.path}/partial.bsexport';
      final service = _service([source]);
      final request = ExportRequest(
        selection: ExportSelection.custom(const {
          'downloads': ExportNodeSelection.leaf('downloads'),
        }),
        outputPath: output,
      );

      await expectLater(
        service.createPackage(request),
        throwsA(same(initializationError)),
      );
      expect(File(output).existsSync(), isFalse);
      // A persistent initializer failure must fail every attempt honestly.
      await expectLater(
        service.createPackage(request),
        throwsA(same(initializationError)),
      );
      expect(File(output).existsSync(), isFalse);

      expect(File(await source.dbPathGetter()).existsSync(), isFalse);
      interrupted = false;
      final staged = await const ExportPackageReader(fs: IoFileSystem()).stage(
        await service.createPackage(request),
      );
      addTearDown(staged.dispose);
      final db = sqlite3.open(
        staged.pathFor(staged.manifest.sources.single.parts.single.path),
        mode: OpenMode.readOnly,
      );
      try {
        expect(db.userVersion, 1);
        for (final table in _tables('downloads')) {
          expect(db.select('SELECT * FROM $table'), isEmpty);
        }
        expect(
          db.select(
            "SELECT name FROM sqlite_master WHERE name = 'first_table'",
          ),
          isEmpty,
        );
      } finally {
        db.close();
      }
    },
  );

  test('first-use initialization waits for ongoing data mutations', () async {
    final blocker = Completer<void>();
    final entered = Completer<void>();
    final coordinator = container.read(dataMutationCoordinatorProvider);
    final mutation = coordinator.runExclusive(() async {
      entered.complete();
      await blocker.future;
    });
    await entered.future;
    final source = sources.first;
    final capture = LegacySqliteSourceAdapter(source).capture(
      ExportSourceRequest(
        selection: ExportNodeSelection.leaf(source.id),
        includeCredentials: false,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(File(await source.dbPathGetter()).existsSync(), isFalse);
    blocker.complete();
    await mutation;
    final snapshot = await capture;
    await snapshot.parts.values.single('${directory.path}/serialized.db');
    expect(
      File('${directory.path}/serialized.db').lengthSync(),
      greaterThan(16),
    );
  });

  for (final id in ['search_histories', 'downloads']) {
    test('unreadable $id fails without replacing source data', () async {
      final source = sources.singleWhere((source) => source.id == id);
      final path = await source.dbPathGetter();
      await Directory('${directory.path}/data').create();
      _populate(path, id);
      final before = File(path).readAsBytesSync();
      expect((await Process.run('chmod', ['000', path])).exitCode, 0);
      final output = '${directory.path}/unreadable.bsexport';
      try {
        await expectLater(
          _service([source]).createPackage(
            ExportRequest(
              selection: ExportSelection.custom({
                id: ExportNodeSelection.leaf(id),
              }),
              outputPath: output,
            ),
          ),
          throwsA(isA<SqliteException>()),
        );
      } finally {
        await Process.run('chmod', ['600', path]);
      }
      expect(File(path).readAsBytesSync(), before);
      expect(File(output).existsSync(), isFalse);
    }, skip: !Platform.isLinux);
  }

  test(
    'first-use directory failure fails without publishing a package',
    () async {
      await File('${directory.path}/data').writeAsString('not a directory');
      final output = '${directory.path}/failed.bsexport';
      await expectLater(
        _service(sources).createPackage(
          ExportRequest(
            selection: ExportSelection.custom(const {
              'search_histories': ExportNodeSelection.leaf('search_histories'),
            }),
            outputPath: output,
          ),
        ),
        throwsA(anything),
      );
      expect(File(output).existsSync(), isFalse);
      expect(
        File('${directory.path}/data').readAsStringSync(),
        'not a directory',
      );
    },
  );
}

ExportService _service(List<SqliteBackupSource> sources) => ExportService(
  sources: () => sources.map(LegacySqliteSourceAdapter.new).toList(),
  writer: const ExportPackageWriter(fs: IoFileSystem()),
  appVersion: 'test',
);

String _table(String id) =>
    id == 'search_histories' ? 'search_history' : 'download_tasks';

Iterable<String> _tables(String id) => id == 'search_histories'
    ? const ['search_history']
    : const [
        'download_tasks',
        'saved_download_tasks',
        'download_sessions',
        'download_records',
        'download_session_statistics',
      ];

void _populate(String path, String id) {
  final db = sqlite3.open(path);
  try {
    if (id == 'search_histories') {
      SearchHistoryRepositorySqlite(db: db).initialize();
      db.execute(
        "INSERT INTO search_history (query, type, booru_type_name, site_url, created_at, updated_at) VALUES ('test', 'simple', 'test', 'https://example.com', 1, 1)",
      );
    } else {
      DownloadRepositorySqlite(db).initialize();
      db.execute(
        "INSERT INTO download_tasks (id, path, created_at, updated_at) VALUES ('test', '/test', 1, 1)",
      );
      db.execute(
        "INSERT INTO saved_download_tasks (task_id, name, created_at) VALUES ('test', 'Saved task', 1)",
      );
      db.execute(
        "INSERT INTO download_sessions (id, task_id, started_at, status, task) VALUES ('session', 'test', 1, 'completed', '{}')",
      );
      db.execute(
        "INSERT INTO download_records (url, session_id, status, page, page_index, created_at, file_name) VALUES ('https://example.com/file.png', 'session', 'completed', 1, 0, 1, 'file.png')",
      );
      db.execute(
        "INSERT INTO download_session_statistics (session_id, total_files, total_size) VALUES ('session', 1, 10)",
      );
    }
  } finally {
    db.close();
  }
}

class _TestFileSystem extends IoFileSystem {
  const _TestFileSystem(this.path);
  final String path;
  @override
  Future<String> getAppStoragePath() async => path;
}

class _InitializationSource extends SqliteBackupSource {
  _InitializationSource({
    required super.ref,
    required String path,
    required void Function(Database) initialize,
  }) : super(
         id: 'downloads',
         priority: 4,
         dbPathGetter: () async => path,
         dbFileName: 'partial.db',
         onImportComplete: () {},
         initializeDatabase: initialize,
       );

  @override
  String get displayName => 'Downloads';

  @override
  Widget buildTile(BuildContext context) => const SizedBox.shrink();
}
