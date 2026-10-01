import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:boorusama/core/backups/export_import/import/legacy_import_stager.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_exception.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late LegacyImportStager stager;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('legacy_import_');
    stager = const LegacyImportStager(
      fs: IoFileSystem(),
      sources: [
        LegacyImportSourceDescriptor(id: 'bookmarks', schemaVersion: 3),
        LegacyImportSourceDescriptor(id: 'settings', schemaVersion: 1),
      ],
    );
  });

  tearDown(() => directory.delete(recursive: true));

  test('converts a named legacy JSON export into a staged package', () async {
    final payload = jsonEncode({
      'version': 2,
      'date': '2025-01-02T03:04:05.000Z',
      'exportVersion': '1.4.0',
      'data': const [],
    });
    final path = '${directory.path}/boorusama_bookmarks_2025.01.02.json';
    await File(path).writeAsString(payload);

    final staged = await stager.stage(path);
    addTearDown(staged.dispose);

    expect(staged.manifest.sources.single.id, 'bookmarks');
    expect(
      staged.manifest.sources.single.recommendedAction,
      ImportAction.replace,
    );
    expect(
      await File(
        staged.pathFor(staged.manifest.sources.single.parts.single.path),
      ).readAsString(),
      payload,
    );
  });

  test('converts every known source in a legacy ZIP', () async {
    final path = '${directory.path}/backup.zip';
    final encoder = ZipFileEncoder()..create(path);
    encoder
      ..addArchiveFile(ArchiveFile.string('bookmarks.json', '{"data":[]}'))
      ..addArchiveFile(ArchiveFile.string('settings.json', '{"data":[]}'))
      ..addArchiveFile(
        ArchiveFile.string(
          'manifest.json',
          jsonEncode({
            'version': 1,
            'appVersion': '1.4.0',
            'exportDate': '2025-01-02T03:04:05.000Z',
            'sourceFiles': {
              'bookmarks': 'bookmarks.json',
              'settings': 'settings.json',
            },
            'failed': const [],
            'skipped': const [],
          }),
        ),
      );
    await encoder.close();

    final staged = await stager.stage(path);
    addTearDown(staged.dispose);

    expect(
      staged.manifest.sources.map((source) => source.id),
      ['bookmarks', 'settings'],
    );
    expect(
      staged.manifest.sources.map((source) => source.recommendedAction),
      everyElement(ImportAction.replace),
    );
  });

  test('rejects unsafe paths in a legacy ZIP before extraction', () async {
    final path = '${directory.path}/unsafe.zip';
    final encoder = ZipFileEncoder()..create(path);
    encoder
      ..addArchiveFile(ArchiveFile.string('../bookmarks.json', '{}'))
      ..addArchiveFile(
        ArchiveFile.string(
          'manifest.json',
          jsonEncode({
            'version': 1,
            'appVersion': '1.4.0',
            'exportDate': '2025-01-02T03:04:05.000Z',
            'sourceFiles': {'bookmarks': '../bookmarks.json'},
          }),
        ),
      );
    await encoder.close();

    await expectLater(
      stager.stage(path),
      throwsA(isA<ExportPackageException>()),
    );
  });
}
