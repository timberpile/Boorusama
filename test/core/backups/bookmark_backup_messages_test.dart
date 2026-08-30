import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:boorusama/core/backups/sources/bookmark_backup_messages.dart';
import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/backups/widgets/backup_restore_tile.dart';

void main() {
  const exportTemplate = '{count} Bookmarks exported';
  const importTemplate = '{count} Bookmarks imported';
  const importExistingTemplate =
      '{count} Bookmarks imported\n({existing} already existed)';

  test('formats the exported bookmark count', () {
    expect(
      formatBookmarkExportSuccess(
        result: const BackupOperationResult(totalCount: 42),
        template: exportTemplate,
      ),
      '42 Bookmarks exported',
    );
  });

  test(
    'omits the existing suffix when no imported bookmark already existed',
    () {
      expect(
        formatBookmarkImportSuccess(
          result: const BackupOperationResult(totalCount: 4),
          template: importTemplate,
          existingTemplate: importExistingTemplate,
        ),
        '4 Bookmarks imported',
      );
    },
  );

  test(
    'includes the existing suffix when imported bookmarks already existed',
    () {
      expect(
        formatBookmarkImportSuccess(
          result: const BackupOperationResult(
            totalCount: 4,
            alreadyExistedCount: 2,
          ),
          template: importTemplate,
          existingTemplate: importExistingTemplate,
        ),
        '4 Bookmarks imported\n(2 already existed)',
      );
    },
  );

  test('keeps the generic success message without count-aware formatting', () {
    const genericMessage = 'Bookmarks exported';

    expect(
      formatBackupSuccessMessage(
        genericMessage: genericMessage,
        result: null,
        builder: (result) => '${result.totalCount} counted',
      ),
      genericMessage,
    );
    expect(
      formatBackupSuccessMessage(
        genericMessage: genericMessage,
        result: const BackupOperationResult(totalCount: 2),
        builder: null,
      ),
      genericMessage,
    );
  });

  test(
    'uses count-aware formatting when a result and builder are supplied',
    () {
      expect(
        formatBackupSuccessMessage(
          genericMessage: 'unused',
          result: const BackupOperationResult(totalCount: 2),
          builder: (result) => '${result.totalCount} counted',
        ),
        '2 counted',
      );
    },
  );

  testWidgets('renders the count-aware success message as user-visible text', (
    tester,
  ) async {
    final message = formatBookmarkImportSuccess(
      result: const BackupOperationResult(
        totalCount: 3,
        alreadyExistedCount: 1,
      ),
      template: importTemplate,
      existingTemplate: importExistingTemplate,
    );

    await tester.pumpWidget(MaterialApp(home: Text(message)));

    expect(
      find.text('3 Bookmarks imported\n(1 already existed)'),
      findsOneWidget,
    );
  });
}
