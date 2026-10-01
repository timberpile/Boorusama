// Dart imports:
import 'dart:io';

// Project imports:
import '../models/export_selection.dart';
import '../../sources/sqlite_source.dart';
import 'export_import_source.dart';

class LegacySqliteSourceAdapter implements ExportImportSource {
  const LegacySqliteSourceAdapter(this.source);

  final SqliteBackupSource source;

  @override
  String get id => source.id;

  @override
  int get priority => source.priority;

  @override
  int get schemaVersion => 1;

  @override
  ExportSelectionDescriptor get selectionDescriptor =>
      ExportSelectionDescriptor.leaf(id: id);

  @override
  Future<ExportSourceSnapshot> capture(ExportSourceRequest request) async {
    final sourcePath = await source.dbPathGetter();
    if (!File(sourcePath).existsSync()) {
      throw StateError('Database source is unavailable: $id');
    }
    return ExportSourceSnapshot(
      sourceId: id,
      schemaVersion: schemaVersion,
      parts: {
        'sources/$id/data.db': (path) => File(sourcePath).copy(path),
      },
    );
  }
}
