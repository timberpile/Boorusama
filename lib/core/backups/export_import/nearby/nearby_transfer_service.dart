import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../../foundation/filesystem.dart';
import '../export/export_filename.dart';
import '../export/export_service.dart';
import '../models/export_selection.dart';

final class NearbyExportPackage {
  const NearbyExportPackage({
    required this.path,
    required this.directoryPath,
    required this.fs,
  });

  final String path;
  final String directoryPath;
  final AppFileSystem fs;

  Future<void> dispose() async {
    if (await fs.directoryExists(directoryPath)) {
      await fs.deleteDirectory(directoryPath, recursive: true);
    }
  }
}

final class NearbyExportService {
  const NearbyExportService({
    required this.exportService,
    required this.catalog,
    required this.fs,
  });

  final ExportService exportService;
  final ExportSourceCatalog catalog;
  final AppFileSystem fs;

  Future<NearbyExportPackage> createFullPackage() async {
    final directory = await fs.createTempDirectory('boorusama_nearby_');
    final outputPath = p.join(directory, exportFileName(DateTime.now()));
    try {
      final path = await exportService.createPackage(
        ExportRequest(
          selection: ExportSelection.full(catalog),
          outputPath: outputPath,
        ),
      );
      return NearbyExportPackage(
        path: path,
        directoryPath: directory,
        fs: fs,
      );
    } catch (_) {
      if (await fs.directoryExists(directory)) {
        await fs.deleteDirectory(directory, recursive: true);
      }
      rethrow;
    }
  }
}

final class NearbyImportService {
  const NearbyImportService({required this.dio, required this.fs});

  final Dio dio;
  final AppFileSystem fs;

  Future<NearbyReceivedPackage> download(String serverUrl) async {
    final directory = await fs.createTempDirectory('boorusama_nearby_');
    final outputPath = '$directory/received.bsexport';
    try {
      final base = Uri.parse(
        serverUrl.endsWith('/') ? serverUrl : '$serverUrl/',
      );
      await dio.downloadUri(base.resolve('export'), outputPath);
      if (!await fs.fileExists(outputPath) ||
          await fs.fileSize(outputPath) == 0) {
        throw StateError('The nearby export is empty');
      }
      return NearbyReceivedPackage(
        path: outputPath,
        directoryPath: directory,
        fs: fs,
      );
    } catch (_) {
      if (await fs.directoryExists(directory)) {
        await fs.deleteDirectory(directory, recursive: true);
      }
      rethrow;
    }
  }
}

final class NearbyReceivedPackage {
  const NearbyReceivedPackage({
    required this.path,
    required this.directoryPath,
    required this.fs,
  });

  final String path;
  final String directoryPath;
  final AppFileSystem fs;

  Future<void> dispose() async {
    if (await fs.directoryExists(directoryPath)) {
      await fs.deleteDirectory(directoryPath, recursive: true);
    }
  }
}

final class NearbyExportCatalog implements ExportSourceCatalog {
  const NearbyExportCatalog(this.selectionDescriptors);

  @override
  final List<ExportSelectionDescriptor> selectionDescriptors;
}
