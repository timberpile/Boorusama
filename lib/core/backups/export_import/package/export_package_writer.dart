// Dart imports:
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

// Project imports:
import '../../../../foundation/filesystem.dart';
import '../models/package_manifest.dart';

typedef ExportPartWriter = Future<void> Function(String path);

final class ExportPackagePartBuild {
  const ExportPackagePartBuild({required this.path, required this.write});

  final String path;
  final ExportPartWriter write;
}

final class ExportPackageSourceBuild {
  const ExportPackageSourceBuild({
    required this.id,
    required this.schemaVersion,
    required this.parts,
  });

  final String id;
  final int schemaVersion;
  final List<ExportPackagePartBuild> parts;
}

final class ExportPackageBuild {
  const ExportPackageBuild({
    required this.createdAt,
    required this.appVersion,
    required this.sources,
  });

  final DateTime createdAt;
  final String appVersion;
  final List<ExportPackageSourceBuild> sources;
}

class ExportPackageWriter {
  const ExportPackageWriter({required this.fs});

  final AppFileSystem fs;

  Future<String> write(ExportPackageBuild build, String requestedPath) async {
    final outputPath = requestedPath.endsWith(kExportPackageExtension)
        ? requestedPath
        : '$requestedPath$kExportPackageExtension';
    final temporaryOutput = '$outputPath.tmp';
    if (await fs.fileExists(outputPath)) {
      throw StateError('The export destination already exists');
    }
    if (await fs.fileExists(temporaryOutput)) {
      await fs.deleteFile(temporaryOutput);
    }

    final stagingPath = await fs.createTempDirectory('boorusama_export_');
    try {
      final seenSourceIds = <String>{};
      final seenPaths = <String>{};
      final sourceManifests = <ExportSourceManifest>[];
      for (final source in build.sources) {
        if (!seenSourceIds.add(source.id) || source.schemaVersion < 1) {
          throw ArgumentError('Invalid or repeated export source');
        }
        final partManifests = <ExportPartManifest>[];
        for (final part in source.parts) {
          if (!isSafeExportPartPath(part.path) ||
              part.path == 'manifest.json' ||
              !seenPaths.add(part.path)) {
            throw ArgumentError.value(part.path, 'path', 'Invalid part path');
          }
          final filePath = p.joinAll([stagingPath, ...part.path.split('/')]);
          await fs.createDirectory(p.dirname(filePath), recursive: true);
          await part.write(filePath);
          if (!await fs.fileExists(filePath)) {
            throw StateError('Export part was not written: ${part.path}');
          }
          final digest = await sha256.bind(fs.openRead(filePath)).first;
          partManifests.add(
            ExportPartManifest(
              path: part.path,
              sha256: digest.toString(),
              byteLength: await fs.fileSize(filePath),
            ),
          );
        }
        sourceManifests.add(
          ExportSourceManifest(
            id: source.id,
            schemaVersion: source.schemaVersion,
            parts: partManifests,
          ),
        );
      }

      final manifest = ExportPackageManifest(
        createdAt: build.createdAt,
        appVersion: build.appVersion,
        sources: sourceManifests,
      );
      final manifestPath = p.join(stagingPath, 'manifest.json');
      await fs.writeString(manifestPath, jsonEncode(manifest.toJson()));

      final encoder = ZipFileEncoder()..create(temporaryOutput);
      try {
        for (final source in sourceManifests) {
          for (final part in source.parts) {
            await encoder.addFile(
              File(p.joinAll([stagingPath, ...part.path.split('/')])),
              part.path,
            );
          }
        }
        await encoder.addFile(File(manifestPath), 'manifest.json');
        await encoder.close();
      } catch (_) {
        try {
          await encoder.close();
        } catch (_) {}
        rethrow;
      }
      await fs.renameFile(temporaryOutput, outputPath);
      return outputPath;
    } finally {
      if (await fs.directoryExists(stagingPath)) {
        await fs.deleteDirectory(stagingPath, recursive: true);
      }
      if (await fs.fileExists(temporaryOutput)) {
        await fs.deleteFile(temporaryOutput);
      }
    }
  }
}
