import 'dart:async';

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
  var _readers = 0;
  Completer<void>? _readersFinished;

  String pathFor(String relativePath) {
    if (!isSafeExportPartPath(relativePath)) {
      throw ArgumentError.value(relativePath, 'relativePath');
    }
    return '$directoryPath/$relativePath';
  }

  Future<T> read<T>(Future<T> Function() operation) async {
    if (_disposed) throw StateError('The staged export has been disposed');
    _readers++;
    try {
      return await operation();
    } finally {
      if (--_readers == 0) _readersFinished?.complete();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_readers != 0) await (_readersFinished = Completer<void>()).future;
    if (await _fs.directoryExists(directoryPath)) {
      await _fs.deleteDirectory(directoryPath, recursive: true);
    }
  }
}
