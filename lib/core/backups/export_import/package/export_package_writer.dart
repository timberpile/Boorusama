import 'package:foundation/performance.dart';

// Dart imports:
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

// Project imports:
import '../../../../foundation/filesystem.dart';
import '../models/export_selection.dart';
import '../models/import_action.dart';
import '../models/package_manifest.dart';
import 'bookmark_transfer_format.dart';
import 'export_package_limits.dart';

typedef ExportPartWriter = Future<void> Function(String path);
typedef ExportPartsPreparer = Future<List<String>> Function(String directory);

final class ExportPackagePartBuild {
  const ExportPackagePartBuild({required this.path, required this.write});

  final String path;
  final ExportPartWriter write;
}

final class ExportPackageSourceBuild {
  const ExportPackageSourceBuild({
    required this.id,
    required this.schemaVersion,
    this.selection,
    this.recommendedAction,
    this.itemRecommendedActions = const {},
    required this.parts,
    this.prepareParts,
  });

  final String id;
  final int schemaVersion;
  final ExportNodeSelection? selection;
  final ImportAction? recommendedAction;
  final Map<String, ImportAction> itemRecommendedActions;
  final List<ExportPackagePartBuild> parts;
  final ExportPartsPreparer? prepareParts;
}

final class ExportPackageBuild {
  const ExportPackageBuild({
    this.exportId,
    required this.createdAt,
    required this.appVersion,
    this.preset = ExportSelectionMode.custom,
    this.containsCredentials = false,
    required this.sources,
  });

  final String? exportId;
  final DateTime createdAt;
  final String appVersion;
  final ExportSelectionMode preset;
  final bool containsCredentials;
  final List<ExportPackageSourceBuild> sources;
}

class ExportPackageWriter {
  const ExportPackageWriter({required this.fs, this.uuid = const Uuid()});

  final AppFileSystem fs;
  final Uuid uuid;

  Future<String> write(ExportPackageBuild build, String requestedPath) async {
    final performanceSpan = performanceRecorder.begin(
      PerfOperation.exportPackage,
      PerfSpanKind.asyncWall,
      items: build.sources.length,
    );
    var performanceFailed = false;
    try {
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
          final generated = await source.prepareParts?.call(stagingPath);
          final paths = [
            for (final part in source.parts) (part.path, part.write),
            for (final path in generated ?? const <String>[]) (path, null),
          ];
          for (final (path, write) in paths) {
            if (!isSafeExportPartPath(path) ||
                path == 'manifest.json' ||
                !seenPaths.add(path)) {
              throw ArgumentError.value(path, 'path', 'Invalid part path');
            }
            final filePath = p.joinAll([stagingPath, ...path.split('/')]);
            if (write != null) {
              await fs.createDirectory(p.dirname(filePath), recursive: true);
              await write(filePath);
            }
            if (!await fs.fileExists(filePath)) {
              throw StateError('Export part was not written: $path');
            }
            final digest = await sha256.bind(fs.openRead(filePath)).first;
            partManifests.add(
              ExportPartManifest(
                path: path,
                sha256: digest.toString(),
                byteLength: await fs.fileSize(filePath),
              ),
            );
          }
          sourceManifests.add(
            ExportSourceManifest(
              id: source.id,
              schemaVersion: source.schemaVersion,
              selection: source.selection ?? ExportNodeSelection.all(source.id),
              recommendedAction: source.recommendedAction,
              itemRecommendedActions: source.itemRecommendedActions,
              parts: partManifests,
            ),
          );
        }

        final manifest = ExportPackageManifest(
          exportId: build.exportId ?? uuid.v4().toLowerCase(),
          createdAt: build.createdAt,
          appVersion: build.appVersion,
          preset: build.preset,
          containsCredentials: build.containsCredentials,
          sources: sourceManifests,
        );
        final manifestPath = p.join(stagingPath, 'manifest.json');
        await fs.writeString(manifestPath, jsonEncode(manifest.toJson()));

        final encoder = ZipFileEncoder()..create(temporaryOutput);
        try {
          for (final source in sourceManifests) {
            for (final part in source.parts) {
              final file = File(
                p.joinAll([stagingPath, ...part.path.split('/')]),
              );
              if (source.id == 'bookmarks' &&
                  isBookmarkTransferPart(part.path) &&
                  await _requiresStoredPart(file, part.byteLength)) {
                final input = InputFileStream(file.path);
                try {
                  encoder.addArchiveFile(
                    ArchiveFile.stream(part.path, input)
                      ..compression = CompressionType.none,
                  );
                } finally {
                  await input.close();
                }
              } else {
                await encoder.addFile(file, part.path);
              }
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
    } catch (_) {
      performanceFailed = true;
      rethrow;
    } finally {
      performanceSpan.finish(failed: performanceFailed);
    }
  }

  Future<bool> _requiresStoredPart(File file, int byteLength) async {
    final ratio = const ExportPackageLimits().maxExpansionRatio;
    final compressedBytes = await file
        .openRead()
        .transform(ZLibCodec(raw: true).encoder)
        .fold<int>(0, (total, bytes) => total + bytes.length);
    return byteLength > compressedBytes * ratio;
  }
}
