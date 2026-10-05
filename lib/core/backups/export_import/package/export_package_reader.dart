// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

// Project imports:
import '../../../../foundation/filesystem.dart';
import '../models/package_manifest.dart';
import 'export_package_exception.dart';
import 'export_package_limits.dart';
import 'staged_export_package.dart';

class ExportPackageReader {
  const ExportPackageReader({
    required this.fs,
    this.limits = const ExportPackageLimits(),
  });

  final AppFileSystem fs;
  final ExportPackageLimits limits;

  Future<StagedExportPackage> stage(String packagePath) async {
    String? stagingPath;
    InputFileStream? input;
    Archive? archive;
    try {
      input = InputFileStream(packagePath);
      final decoder = ZipDecoder();
      archive = decoder.decodeStream(input);
      _validateHeaders(decoder);
      if (archive.files.any(
        (entry) => !entry.isFile || entry.isSymbolicLink,
      )) {
        throw const ExportPackageException(
          'Directories and symbolic links are unsupported',
        );
      }

      final manifestEntry = archive.find('manifest.json');
      if (manifestEntry == null ||
          !manifestEntry.isFile ||
          manifestEntry.size > limits.maxManifestBytes) {
        throw const ExportPackageException('Missing or oversized manifest');
      }
      final manifestBytes = manifestEntry.readBytes();
      if (manifestBytes == null) {
        throw const ExportPackageException('Manifest cannot be read');
      }
      final decoded = jsonDecode(utf8.decode(manifestBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const ExportPackageException('Manifest is not an object');
      }
      final manifest = ExportPackageManifest.fromJson(decoded);
      final parts = {
        for (final source in manifest.sources)
          for (final part in source.parts) part.path: part,
      };
      final declaredPartCount = manifest.sources.fold<int>(
        0,
        (total, source) => total + source.parts.length,
      );
      if (parts.length != declaredPartCount) {
        throw const ExportPackageException('Manifest repeats a part path');
      }
      final archivePaths = decoder.directory.fileHeaders
          .map((header) => header.filename)
          .toSet();
      if (archivePaths.length != parts.length + 1 ||
          !archivePaths.contains('manifest.json') ||
          !archivePaths.containsAll(parts.keys)) {
        throw const ExportPackageException(
          'Archive entries do not match the manifest',
        );
      }

      stagingPath = await fs.createTempDirectory('boorusama_import_');
      for (final entry in parts.entries) {
        final archiveFile = archive.find(entry.key);
        if (archiveFile == null || !archiveFile.isFile) {
          throw const ExportPackageException('Declared part is missing');
        }
        final outputPath = p.joinAll([
          stagingPath,
          ...entry.key.split('/'),
        ]);
        await fs.createDirectory(p.dirname(outputPath), recursive: true);
        final output = OutputFileStream(outputPath);
        try {
          archiveFile.writeContent(output);
        } finally {
          await output.close();
        }
        final byteLength = await fs.fileSize(outputPath);
        final digest = await sha256.bind(fs.openRead(outputPath)).first;
        if (byteLength != entry.value.byteLength ||
            digest.toString() != entry.value.sha256) {
          throw ExportPackageException(
            'Part verification failed: ${entry.key}',
          );
        }
      }

      final staged = StagedExportPackage(
        manifest: manifest,
        directoryPath: stagingPath,
        fs: fs,
      );
      stagingPath = null;
      return staged;
    } on ExportPackageException {
      rethrow;
    } on FormatException catch (error) {
      throw ExportPackageException('Invalid export package', cause: error);
    } catch (error) {
      throw ExportPackageException(
        'Unable to read export package',
        cause: error,
      );
    } finally {
      if (archive != null) await archive.clear();
      if (input != null) await input.close();
      if (stagingPath != null && await fs.directoryExists(stagingPath)) {
        await fs.deleteDirectory(stagingPath, recursive: true);
      }
    }
  }

  void _validateHeaders(ZipDecoder decoder) {
    final headers = decoder.directory.fileHeaders;
    if (headers.isEmpty || headers.length > limits.maxFileCount) {
      throw const ExportPackageException('Archive file count is invalid');
    }
    final paths = <String>{};
    var totalExpandedBytes = 0;
    for (final header in headers) {
      final path = header.filename;
      if (!isSafeExportPartPath(path) || !paths.add(path)) {
        throw ExportPackageException('Unsafe or repeated archive path: $path');
      }
      if ((header.generalPurposeBitFlag & 1) != 0) {
        throw const ExportPackageException(
          'Encrypted archives are unsupported',
        );
      }
      if (header.compressionMethod != 0 && header.compressionMethod != 8) {
        throw const ExportPackageException('Unsupported ZIP compression');
      }
      if (header.uncompressedSize < 0 ||
          header.uncompressedSize > limits.maxPartBytes) {
        throw const ExportPackageException('Archive entry is too large');
      }
      totalExpandedBytes += header.uncompressedSize;
      if (totalExpandedBytes > limits.maxExpandedBytes) {
        throw const ExportPackageException('Expanded archive is too large');
      }
      if (header.uncompressedSize > 0 &&
          (header.compressedSize == 0 ||
              header.uncompressedSize / header.compressedSize >
                  limits.maxExpansionRatio)) {
        throw const ExportPackageException('Archive expansion ratio is unsafe');
      }
    }
  }
}
