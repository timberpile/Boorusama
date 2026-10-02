import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/backups/export_import/import/import_source_integrity_validator.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';

void main() {
  const validator = ImportSourceIntegrityValidator();

  test('rejects a source schema newer than the app understands', () {
    final issues = validator.validate(
      sourceId: 'settings',
      packageSchemaVersion: 3,
      supportedSchemaVersion: 2,
      selection: const ExportNodeSelection.leaf('settings'),
      itemRecommendations: const {},
      data: Object(),
    );

    expect(issues.single.code, 'unsupported_source_version');
  });

  test('rejects selected and recommended items absent from the payload', () {
    const data = BookmarkBackupData(bookmarks: [], groups: []);
    final issues = validator.validate(
      sourceId: 'bookmarks',
      packageSchemaVersion: 3,
      supportedSchemaVersion: 3,
      selection: const ExportNodeSelection.explicit('bookmarks', {
        'group:missing',
      }),
      itemRecommendations: const {
        'group:also-missing': ImportAction.update,
      },
      data: data,
    );

    expect(issues.map((issue) => issue.code).toSet(), {
      'unknown_selected_item',
      'unknown_recommended_item',
    });
  });

  test('rejects bookmark groups referencing an absent bookmark', () {
    const data = BookmarkBackupData(
      bookmarks: [],
      groups: [
        BookmarkGroupBackup(
          id: 'group-id',
          name: 'References',
          bookmarkIds: [42],
        ),
      ],
    );
    final issues = validator.validate(
      sourceId: 'bookmarks',
      packageSchemaVersion: 3,
      supportedSchemaVersion: 3,
      selection: const ExportNodeSelection.all('bookmarks'),
      itemRecommendations: const {},
      data: data,
    );

    expect(issues.single.code, 'missing_bookmark_reference');
    expect(issues.single.itemId, 'group:group-id');
  });
}
