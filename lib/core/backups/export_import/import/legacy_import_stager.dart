import 'dart:convert';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../../../foundation/filesystem.dart';
import '../../zip/types.dart';
import '../models/import_action.dart';
import '../models/package_manifest.dart';
import '../package/export_package_exception.dart';
import '../package/export_package_limits.dart';
import '../package/export_package_reader.dart';
import '../package/export_package_writer.dart';
import '../package/staged_export_package.dart';

final class LegacyImportSourceDescriptor {
  const LegacyImportSourceDescriptor({
    required this.id,
    required this.schemaVersion,
  });

  final String id;
  final int schemaVersion;
}

final class LegacyImportStager {
  const LegacyImportStager({
    required this.fs,
    required this.sources,
    this.limits = const ExportPackageLimits(),
  });

  final AppFileSystem fs;
  final List<LegacyImportSourceDescriptor> sources;
  final ExportPackageLimits limits;

  Future<StagedExportPackage> stage(String path) async {
    final reader = ExportPackageReader(fs: fs, limits: limits);
    try {
      return await reader.stage(path);
    } on ExportPackageException {
      final extension = p.extension(path).toLowerCase();
      if (extension == '.bsexport') rethrow;
      final converted = switch (extension) {
        '.json' => await _convertJson(path),
        '.zip' => await _convertZip(path),
        _ => null,
      };
      if (converted == null) rethrow;
      try {
        return await reader.stage(converted.packagePath);
      } finally {
        await converted.dispose();
      }
    }
  }

  Future<_ConvertedLegacyPackage?> _convertJson(String path) async {
    final content = await fs.readString(path);
    final decoded = _jsonObject(content);
    final source = _identifyJsonSource(path, decoded);
    if (source == null) return null;
    final createdAt = switch (decoded?['date']) {
      final String value => DateTime.tryParse(value),
      _ => null,
    };
    final appVersion = switch (decoded?['exportVersion']) {
      final String value when value.trim().isNotEmpty => value,
      _ => 'legacy',
    };
    return _writeConverted(
      createdAt: createdAt ?? DateTime.now().toUtc(),
      appVersion: appVersion,
      payloads: [(source: source, path: path)],
    );
  }

  Future<_ConvertedLegacyPackage?> _convertZip(String path) async {
    InputFileStream? input;
    Archive? archive;
    String? extractionPath;
    try {
      input = InputFileStream(path);
      final decoder = ZipDecoder();
      archive = decoder.decodeStream(input);
      _validateHeaders(decoder);
      final manifestEntry = archive.find('manifest.json');
      if (manifestEntry == null ||
          !manifestEntry.isFile ||
          manifestEntry.size > limits.maxManifestBytes) {
        return null;
      }
      final manifestBytes = manifestEntry.readBytes();
      if (manifestBytes == null) return null;
      final manifestJson = jsonDecode(utf8.decode(manifestBytes));
      if (manifestJson is! Map<String, dynamic> ||
          !manifestJson.containsKey('sourceFiles')) {
        return null;
      }
      final manifest = BulkBackupManifest.fromJson(manifestJson);
      final declaredPaths = manifest.sourceFiles.values.toSet();
      if (declaredPaths.length != manifest.sourceFiles.length) {
        throw const ExportPackageException(
          'Legacy backup repeats a source path',
        );
      }
      final archivePaths = decoder.directory.fileHeaders
          .map((header) => header.filename)
          .toSet();
      if (archivePaths.length != declaredPaths.length + 1 ||
          !archivePaths.contains('manifest.json') ||
          !archivePaths.containsAll(declaredPaths)) {
        throw const ExportPackageException(
          'Legacy archive entries do not match the manifest',
        );
      }

      final descriptors = {for (final source in sources) source.id: source};
      extractionPath = await fs.createTempDirectory('boorusama_legacy_');
      final payloads = <({LegacyImportSourceDescriptor source, String path})>[];
      for (final entry in manifest.sourceFiles.entries) {
        final source = descriptors[entry.key];
        if (source == null) continue;
        final archiveFile = archive.find(entry.value);
        if (archiveFile == null || !archiveFile.isFile) {
          throw const ExportPackageException(
            'Legacy backup source is missing',
          );
        }
        final extension = p.extension(entry.value).toLowerCase();
        final outputPath = p.join(
          extractionPath,
          '${source.id}${extension == '.db' ? '.db' : '.json'}',
        );
        final output = OutputFileStream(outputPath);
        try {
          archiveFile.writeContent(output);
        } finally {
          await output.close();
        }
        payloads.add((source: source, path: outputPath));
      }
      if (payloads.isEmpty) {
        throw const ExportPackageException(
          'Legacy backup has no supported sources',
        );
      }
      final converted = await _writeConverted(
        createdAt: manifest.exportDate.toUtc(),
        appVersion: manifest.appVersion ?? 'legacy',
        payloads: payloads,
      );
      await fs.deleteDirectory(extractionPath, recursive: true);
      extractionPath = null;
      return converted;
    } on ExportPackageException {
      rethrow;
    } on FormatException catch (error) {
      throw ExportPackageException('Invalid legacy backup', cause: error);
    } catch (error) {
      throw ExportPackageException(
        'Unable to read legacy backup',
        cause: error,
      );
    } finally {
      if (archive != null) await archive.clear();
      if (input != null) await input.close();
      if (extractionPath != null && await fs.directoryExists(extractionPath)) {
        await fs.deleteDirectory(extractionPath, recursive: true);
      }
    }
  }

