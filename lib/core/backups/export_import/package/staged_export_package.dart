// Project imports:
import '../../../../foundation/filesystem.dart';
import '../models/package_manifest.dart';

final class StagedExportPackage {
  StagedExportPackage({
    required this.manifest,
    required this.directoryPath,
    required AppFileSystem fs,
  }) : _fs = fs;

  final ExportPackageManifest manifest;
  final String directoryPath;
  final AppFileSystem _fs;
  var _disposed = false;

  String pathFor(String relativePath) {
    if (!isSafeExportPartPath(relativePath)) {
      throw ArgumentError.value(relativePath, 'relativePath');
    }
    return '$directoryPath/$relativePath';
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (await _fs.directoryExists(directoryPath)) {
      await _fs.deleteDirectory(directoryPath, recursive: true);
    }
  }
}
