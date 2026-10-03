// Dart imports:
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/backups/export_import/package/export_package_exception.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_limits.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/foundation/filesystem.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bsexport_reader_');
  });

  tearDown(() => directory.delete(recursive: true));

  test('stages only parts whose size and digest match the manifest', () async {
    final bytes = utf8.encode('bookmark payload');
    final path = _writeArchive(directory, {
      'sources/bookmarks/data.json': bytes,
    });

    final staged = await const ExportPackageReader(
      fs: IoFileSystem(),
    ).stage(path);
    addTearDown(staged.dispose);

    expect(
      await File(
        staged.pathFor('sources/bookmarks/data.json'),
      ).readAsString(),
      'bookmark payload',
    );
  });

  for (final path in ['../secret', '/absolute', 'sources/../secret']) {
    test('rejects unsafe archive path $path before extraction', () async {
      final archivePath = _writeRawArchive(directory, [
        ArchiveFile.string(path, 'bad'),
        ArchiveFile.string('manifest.json', '{}'),
      ]);
      await expectLater(
        const ExportPackageReader(fs: IoFileSystem()).stage(archivePath),
        throwsA(isA<ExportPackageException>()),
      );
    });
  }

  test('rejects duplicate archive paths before extraction', () async {
    final path = '${directory.path}/duplicate.bsexport';
    final encoder = ZipFileEncoder()..create(path);
    encoder.addArchiveFile(ArchiveFile.string('duplicate', 'one'));
    encoder.addArchiveFile(ArchiveFile.string('duplicate', 'two'));
    await encoder.close();

    await expectLater(
      const ExportPackageReader(fs: IoFileSystem()).stage(path),
      throwsA(isA<ExportPackageException>()),
    );
  });

  test('rejects encrypted entries before extraction', () async {
    final path = '${directory.path}/encrypted.bsexport';
    final encoder = ZipFileEncoder(password: 'secret')..create(path);
    encoder.addArchiveFile(ArchiveFile.string('manifest.json', '{}'));
    await encoder.close();

    await expectLater(
      const ExportPackageReader(fs: IoFileSystem()).stage(path),
      throwsA(isA<ExportPackageException>()),
    );
  });

  test('rejects unsupported compression before extraction', () async {
    final path = _writeRawArchive(directory, [
      ArchiveFile.string('manifest.json', '{}'),
    ]);
    final bytes = File(path).readAsBytesSync();
    _replaceCompressionMethods(bytes, 12);
    File(path).writeAsBytesSync(bytes);

    await expectLater(
      const ExportPackageReader(fs: IoFileSystem()).stage(path),
      throwsA(isA<ExportPackageException>()),
    );
  });

  test('rejects a digest mismatch', () async {
    final path = _writeArchive(
      directory,
      {'sources/bookmarks/data.json': utf8.encode('actual')},
      digestOverride: '0' * 64,
    );

    await expectLater(
      const ExportPackageReader(fs: IoFileSystem()).stage(path),
      throwsA(isA<ExportPackageException>()),
    );
  });

  test('rejects file count and expanded byte limits', () async {
    final path = _writeArchive(directory, {
      'sources/bookmarks/data.json': utf8.encode('payload'),
    });

    for (final limits in [
      const ExportPackageLimits(maxFileCount: 1),
      const ExportPackageLimits(maxExpandedBytes: 2),
    ]) {
      await expectLater(
        ExportPackageReader(
          fs: const IoFileSystem(),
          limits: limits,
        ).stage(path),
        throwsA(isA<ExportPackageException>()),
      );
    }
  });
}

String _writeArchive(
  Directory directory,
  Map<String, List<int>> parts, {
  String? digestOverride,
}) {
  final sources = [
    {
      'id': 'bookmarks',
      'schemaVersion': 3,
      'parts': [
        for (final entry in parts.entries)
          {
            'path': entry.key,
            'sha256': digestOverride ?? sha256.convert(entry.value).toString(),
            'byteLength': entry.value.length,
          },
      ],
    },
  ];
  return _writeRawArchive(directory, [
    for (final entry in parts.entries)
      ArchiveFile(entry.key, entry.value.length, entry.value),
    ArchiveFile.string(
      'manifest.json',
      jsonEncode({
        'formatVersion': 1,
        'createdAt': '2026-10-01T00:00:00.000Z',
        'appVersion': '1.2.3',
        'sources': sources,
      }),
    ),
  ]);
}

String _writeRawArchive(Directory directory, List<ArchiveFile> files) {
  final path = '${directory.path}/input.bsexport';
  final encoder = ZipFileEncoder()..create(path);
  files.forEach(encoder.addArchiveFile);
  encoder.closeSync();
  return path;
}

void _replaceCompressionMethods(List<int> bytes, int method) {
  for (var index = 0; index <= bytes.length - 10; index++) {
    final isLocal =
        bytes[index] == 0x50 &&
        bytes[index + 1] == 0x4b &&
        bytes[index + 2] == 0x03 &&
        bytes[index + 3] == 0x04;
    final isCentral =
        bytes[index] == 0x50 &&
        bytes[index + 1] == 0x4b &&
        bytes[index + 2] == 0x01 &&
        bytes[index + 3] == 0x02;
    if (isLocal) {
      bytes[index + 8] = method;
      bytes[index + 9] = 0;
    }
    if (isCentral) {
      bytes[index + 10] = method;
      bytes[index + 11] = 0;
    }
  }
}
