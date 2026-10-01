// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/export_import/models/package_manifest.dart';

void main() {
  test('manifest preserves package and source metadata', () {
    final manifest = ExportPackageManifest.fromJson({
      'format': 'boorusama-export',
      'formatVersion': 1,
      'exportId': '7e307c25-7b35-46b0-ae1c-60c78f09d229',
      'createdAt': '2026-10-01T12:00:00.000Z',
      'appVersion': '1.2.3',
      'preset': 'full',
      'containsCredentials': true,
      'future': true,
      'sources': [
        {
          'id': 'bookmarks',
          'schemaVersion': 3,
          'selection': const {'kind': 'all'},
          'recommendedAction': 'replace',
          'itemRecommendedActions': const {
            'group-a': 'update',
            'group-b': 'merge',
          },
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

    expect(manifest.format, 'boorusama-export');
    expect(manifest.exportId, '7e307c25-7b35-46b0-ae1c-60c78f09d229');
    expect(manifest.preset, ExportSelectionMode.full);
    expect(manifest.containsCredentials, isTrue);
    expect(manifest.sources.single.id, 'bookmarks');
    expect(
      manifest.sources.single.selection,
      const ExportNodeSelection.all('bookmarks'),
    );
    expect(manifest.sources.single.recommendedAction, ImportAction.replace);
    expect(manifest.sources.single.itemRecommendedActions, const {
      'group-a': ImportAction.update,
      'group-b': ImportAction.merge,
    });
    expect(manifest.sources.single.parts.single.byteLength, 12);
  });

  test('legacy version one metadata remains optional', () {
    final manifest = ExportPackageManifest.fromJson({
      'formatVersion': 1,
      'createdAt': '2026-10-01T12:00:00.000Z',
      'appVersion': '1.2.3',
      'sources': [
        {
          'id': 'settings',
          'schemaVersion': 1,
          'parts': [
            {
              'path': 'sources/settings/data.json',
              'sha256': 'a' * 64,
              'byteLength': 1,
            },
          ],
        },
      ],
    });

    expect(manifest.format, isNull);
    expect(manifest.exportId, isNull);
    expect(manifest.preset, isNull);
    expect(manifest.containsCredentials, isNull);
    expect(manifest.sources.single.selection, isNull);
    expect(manifest.sources.single.recommendedAction, isNull);
    expect(manifest.sources.single.itemRecommendedActions, isEmpty);
  });

  test('rejects invalid item recommendations', () {
    expect(
      () => ExportSourceManifest.fromJson({
        'id': 'bookmarks',
        'schemaVersion': 1,
        'itemRecommendedActions': const {'group-a': 'future-action'},
        'parts': [
          {
            'path': 'sources/bookmarks/data.json',
            'sha256': 'a' * 64,
            'byteLength': 1,
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('rejects a package with another format marker', () {
    expect(
      () => ExportPackageManifest.fromJson(const {
        'format': 'other-export',
        'formatVersion': 1,
        'exportId': 'export-id',
        'createdAt': '2026-10-01T12:00:00.000Z',
        'appVersion': '1.2.3',
        'preset': 'custom',
        'containsCredentials': false,
        'sources': [],
      }),
      throwsFormatException,
    );
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
