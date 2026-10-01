// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/export_template.dart';

void main() {
  test(
    'template freezes app sources but keeps dynamic collection selection',
    () {
      final selection = ExportSelection.custom({
        'bookmarks': const ExportNodeSelection.all('bookmarks'),
        'settings': const ExportNodeSelection.leaf('settings'),
      });
      final template = ExportTemplate(
        id: 'share',
        name: 'Share',
        selection: selection,
      );

      final restored = ExportTemplate.fromJson(template.toJson());
      expect(restored, template);
      expect(restored.selection.sourceIds, {'bookmarks', 'settings'});
      expect(
        restored.selection.nodes['bookmarks'],
        const ExportNodeSelection.all('bookmarks'),
      );
    },
  );

  test('template rejects a full selection that could gain app sources', () {
    expect(
      () => ExportTemplate.fromJson({
        'id': 'bad',
        'name': 'Bad',
        'selection': {'mode': 'full'},
      }),
      throwsFormatException,
    );
  });
}
