// Project imports:
import '../../sources/json_source.dart';
import '../../types/backup_data_source.dart';
import '../models/export_selection.dart';
import 'export_import_source.dart';

typedef ExportScopeBuilder =
    BackupExportScope? Function(
      ExportNodeSelection selection,
    );
typedef ExportJsonTransformer =
    String Function(
      String json,
      bool includeCredentials,
    );

class LegacyJsonSourceAdapter<T> implements ExportImportSource {
  const LegacyJsonSourceAdapter({
    required this.source,
    this.descriptor,
    this.scopeBuilder,
    this.transformer,
  });

  final JsonBackupSource<T> source;
  final ExportSelectionDescriptor? descriptor;
  final ExportScopeBuilder? scopeBuilder;
  final ExportJsonTransformer? transformer;

  @override
  String get id => source.id;

  @override
  int get priority => source.priority;

  @override
  int get schemaVersion => source.version;

  @override
  ExportSelectionDescriptor get selectionDescriptor =>
      descriptor ?? ExportSelectionDescriptor.leaf(id: id);

  @override
  Future<ExportSourceSnapshot> capture(ExportSourceRequest request) async {
    final scope = scopeBuilder?.call(request.selection);
    var json = await source.encodeForExport(
      options: scope == null ? null : BackupExportOptions(scope: scope),
    );
    json = transformer?.call(json, request.includeCredentials) ?? json;
    return ExportSourceSnapshot.json(
      sourceId: id,
      schemaVersion: schemaVersion,
      json: json,
    );
  }
}
