// Project imports:
import '../models/export_selection.dart';
import '../package/export_package_writer.dart';
import '../sources/export_import_source.dart';

final class ExportRequest {
  const ExportRequest({
    required this.selection,
    required this.outputPath,
    this.includeCredentials = false,
  });

  final ExportSelection selection;
  final String outputPath;
  final bool includeCredentials;
}

class ExportService {
  const ExportService({
    required this.sources,
    required this.writer,
    required this.appVersion,
  });

  final List<ExportImportSource> Function() sources;
  final ExportPackageWriter writer;
  final String appVersion;

  Future<String> createPackage(ExportRequest request) async {
    final currentSources = {
      for (final source in sources()) source.id: source,
    };
    final selectedIds = request.selection.sourceIds;
    final missing = selectedIds.difference(currentSources.keys.toSet());
    if (missing.isNotEmpty) {
      throw StateError('Export sources are unavailable: ${missing.join(', ')}');
    }
    final selected = [
      for (final id in selectedIds) currentSources[id]!,
    ]..sort((a, b) => a.priority.compareTo(b.priority));
    final includeCredentials =
        request.selection.mode == ExportSelectionMode.full ||
        request.includeCredentials;
    final snapshots = <ExportSourceSnapshot>[];
    for (final source in selected) {
      final selection =
          request.selection.nodes[source.id] ??
          ExportNodeSelection.all(source.id);
      snapshots.add(
        await source.capture(
          ExportSourceRequest(
            selection: selection,
            includeCredentials: includeCredentials,
          ),
        ),
      );
    }
    return writer.write(
      ExportPackageBuild(
        createdAt: DateTime.now().toUtc(),
        appVersion: appVersion,
        sources: snapshots
            .map((snapshot) => snapshot.toPackageBuild())
            .toList(),
      ),
      request.outputPath,
    );
  }
}
