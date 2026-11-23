import 'dart:io';

import 'package:flutter_sqlite3_migration/src/exceptions.dart';
import 'package:flutter_sqlite3_migration/src/migration.dart';
import 'package:flutter_sqlite3_migration/src/migration_event.dart';
import 'package:flutter_sqlite3_migration/src/migration_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory directory;
  late String path;
  late Database db;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('migration_atomicity_');
    path = '${directory.path}/fixture.db';
    db = sqlite3.open(path);
  });
  tearDown(() {
    db.close();
    directory.deleteSync(recursive: true);
  });

  int version() => db.select('PRAGMA user_version').first.columnAt(0) as int;
  List<Map<String, Object?>> history() => [
    for (final row in db.select(
      'SELECT version, success, error_message FROM migrations_history ORDER BY version',
    ))
      Map<String, Object?>.from(row),
  ];
  bool hasPayload() => db
      .select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='payload'",
      )
      .isNotEmpty;
  List<Migration> migrations({void Function()? beforeFinish}) => [
    BasicMigration(
      version: 1,
      onUp: (context) {
        context.execute(
          'CREATE TABLE payload (id INTEGER PRIMARY KEY, value TEXT NOT NULL)',
        );
        context.execute("INSERT INTO payload VALUES (7, 'preserved')");
        beforeFinish?.call();
      },
    ),
  ];
  DbMigrationManager manager(List<Migration> steps) =>
      DbMigrationManager.create(
        db: db,
        targetVersion: 1,
        migrations: steps,
      );
  void reopen() {
    db.close();
    db = sqlite3.open(path);
  }

  test('a failed migration can succeed on retry and cold reopen', () {
    var fail = true;
    final failure = StateError('controlled migration failure');
    final steps = migrations(
      beforeFinish: () {
        if (fail) throw failure;
      },
    );
    expect(manager(steps).runMigrations, throwsA(same(failure)));
    expect(version(), 0);
    expect(hasPayload(), isFalse);
    expect(history().single['success'], 0);

    fail = false;
    expect(manager(steps).runMigrations, returnsNormally);
    reopen();
    expect(manager(steps).runMigrations, returnsNormally);
    expect(version(), 1);
    expect(history(), [
      {'version': 1, 'success': 1, 'error_message': null},
    ]);
    expect(
      db.select('SELECT id, value FROM payload').single['value'],
      'preserved',
    );
  });

  test(
    'a second connection can finish before this manager acquires its transaction',
    () {
      final steps = migrations();
      final other = sqlite3.open(path);
      addTearDown(other.close);
      final competing = DbMigrationManager.create(
        db: other,
        targetVersion: 1,
        migrations: steps,
      );
      final events = <MigrationEvent>[];
      final migration = manager(steps)
        ..addProgressListener(
          MigrationProgressListener(
            onEvent: (event) {
              events.add(event);
              if (event is MigrationStartedEvent) competing.runMigrations();
            },
          ),
        );
      migration.runMigrations();
      expect(events, [
        isA<MigrationStartedEvent>(),
        isA<MigrationCompletedEvent>(),
      ]);
      reopen();
      manager(steps).runMigrations();
      expect(history().single['success'], 1);
      expect(
        db.select('SELECT value FROM payload').single['value'],
        'preserved',
      );
    },
  );

  test('completion observers see the committed successful history', () {
    List<Map<String, Object?>>? atCompletion;
    final migration = manager(migrations())
      ..addProgressListener(
        MigrationProgressListener(
          onEvent: (event) {
            if (event is MigrationCompletedEvent) atCompletion = history();
          },
        ),
      );
    migration.runMigrations();
    expect(atCompletion, [
      {'version': 1, 'success': 1, 'error_message': null},
    ]);
  });

  test('completion observer failure cannot corrupt committed history', () {
    final failure = StateError('controlled observer failure');
    final steps = migrations();
    final migration = manager(steps)
      ..addProgressListener(
        MigrationProgressListener(
          onEvent: (event) {
            if (event is MigrationCompletedEvent) throw failure;
          },
        ),
      );
    expect(migration.runMigrations, throwsA(same(failure)));
    reopen();
    expect(manager(steps).runMigrations, returnsNormally);
    expect(version(), 1);
    expect(history().single['success'], 1);
    expect(db.select('SELECT value FROM payload').single['value'], 'preserved');
  });

  test('a success-history write failure rolls back schema and version', () {
    final migration = manager(migrations());
    db.execute('''
      CREATE TRIGGER fail_success_history BEFORE INSERT ON migrations_history
      WHEN NEW.success = 1 BEGIN
        SELECT RAISE(ABORT, 'controlled history write failure');
      END
    ''');
    expect(migration.runMigrations, throwsA(isA<SqliteException>()));
    reopen();
    expect(version(), 0);
    expect(hasPayload(), isFalse);
    expect(history().single['success'], 0);
    db.execute('DROP TRIGGER fail_success_history');
    expect(manager(migrations()).runMigrations, returnsNormally);
    expect(version(), 1);
  });

  test('failed diagnostic logging does not replace the migration error', () {
    final failure = StateError('original migration failure');
    final migration = manager(migrations(beforeFinish: () => throw failure));
    db.execute('''
      CREATE TRIGGER fail_failure_history BEFORE INSERT ON migrations_history
      WHEN NEW.success = 0 BEGIN
        SELECT RAISE(ABORT, 'controlled diagnostic failure');
      END
    ''');
    expect(migration.runMigrations, throwsA(same(failure)));
    expect(version(), 0);
    expect(hasPayload(), isFalse);
    expect(history(), isEmpty);
  });

  test('start observer failure leaves the database untouched', () {
    final failure = StateError('start observer failure');
    final migration = manager(migrations())
      ..addProgressListener(
        MigrationProgressListener(
          onEvent: (event) {
            if (event is MigrationStartedEvent) throw failure;
          },
        ),
      );
    expect(migration.runMigrations, throwsA(same(failure)));
    expect(version(), 0);
    expect(hasPayload(), isFalse);
    expect(history(), isEmpty);
  });

  test('an existing committed history gap is not silently certified', () {
    final steps = migrations();
    manager(steps).runMigrations();
    db.execute('DELETE FROM migrations_history');
    reopen();
    expect(
      manager(steps).runMigrations,
      throwsA(isA<HistoryInconsistencyException>()),
    );
    expect(version(), 1);
    expect(db.select('SELECT value FROM payload').single['value'], 'preserved');
    expect(history(), isEmpty);
  });

  test('failure observers cannot replace the original operation error', () {
    final failure = StateError('original operation failure');
    final migration = manager(migrations(beforeFinish: () => throw failure))
      ..addProgressListener(
        MigrationProgressListener(
          onEvent: (event) {
            if (event is MigrationFailedEvent) {
              throw StateError('observer failure');
            }
          },
        ),
      );
    expect(migration.runMigrations, throwsA(same(failure)));
    expect(version(), 0);
    expect(hasPayload(), isFalse);
    expect(history().single['success'], 0);
  });

  test('a failed BEGIN does not roll back the caller transaction', () {
    final migration = manager(migrations());
    db.execute('BEGIN TRANSACTION');
    db.execute('CREATE TABLE caller_owned (id INTEGER PRIMARY KEY)');
    expect(migration.runMigrations, throwsA(isA<SqliteException>()));
    expect(
      db.select(
        "SELECT name FROM sqlite_master WHERE name='caller_owned'",
      ),
      hasLength(1),
    );
    expect(history(), isEmpty);
    db.execute('ROLLBACK');
    expect(
      db.select(
        "SELECT name FROM sqlite_master WHERE name='caller_owned'",
      ),
      isEmpty,
    );
  });

  test('an unconfirmed rollback retains both errors', () {
    final failure = StateError('migration violated transaction ownership');
    final migration = manager(
      migrations(
        beforeFinish: () {
          db.execute('ROLLBACK');
          throw failure;
        },
      ),
    );
    expect(
      migration.runMigrations,
      throwsA(
        isA<MigrationRollbackException>()
            .having((error) => error.operationError, 'operation', same(failure))
            .having(
              (error) => error.rollbackError,
              'rollback',
              isA<SqliteException>(),
            ),
      ),
    );
    expect(version(), 0);
    expect(hasPayload(), isFalse);
    expect(history(), isEmpty);
  });

  test(
    'a later failure rolls back earlier success history as well as schema',
    () {
      var fail = true;
      final failure = StateError('second migration failed');
      final steps = [
        ...migrations(),
        BasicMigration(
          version: 2,
          onUp: (context) {
            context.execute('ALTER TABLE payload ADD COLUMN extra TEXT');
            if (fail) throw failure;
          },
        ),
      ];
      DbMigrationManager build() => DbMigrationManager.create(
        db: db,
        targetVersion: 2,
        migrations: steps,
      );
      expect(build().runMigrations, throwsA(same(failure)));
      expect(version(), 0);
      expect(hasPayload(), isFalse);
      expect(history().map((row) => row['version']), [2]);
      expect(history().single['success'], 0);
      fail = false;
      build().runMigrations();
      reopen();
      expect(build().runMigrations, returnsNormally);
      expect(version(), 2);
      expect(history(), [
        {'version': 1, 'success': 1, 'error_message': null},
        {'version': 2, 'success': 1, 'error_message': null},
      ]);
      expect(
        db.select('SELECT value FROM payload').single['value'],
        'preserved',
      );
    },
  );

  test('explicit repair can replace a failed history entry', () {
    manager(migrations()).runMigrations();
    db.execute(
      "UPDATE migrations_history SET success=0, error_message='old diagnostic'",
    );
    final repair = DbMigrationManager.create(
      db: db,
      targetVersion: 1,
      mode: MigrationMode.repair,
      migrations: [
        BasicMigration(
          version: 1,
          onUp: (_) {
            fail('History repair must not rerun the schema migration');
          },
        ),
      ],
    );
    expect(repair.runMigrations, returnsNormally);
    expect(history(), [
      {'version': 1, 'success': 1, 'error_message': null},
    ]);
    expect(db.select('SELECT value FROM payload').single['value'], 'preserved');
  });
}
