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

  test('custom names keep the extension and reject unsafe names', () {
    expect(
      normalizedExportFileName('  Favorites October  '),
      'Favorites October.bsexport',
    );
    expect(
      normalizedExportFileName('Favorites.bsexport'),
      'Favorites.bsexport',
    );
    expect(
      normalizedExportFileName('Favorites.BSEXPORT'),
      'Favorites.bsexport',
    );
    expect(exportFileNameStem('Favorites.bsexport'), 'Favorites');

    for (final invalid in [
      '',
      '.',
      '..',
      '.bsexport',
      '../other',
      r'folder\other',
      'a/b',
      'name:invalid',
      'name?',
      'report.',
      'Favorites .bsexport',
      'Favorites\t.bsexport',
      'CON',
      'nul.txt',
      'COM1',
      'LPT9',
      'a'.padRight(250, 'a'),
    ]) {
      expect(normalizedExportFileName(invalid), isNull, reason: invalid);
    }
  });

  test('saving with a custom name preserves existing files', () async {
    final root = await Directory.systemTemp.createTemp('named_export_');
    addTearDown(() => root.delete(recursive: true));
    final source = File(p.join(root.path, 'auto.bsexport'));
    await source.writeAsString('new export');
    final directory = Directory(p.join(root.path, 'exports'));
    await directory.create();
    final existing = File(p.join(directory.path, 'Favorites.bsexport'));
    await existing.writeAsString('old export');

    final saved = await copyExportToDirectory(
      const IoFileSystem(),
      source.path,
      directory.path,
      fileName: 'Favorites.bsexport',
    );
    expect(p.basename(saved), 'Favorites-2.bsexport');
    expect(await existing.readAsString(), 'old export');
    expect(await File(saved).readAsString(), 'new export');
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
