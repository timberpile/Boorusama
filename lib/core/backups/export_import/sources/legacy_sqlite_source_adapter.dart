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
    await source.ensureInitializedForExport();
    return ExportSourceSnapshot(
      sourceId: id,
      schemaVersion: schemaVersion,
      parts: {
        'sources/$id/data.db': source.captureDatabase,
      },
    );
  }
}
