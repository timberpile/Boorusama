// Dart imports:
import 'dart:convert';
import 'dart:io';

// Project imports:
import '../models/export_selection.dart';
import '../package/export_package_writer.dart';

final class ExportSourceRequest {
  const ExportSourceRequest({
    required this.selection,
    required this.includeCredentials,
  });

  final ExportNodeSelection selection;
  final bool includeCredentials;
}

final class ExportSourceSnapshot {
  const ExportSourceSnapshot({
    required this.sourceId,
    required this.schemaVersion,
    required this.parts,
  });

  factory ExportSourceSnapshot.json({
    required String sourceId,
    required int schemaVersion,
    required String json,
  }) => ExportSourceSnapshot(
    sourceId: sourceId,
    schemaVersion: schemaVersion,
    parts: {
      'sources/$sourceId/data.json': (path) =>
          File(path).writeAsBytes(utf8.encode(json)),
    },
  );

  final String sourceId;
  final int schemaVersion;
  final Map<String, ExportPartWriter> parts;

  ExportPackageSourceBuild toPackageBuild() => ExportPackageSourceBuild(
    id: sourceId,
    schemaVersion: schemaVersion,
    parts: [
      for (final entry in parts.entries)
        ExportPackagePartBuild(path: entry.key, write: entry.value),
    ],
  );
}

abstract interface class ExportImportSource {
  String get id;
  int get priority;
  int get schemaVersion;
  ExportSelectionDescriptor get selectionDescriptor;

  Future<ExportSourceSnapshot> capture(ExportSourceRequest request);
}
