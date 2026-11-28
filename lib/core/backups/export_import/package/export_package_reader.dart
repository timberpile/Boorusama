import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../../foundation/filesystem.dart';
import '../import/import_progress.dart';
import '../models/package_manifest.dart';
import 'bookmark_transfer_format.dart';
import 'export_package_exception.dart';
import 'export_package_limits.dart';
import 'staged_export_package.dart';

class ExportPackageReader {
  const ExportPackageReader({
    required this.fs,
    this.limits = const ExportPackageLimits(separateBookmarkBudget: true),
  });

  final AppFileSystem fs;
  final ExportPackageLimits limits;

  Future<StagedExportPackage> stage(String packagePath) async {
    ImportProgress.current?.show(ImportProgressPhase.opening);
    final stagingPath = await fs.createTempDirectory('boorusama_import_');
    try {
      final task = _ExtractPackage(packagePath, stagingPath, limits);
      final manifest = await runImportWorker(task.run);
      return StagedExportPackage(
        manifest: manifest,
        directoryPath: stagingPath,
        fs: fs,
      );
    } catch (_) {
      if (await fs.directoryExists(stagingPath)) {
        await fs.deleteDirectory(stagingPath, recursive: true);
      }
      rethrow;
    }
  }
}

final class _ExtractPackage {
  const _ExtractPackage(this.packagePath, this.stagingPath, this.limits);

  final String packagePath;
  final String stagingPath;
  final ExportPackageLimits limits;

  Future<ExportPackageManifest> run() async {
    final progress = ImportProgress.current;
    void checkCancelled() {
      if (progress?.cancelled ?? false) {
        throw const ExportPackageException('Import cancelled');
      }
    }

    InputFileStream? input;
    try {
      input = InputFileStream(packagePath);
      final directory = ZipDirectory()..read(input);
      if (directory.fileHeaders.length >
          limits.maxFileCount +
              (limits.separateBookmarkBudget ? bookmarkTransferPartCount : 0)) {
        throw const ExportPackageLimitException('Too many archive entries');
      }
      final headers = <String, ZipFileHeader>{};
      for (final header in directory.fileHeaders) {
        _validateHeader(header);
        if (headers.containsKey(header.filename)) {
          throw const ExportPackageException('Repeated archive path');
        }
        headers[header.filename] = header;
      }

      final manifestEntry = headers.remove('manifest.json');
      if (manifestEntry == null ||
          manifestEntry.uncompressedSize > limits.maxManifestBytes) {
        throw const ExportPackageException('Missing or oversized manifest');
      }
      final manifestBytes = BytesBuilder(copy: false);
      _extract(manifestEntry, manifestBytes.add);
      final decoded = jsonDecode(utf8.decode(manifestBytes.takeBytes()));
      if (decoded is! Map<String, dynamic>) {
        throw const ExportPackageException('Manifest is not an object');
      }
      final manifest = ExportPackageManifest.fromJson(decoded);
      final parts = <String, ExportPartManifest>{};
      final streamed = <String>{};
      for (final source in manifest.sources) {
        final tables = bookmarkTransferParts(source);
        if (tables != null) {
          streamed.addAll(source.parts.map((part) => part.path));
        }
        for (final part in source.parts) {
          final header = headers[part.path];
          if (parts.containsKey(part.path) ||
              header == null ||
              header.uncompressedSize != part.byteLength) {
            throw const ExportPackageException(
              'Archive entries do not match the manifest',
            );
          }
          parts[part.path] = part;
        }
      }
      if (parts.length != headers.length) {
        throw const ExportPackageException(
          'Archive entries do not match the manifest',
        );
      }

      var generalBytes = manifestEntry.uncompressedSize;
      var generalFiles = 1;
      var bookmarkBytes = 0;
      var bytes = 0;
      for (final part in parts.values) {
        bytes += part.byteLength;
        if (streamed.contains(part.path)) {
          bookmarkBytes += part.byteLength;
          if (part.byteLength > bookmarkTransferPartBytes) {
            throw const ExportPackageLimitException(
              'Bookmark part is too large',
            );
          }
          if (limits.separateBookmarkBudget) continue;
        }
        generalFiles++;
        generalBytes += part.byteLength;
        if (part.byteLength > limits.maxPartBytes) {
          throw const ExportPackageLimitException('Archive entry is too large');
        }
      }
      if (streamed.length > bookmarkTransferPartCount ||
          generalFiles > limits.maxFileCount) {
        throw const ExportPackageLimitException('Too many archive entries');
      }
      if (generalBytes > limits.maxExpandedBytes ||
          bookmarkBytes > bookmarkTransferExpandedBytes) {
        throw const ExportPackageLimitException(
          'Expanded archive is too large',
        );
      }

      var extracted = 0;
      progress?.show(ImportProgressPhase.extracting, total: bytes);
      for (final part in parts.values) {
        final outputPath = p.joinAll([stagingPath, ...part.path.split('/')]);
        await Directory(p.dirname(outputPath)).create(recursive: true);
        checkCancelled();
        final output = OutputFileStream(outputPath);
        try {
          _extract(headers[part.path]!, (chunk) {
            output.writeBytes(chunk);
            extracted += chunk.length;
            progress?.show(
              ImportProgressPhase.extracting,
              completed: extracted,
              total: bytes,
            );
          });
        } finally {
          await output.close();
        }
      }

      var verified = 0;
      progress?.show(ImportProgressPhase.verifying, total: bytes);
      for (final part in parts.values) {
        final outputPath = p.joinAll([stagingPath, ...part.path.split('/')]);
        final digest = await sha256
            .bind(
              File(outputPath).openRead().map((chunk) {
                checkCancelled();
                verified += chunk.length;
                progress?.show(
                  ImportProgressPhase.verifying,
                  completed: verified,
                  total: bytes,
                );
                return chunk;
              }),
            )
            .first;
        if (digest.toString() != part.sha256) {
          throw const ExportPackageException('Part verification failed');
        }
      }
      return manifest;
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
      if (input != null) await input.close();
    }
  }

