import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/sources/sqlite_source.dart';
import 'package:boorusama/core/bulk_downloads/src/data/repo_sqlite.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/core/search/histories/src/data/repo_sqlite.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/device_info.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory root;
  late ProviderContainer container;
  late SqliteBackupSource downloads;
  late SqliteBackupSource history;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    root = await Directory.systemTemp.createTemp('sqlite_import_validation_');
    await Directory('${root.path}/data').create();
    container = ProviderContainer(
      overrides: [
        appFileSystemProvider.overrideWithValue(_FileSystem(root.path)),
        loggerProvider.overrideWithValue(AppLogger()),
        deviceInfoProvider.overrideWithValue(const DeviceInfo()),
      ],
    );
    downloads = container.read(downloadsBackupSourceProvider);
    history = container.read(searchHistoryBackupSourceProvider);
    _downloads(await downloads.dbPathGetter(), value: 'keep-task');
    _history(await history.dbPathGetter(), query: 'keep-query');
  });
  tearDown(() async {
    container.dispose();
    await root.delete(recursive: true);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'a SQLite-looking corrupt file fails before replacing live data',
    () async {
      final live = File(await downloads.dbPathGetter());
      final before = live.readAsBytesSync();
      final incoming = File('${root.path}/corrupt.db');
      await incoming.writeAsBytes([
        ...ascii.encode('SQLite format 3\u0000'),
        ...List<int>.filled(256, 0xff),
      ]);
      await expectLater(
        downloads.capabilities.file!.prepareImport(incoming.path, null),
        throwsA(anything),
      );
      expect(live.readAsBytesSync(), before);
    },
  );

  for (final toDownloads in [false, true]) {
    test(
      'a different source database is rejected, downloads=$toDownloads',
      () async {
        final source = toDownloads ? downloads : history;
        final live = File(await source.dbPathGetter());
        final before = live.readAsBytesSync();
        final incoming = '${root.path}/wrong-source.db';
        if (toDownloads) {
          _history(incoming, query: 'incoming');
        } else {
          _downloads(incoming, value: 'incoming');
        }
        final incomingBefore = File(incoming).readAsBytesSync();
        await expectLater(
          source.capabilities.file!.prepareImport(incoming, null),
          throwsA(anything),
        );
        expect(live.readAsBytesSync(), before);
        expect(File(incoming).readAsBytesSync(), incomingBefore);
      },
    );
  }

  for (final malformed in [
    'empty-schema',
    'missing-column',
    'future',
    'trigger',
    'orphan',
  ]) {
    test('rejects $malformed before the initializer can approve it', () async {
      final incoming = '${root.path}/$malformed.db';
      if (malformed == 'empty-schema') {
        final db = sqlite3.open(incoming);
        db.execute('CREATE TABLE unrelated (id INTEGER PRIMARY KEY)');
        db.close();
      } else {
        _downloads(incoming, value: 'incoming');
        final db = sqlite3.open(incoming);
        try {
          switch (malformed) {
            case 'missing-column':
              db.execute('ALTER TABLE download_records DROP COLUMN sidecar');
            case 'future':
              db.execute('PRAGMA user_version = 3');
            case 'trigger':
              db.execute(
                '''
CREATE TRIGGER unexpected AFTER INSERT ON download_tasks
                BEGIN DELETE FROM saved_download_tasks; END''',
              );
            case 'orphan':
              db.execute(
                "INSERT INTO saved_download_tasks (task_id, created_at) VALUES ('absent', 1)",
              );
          }
        } finally {
          db.close();
        }
      }
      final live = File(await downloads.dbPathGetter());
      final before = live.readAsBytesSync();
      await expectLater(
        downloads.capabilities.file!.prepareImport(incoming, null),
        throwsA(anything),
      );
      expect(live.readAsBytesSync(), before);
    });
  }

  test(
    'rejects a History schema without the unique key its UPSERT needs',
    () async {
      final incoming = '${root.path}/missing-history-unique.db';
      final db = sqlite3.open(incoming);
      try {
        db.execute('''
        CREATE TABLE search_history (
          id INTEGER PRIMARY KEY,
          query TEXT NOT NULL,
          type TEXT NOT NULL,
          booru_type_name TEXT NOT NULL,
          site_url TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          search_count INTEGER DEFAULT 1
        )
      ''');
      } finally {
        db.close();
      }
      final live = File(await history.dbPathGetter());
      final before = live.readAsBytesSync();
      await expectLater(
        history.capabilities.file!.prepareImport(incoming, null),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('unique key'),
          ),
        ),
      );
      expect(live.readAsBytesSync(), before);
    },
  );

  for (final change in [
    'updated_at TEXT NOT NULL',
    'updated_at INTEGER',
    'updated_at INTEGER NOT NULL, extra TEXT NOT NULL',
  ]) {
    test(
      'incompatible History writer columns fail in staging: $change',
      () async {
        final incoming = '${root.path}/incompatible.db';
        final db = sqlite3.open(incoming);
        try {
          db.execute('''
          CREATE TABLE search_history (
            id INTEGER PRIMARY KEY,
            query TEXT NOT NULL,
            type TEXT NOT NULL,
            booru_type_name TEXT NOT NULL,
            site_url TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            $change,
            search_count INTEGER DEFAULT 1,
            UNIQUE(query, type)
          )
        ''');
        } finally {
          db.close();
        }
        final live = File(await history.dbPathGetter());
        final before = live.readAsBytesSync();
        await expectLater(
          history.capabilities.file!.prepareImport(incoming, null),
          throwsFormatException,
        );
        expect(live.readAsBytesSync(), before);
      },
    );
  }

  test('restores genuine released v1 Downloads and cold reopens', () async {
    final fixture = File(
      'test/fixtures/released_upgrade/v4.5.0-timberpile.3/storage/data/download.db',
    );
    final before = fixture.readAsBytesSync();
    final old = sqlite3.open(fixture.path, mode: OpenMode.readOnly);
    late String expectedId;
    try {
      expect(old.userVersion, 1);
      expectedId =
          old.select('SELECT id FROM download_tasks').single['id'] as String;
    } finally {
      old.close();
    }
    final preparation = await downloads.capabilities.file!.prepareImport(
      fixture.path,
      null,
    );
    await preparation.executeImport(deferRestart: true);
    for (var reopen = 0; reopen < 2; reopen++) {
      final db = sqlite3.open(await downloads.dbPathGetter());
      try {
        final repository = DownloadRepositorySqlite(db)..initialize();
        expect(db.userVersion, 2);
        final saved = (await repository.getSavedTasks()).single;
        expect(saved.name, 'Fixture v1 saved download');
        expect(saved.task.id, expectedId);
        expect(saved.task.path, '/synthetic/downloads-v1');
        expect(saved.task.perPage, 16);
        expect(saved.task.sidecarFormat, isNull);
      } finally {
        db.close();
      }
    }
    expect(fixture.readAsBytesSync(), before);
  });

  test(
    'execution revalidates bytes changed after a successful preview',
    () async {
      final incoming = '${root.path}/changed.db';
      _downloads(incoming, value: 'incoming');
      final preparation = await downloads.capabilities.file!.prepareImport(
        incoming,
        null,
      );
      final live = File(await downloads.dbPathGetter());
      final before = live.readAsBytesSync();
      await File(incoming).delete();
      _history(incoming, query: 'wrong-source-after-preview');
      await expectLater(
        preparation.executeImport(deferRestart: true),
        throwsA(anything),
      );
      expect(live.readAsBytesSync(), before);
    },
  );

  for (final version in [0, 1]) {
    test(
      'stages version $version migrations without modifying the incoming file',
      () async {
        final incoming = '${root.path}/old-$version.db';
        _downloads(incoming, value: 'old-task');
        final old = sqlite3.open(incoming);
        try {
          old.execute('ALTER TABLE download_tasks DROP COLUMN sidecar_format');
          old.execute('ALTER TABLE download_records DROP COLUMN sidecar');
          old.execute(
            'DELETE FROM migrations_history WHERE version > $version',
          );
          old.execute('PRAGMA user_version = $version');
          if (version == 0) {
            old.execute(
              'ALTER TABLE download_tasks ADD COLUMN notifications INTEGER',
            );
          }
        } finally {
          old.close();
        }
        // Synthetic migration-unit input, not a claim of released-writer provenance.
        final inputBytes = File(incoming).readAsBytesSync();
        final preparation = await downloads.capabilities.file!.prepareImport(
          incoming,
          null,
        );
        expect(File(incoming).readAsBytesSync(), inputBytes);
        await preparation.executeImport(deferRestart: true);
        expect(File(incoming).readAsBytesSync(), inputBytes);
        for (var reopen = 0; reopen < 2; reopen++) {
          final db = sqlite3.open(await downloads.dbPathGetter());
          try {
            DownloadRepositorySqlite(db).initialize();
            expect(db.userVersion, 2);
            expect(
              db
                  .select('SELECT id FROM download_tasks')
                  .map((row) => row['id']),
              ['old-task'],
            );
            expect(
              db
                  .select('SELECT sidecar_format FROM download_tasks')
                  .single['sidecar_format'],
              isNull,
            );
            expect(
              db
                  .select('SELECT success FROM migrations_history')
                  .map((row) => row['success']),
              [1, 1],
            );
          } finally {
            db.close();
          }
        }
      },
    );
  }

  test('an ambiguous version/shape fails in staging and leaves the live file intact', () async {
    final incoming = '${root.path}/ambiguous.db';
    _downloads(incoming, value: 'incoming');
    final db = sqlite3.open(incoming);
    try {
      // A claimed old version with already-added columns makes the real ALTER fail.
      db.execute('DELETE FROM migrations_history WHERE version = 2');
      db.execute('PRAGMA user_version = 1');
    } finally {
      db.close();
    }
    final live = File(await downloads.dbPathGetter());
    final before = live.readAsBytesSync();
    await expectLater(
      downloads.capabilities.file!.prepareImport(incoming, null),
      throwsA(anything),
    );
    expect(live.readAsBytesSync(), before);
  });

  test(
    'the package transaction adapter uses the same source-validation gate',
    () async {
      final incoming = '${root.path}/wrong-part.db';
      _history(incoming, query: 'not-downloads');
      final provider = Provider(
        (ref) => PackageTransactionSource(
          source: downloads,
          incomingPath: incoming,
          fs: ref.read(appFileSystemProvider),
          ref: ref,
          credentialsIncluded: false,
        ),
      );
      final live = File(await downloads.dbPathGetter());
      final before = live.readAsBytesSync();
      await expectLater(
        container.read(provider).prepare(null),
        throwsA(anything),
      );
      expect(live.readAsBytesSync(), before);
    },
  );

  for (final (input, checksum, errorMessage) in [
    ('history', 'valid', 'Database contains another source'),
    ('downloads', 'missing', 'No checksum provided in header'),
    ('downloads', 'mismatch', 'Database file is corrupted'),
    ('downloads', 'valid', null),
  ]) {
    test('server validates $checksum checksum and $input schema', () async {
      final incoming = '${root.path}/served.db';
      if (input == 'history') {
        _history(incoming, query: 'not-downloads');
      } else {
        _downloads(incoming, value: 'incoming-task');
      }
      final bytes = File(incoming).readAsBytesSync();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final listener = server.listen((request) async {
        if (checksum != 'missing') {
          request.response.headers.set(
            'X-File-Checksum',
            checksum == 'valid'
                ? sha256.convert(bytes).toString()
                : 'incorrect',
          );
        }
        request.response.add(bytes);
        await request.response.close();
      });
      addTearDown(listener.cancel);
      final preparation = await downloads.capabilities.server.prepareImport(
        'http://${server.address.address}:${server.port}',
        null,
      );
      final live = File(await downloads.dbPathGetter());
      final before = live.readAsBytesSync();
      final operation = preparation.executeImport(deferRestart: true);
      if (errorMessage == null) {
        await operation;
        final db = sqlite3.open(live.path, mode: OpenMode.readOnly);
        try {
          expect(
            db.select('SELECT id FROM download_tasks').single['id'],
            'incoming-task',
          );
        } finally {
          db.close();
        }
      } else {
        await expectLater(
          operation,
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              errorMessage,
            ),
          ),
        );
        expect(live.readAsBytesSync(), before);
      }
      expect(File(incoming).readAsBytesSync(), bytes);
    });
  }

  test(
    'valid empty current sources can intentionally replace populated data',
    () async {
      for (final source in [downloads, history]) {
        final incoming = '${root.path}/empty-${source.id}.db';
        if (source.id == 'downloads') {
          _downloads(incoming);
        } else {
          _history(incoming);
        }
        final preparation = await source.capabilities.file!.prepareImport(
          incoming,
          null,
        );
        await preparation.executeImport(deferRestart: true);
        final db = sqlite3.open(await source.dbPathGetter());
        try {
          final table = source.id == 'downloads'
              ? 'download_tasks'
              : 'search_history';
          expect(db.select('SELECT * FROM $table'), isEmpty);
        } finally {
          db.close();
        }
      }
    },
  );
}

void _downloads(String path, {String? value}) {
  final db = sqlite3.open(path);
  try {
    DownloadRepositorySqlite(db).initialize();
    if (value != null) {
      db.execute(
        'INSERT INTO download_tasks (id, path, created_at, updated_at) VALUES (?, ?, 1, 1)',
        [value, '/synthetic'],
      );
    }
  } finally {
    db.close();
  }
}

void _history(String path, {String? query}) {
  final db = sqlite3.open(path);
  try {
    SearchHistoryRepositorySqlite(db: db).initialize();
    if (query != null) {
      db.execute(
        '''
INSERT INTO search_history
        (query, type, booru_type_name, site_url, created_at, updated_at)
        VALUES (?, 'simple', 'test', 'https://example.invalid', 1, 1)''',
        [query],
      );
    }
  } finally {
    db.close();
  }
}

class _FileSystem extends IoFileSystem {
  const _FileSystem(this.root);
  final String root;
  @override
  Future<String> getAppStoragePath() async => root;
}
