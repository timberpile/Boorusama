// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/backups/export_import/models/package_manifest.dart';

void main() {
  test('manifest ignores unknown fields and preserves source parts', () {
    final manifest = ExportPackageManifest.fromJson({
      'formatVersion': 1,
      'createdAt': '2026-10-01T12:00:00.000Z',
      'appVersion': '1.2.3',
      'future': true,
      'sources': [
        {
          'id': 'bookmarks',
          'schemaVersion': 3,
          'unknown': 42,
          'parts': [
            {
              'path': 'sources/bookmarks/data.json',
              'sha256': 'a' * 64,
              'byteLength': 12,
              'future': 'value',
            },
          ],
        },
      ],
    });

    expect(manifest.sources.single.id, 'bookmarks');
    expect(manifest.sources.single.parts.single.byteLength, 12);
  });

  for (final path in [
    '../secret',
    '/absolute/data.json',
    'sources/../secret',
    r'sources\bookmarks\data.json',
    '',
  ]) {
    test('rejects unsafe part path $path', () {
      expect(
        () => ExportPartManifest(
          path: path,
          sha256: 'a' * 64,
          byteLength: 1,
        ),
        throwsArgumentError,
      );
    });
  }
}