  void _validateHeader(ZipFileHeader header) {
    final path = header.filename;
    final file = header.file;
    if (!isSafeExportPartPath(path) || file == null || file.filename != path) {
      throw const ExportPackageException('Invalid archive path');
    }
    final mode = (header.externalFileAttributes >> 16) & 0xf000;
    if (mode == 0xa000 ||
        mode == 0x4000 ||
        path.endsWith('/') ||
        (header.externalFileAttributes & 0x10) != 0) {
      throw const ExportPackageException(
        'Directories and symbolic links are unsupported',
      );
    }
    if (((header.generalPurposeBitFlag | file.flags) & 1) != 0) {
      throw const ExportPackageException('Encrypted archives are unsupported');
    }
    final method = switch (header.compressionMethod) {
      0 => CompressionType.none,
      8 => CompressionType.deflate,
      _ => throw const ExportPackageException('Unsupported ZIP compression'),
    };
    if (method != file.compressionMethod ||
        header.uncompressedSize < 0 ||
        header.compressedSize < 0 ||
        header.compressedSize != file.compressedSize ||
        header.uncompressedSize != file.uncompressedSize) {
      throw const ExportPackageException('Invalid ZIP entry header');
    }
    if (header.uncompressedSize > 0 &&
        (header.compressedSize == 0 ||
            header.uncompressedSize / header.compressedSize >
                limits.maxExpansionRatio)) {
      throw const ExportPackageException('Archive expansion ratio is unsafe');
    }
  }
}

void _extract(ZipFileHeader header, void Function(List<int>) write) {
  final file = header.file!;
  final input = file.getStream(decompress: false);
  if (input.length != header.compressedSize) {
    throw const ExportPackageException('Incomplete ZIP entry');
  }
  final output = _ZipOutput(header.uncompressedSize, write);
  final sink = file.compressionMethod == CompressionType.deflate
      ? ZLibCodec(raw: true).decoder.startChunkedConversion(output)
      : output;
  const chunkSize = 64 * 1024;
  while (!input.isEOS) {
    sink.add(
      input
          .readBytes(input.length < chunkSize ? input.length : chunkSize)
          .toUint8List(),
    );
  }
  sink.close();
  if (output.written != header.uncompressedSize || output.crc != header.crc32) {
    throw const ExportPackageException('Invalid ZIP entry content');
  }
}

final class _ZipOutput extends ByteConversionSink {
  _ZipOutput(this.limit, this.write);

  final int limit;
  final void Function(List<int>) write;
  var written = 0;
  var crc = 0;

  @override
  void add(List<int> chunk) {
    if (written + chunk.length > limit) {
      throw const ExportPackageLimitException(
        'Expanded ZIP entry exceeds its declared size',
      );
    }
    written += chunk.length;
    crc = getCrc32(chunk, crc);
    write(chunk);
  }

  @override
  void close() {}
}