  Future<_ConvertedLegacyPackage> _writeConverted({
    required DateTime createdAt,
    required String appVersion,
    required List<({LegacyImportSourceDescriptor source, String path})>
    payloads,
  }) async {
    final directory = await fs.createTempDirectory('boorusama_converted_');
    try {
      final packagePath = await ExportPackageWriter(fs: fs).write(
        ExportPackageBuild(
          createdAt: createdAt,
          appVersion: appVersion,
          containsCredentials: payloads.any(
            (payload) => payload.source.id == 'profiles',
          ),
          sources: [
            for (final payload in payloads)
              ExportPackageSourceBuild(
                id: payload.source.id,
                schemaVersion: payload.source.schemaVersion,
                recommendedAction: ImportAction.replace,
                parts: [
                  ExportPackagePartBuild(
                    path:
                        'sources/${payload.source.id}/data${p.extension(payload.path).toLowerCase() == '.db' ? '.db' : '.json'}',
                    write: (outputPath) =>
                        fs.copyFile(payload.path, outputPath),
                  ),
                ],
              ),
          ],
        ),
        p.join(directory, 'converted'),
      );
      return _ConvertedLegacyPackage(
        packagePath: packagePath,
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

  LegacyImportSourceDescriptor? _identifyJsonSource(
    String path,
    Map<String, dynamic>? json,
  ) {
    final byId = {for (final source in sources) source.id: source};
    if (json?['source'] case final String id) {
      if (byId[id] case final source?) return source;
    }
    final name = p.basename(path);
    for (final source in sources) {
      if (name.startsWith('boorusama_${source.id}_')) return source;
    }
    return null;
  }

  Map<String, dynamic>? _jsonObject(String content) {
    try {
      return switch (jsonDecode(content)) {
        final Map<String, dynamic> value => value,
        _ => null,
      };
    } catch (_) {
      return null;
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

final class _ConvertedLegacyPackage {
  const _ConvertedLegacyPackage({
    required this.packagePath,
    required this.directoryPath,
    required this.fs,
  });

  final String packagePath;
  final String directoryPath;
  final AppFileSystem fs;

  Future<void> dispose() async {
    if (await fs.directoryExists(directoryPath)) {
      await fs.deleteDirectory(directoryPath, recursive: true);
    }
  }
}
