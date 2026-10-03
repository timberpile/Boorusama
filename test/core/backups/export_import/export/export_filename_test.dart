import 'dart:io';

import 'package:boorusama/core/backups/export_import/export/export_filename.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('export filename uses the UTC time encoded in the date', () {
    expect(
      exportFileName(DateTime.parse('2026-10-03T14:05:06+02:00')),
      'boorusama-2026-10-03_12-05-06Z.bsexport',
    );
  });

  test('saving again in the same second keeps both exports', () {
    const name = 'boorusama-2026-10-03_12-05-06Z.bsexport';
    final occupied = {
      p.join('/exports', name),
      p.join('/exports', 'boorusama-2026-10-03_12-05-06Z-2.bsexport'),
    };

    expect(
      nextAvailableExportPath('/exports', name, occupied.contains),
      p.join('/exports', 'boorusama-2026-10-03_12-05-06Z-3.bsexport'),
    );
  });

  test(
    'concurrent saves keep both files without changing an existing export',
    () async {
      final directory = await Directory.systemTemp.createTemp('export_names_');
      addTearDown(() => directory.delete(recursive: true));
      final source = File(p.join(directory.path, 'source.bsexport'));
      await source.writeAsString('new export');
      final destination = Directory(p.join(directory.path, 'saved'));
      await destination.create();
      final name = exportFileName(DateTime.utc(2026, 10, 3, 12, 5, 6));
      final namedSource = await source.copy(p.join(directory.path, name));
      final original = File(p.join(destination.path, name));
      await original.writeAsString('original export');

      final saved = await Future.wait([
        copyExportToDirectory(
          const IoFileSystem(),
          namedSource.path,
          destination.path,
        ),
        copyExportToDirectory(
          const IoFileSystem(),
          namedSource.path,
          destination.path,
        ),
      ]);

      expect(saved.map(p.basename).toSet(), {
        'boorusama-2026-10-03_12-05-06Z-2.bsexport',
        'boorusama-2026-10-03_12-05-06Z-3.bsexport',
      });
      expect(await original.readAsString(), 'original export');
      for (final path in saved) {
        expect(await File(path).readAsString(), 'new export');
      }
    },
  );
}
