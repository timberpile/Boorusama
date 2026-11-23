import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import '../../bulk_downloads/src/data/repo_sqlite.dart';
import '../../search/histories/src/data/repo_sqlite.dart';

/// Structural identity of a supported app-owned portable database. Validate
/// before its initializer can manufacture missing tables in an unrelated file.
final class SqliteImportContract {
  const SqliteImportContract({
    required this.currentVersion,
    required this.initializeDatabase,
    required this.otherSourceTable,
    required this.primaryKeys,
    required this.uniqueKeys,
    this.foreignKeys = const {},
    this.addedColumns = const {},
  });

  final int currentVersion;
  final void Function(Database db) initializeDatabase;

  final String otherSourceTable;
  final Map<String, List<String>> primaryKeys;
  final Map<String, List<String>> uniqueKeys;
  final Map<String, (String, String, String)> foreignKeys;
  final Map<int, Map<String, Set<String>>> addedColumns;

  Future<void> prepare(String path) => _prepareInWorker(path, this);

  void _validate(
    Database db,
    Database reference, {
    bool requireCurrentVersion = false,
  }) {
    final version = db.userVersion;
    if (version < 0 ||
        version > currentVersion ||
        (requireCurrentVersion && version != currentVersion)) {
      throw const FormatException('Unsupported database schema version');
    }
    final tables = db.select('PRAGMA main.table_list');
    if (tables.any((row) => row['name'] == otherSourceTable)) {
      throw const FormatException('Database contains another source');
    }
    // Neither released source creates executable or virtual schema objects.
    if (tables.any((row) => row['type'] != 'table') ||
        db
            .select(
              "SELECT 1 FROM sqlite_master WHERE type = 'trigger' LIMIT 1",
            )
            .isNotEmpty) {
      throw const FormatException('Unsupported database schema objects');
    }
    final integrity = db.select('PRAGMA integrity_check(1)');
    if (integrity.length != 1 || integrity.single.values.single != 'ok') {
      throw const FormatException('Invalid database integrity');
    }
    for (final table in primaryKeys.keys) {
      if (!tables.any(
        (row) => row['name'] == table && row['type'] == 'table',
      )) {
        throw const FormatException('Database source identity does not match');
      }
      // Compare with the production writer so staged data can be read and new
      // records inserted after replacement. Older generations omit later columns.
      final actual = {
        for (final row in db.select('SELECT * FROM pragma_table_info(?)', [
          table,
        ]))
          row['name']: row,
      };
      final laterColumns = {
        for (final addition in addedColumns.entries)
          if (addition.key > version) ...?addition.value[table],
      };
      for (final expected in reference.select(
        'SELECT * FROM pragma_table_info(?)',
        [table],
      )) {
        if (laterColumns.contains(expected['name'])) continue;
        final column = actual.remove(expected['name']);
        if (column == null ||
            column['type'] != expected['type'] ||
            column['notnull'] != expected['notnull'] ||
            column['dflt_value'] != expected['dflt_value']) {
          throw const FormatException('Database source columns do not match');
        }
      }
      // Additive columns are compatible only if the app can omit them on INSERT.
      if (requireCurrentVersion &&
          actual.values.any(
            (column) =>
                column['notnull'] == 1 &&
                (column['dflt_value'] == null ||
                    column['dflt_value'].toString().toUpperCase() == 'NULL'),
          )) {
        throw const FormatException('Database requires an unsupported column');
      }
      // Repository UPSERTs and deletes depend on the released key constraints.
      final primaryKey = db
          .select(
            'SELECT name FROM pragma_table_info(?) WHERE pk > 0 ORDER BY pk',
            [table],
          )
          .map((row) => row['name']);
      if (!_matchesColumns(primaryKey, primaryKeys[table]!)) {
        throw const FormatException(
          'Database source primary key does not match',
        );
      }
      if (uniqueKeys[table] case final expected?) {
        final indexes = db.select(
          'SELECT name FROM pragma_index_list(?) WHERE "unique" = 1 AND partial = 0',
          [table],
        );
        if (!indexes.any(
          (index) => _matchesColumns(
            db
                .select(
                  'SELECT name FROM pragma_index_info(?) ORDER BY seqno',
                  [index['name']],
                )
                .map((row) => row['name']),
            expected,
          ),
        )) {
          throw const FormatException(
            'Database source unique key does not match',
          );
        }
      }
      if (foreignKeys[table] case (
        final column,
        final parent,
        final onDelete,
      )) {
        final references = db.select(
          'SELECT * FROM pragma_foreign_key_list(?)',
          [table],
        );
        if (!references.any(
          (row) =>
              row['from'] == column &&
              row['table'] == parent &&
              row['to'] == 'id' &&
              row['on_delete'] == onDelete,
        )) {
          throw const FormatException(
            'Database source foreign key does not match',
          );
        }
      }
    }
    if (db
        .select('SELECT 1 FROM pragma_foreign_key_check LIMIT 1')
        .isNotEmpty) {
      throw const FormatException('Database contains broken relationships');
    }
  }

  static const searchHistory = SqliteImportContract(
    currentVersion: 0,
    otherSourceTable: 'download_tasks',
    primaryKeys: {
      'search_history': ['id'],
    },
    uniqueKeys: {
      'search_history': ['query', 'type'],
    },
    initializeDatabase: _initializeHistory,
  );

  static const downloads = SqliteImportContract(
    currentVersion: 2,
    otherSourceTable: 'search_history',
    primaryKeys: {
      'download_tasks': ['id'],
      'saved_download_tasks': ['id'],
      'download_sessions': ['id'],
      'download_records': ['url', 'session_id'],
      'download_session_statistics': ['id'],
    },
    uniqueKeys: {
      'saved_download_tasks': ['task_id'],
      'download_session_statistics': ['session_id'],
    },
    foreignKeys: {
      'saved_download_tasks': ('task_id', 'download_tasks', 'RESTRICT'),
      'download_sessions': ('task_id', 'download_tasks', 'SET NULL'),
      'download_records': ('session_id', 'download_sessions', 'CASCADE'),
      'download_session_statistics': (
        'session_id',
        'download_sessions',
        'SET NULL',
      ),
    },
    initializeDatabase: _initializeDownloads,
    addedColumns: {
      2: {
        'download_tasks': {'sidecar_format'},
        'download_records': {'sidecar'},
      },
    },
  );
}

bool _matchesColumns(Iterable<Object?> names, List<String> expected) =>
    names.length == expected.length &&
    names.indexed.every((entry) => expected[entry.$1] == entry.$2);

void _initializeHistory(Database db) =>
    SearchHistoryRepositorySqlite(db: db).initialize();

void _initializeDownloads(Database db) =>
    DownloadRepositorySqlite(db).initialize();

// This closure is created outside a provider or source instance. Only the path
// and the immutable contract with top-level initializer tear-offs cross isolates.
Future<void> _prepareInWorker(String path, SqliteImportContract contract) =>
    Isolate.run(() {
      final reference = sqlite3.openInMemory();
      try {
        contract.initializeDatabase(reference);
        final db = sqlite3.open(path, mode: OpenMode.readWrite);
        try {
          db.execute('PRAGMA trusted_schema = OFF');
          contract._validate(db, reference);
          final journalMode = db.select('PRAGMA journal_mode = DELETE');
          if (journalMode.single.values.single != 'delete') {
            throw const FormatException('Cannot stage a standalone database');
          }
          contract.initializeDatabase(db);
          contract._validate(db, reference, requireCurrentVersion: true);
        } finally {
          db.close();
        }
      } finally {
        reference.close();
      }
    });
