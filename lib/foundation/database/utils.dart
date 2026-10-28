// Package imports:
import 'package:path/path.dart' show join;
import 'package:sqlite3/sqlite3.dart';

// Project imports:
import '../filesystem.dart';
import '../loggers.dart';

mixin DatabaseUtilsMixin {
  Database get db;

  void transaction(void Function() action) {
    db.execute('BEGIN TRANSACTION');
    try {
      action();
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}

Future<Database?> createDb({
  required AppFileSystem fs,
  required String folderPath,
  required String name,
  Logger? logger,
}) async {
  try {
    await fs.createDirectory(folderPath, recursive: true);

    return sqlite3.open(join(folderPath, name));
  } on Exception catch (error, stackTrace) {
    logger?.handledError(
      'Database',
      'open_sqlite',
      error: error,
      stackTrace: stackTrace,
      outcome: 'database_unavailable',
    );
    return null;
  }
}
