// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/export_template.dart';
import 'package:boorusama/core/backups/export_import/template_repository.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('export_templates_');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('settings');
  });

  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  test(
    'saves replaces and deletes templates without changing their order',
    () async {
      final repository = ExportTemplateRepository(box);
      final first = _template('first', 'First');
      final second = _template('second', 'Second');
      await repository.save(first);
      await repository.save(second);

      await repository.replace(_template('first', 'Renamed'));
      expect(repository.load().map((template) => template.name), [
        'Renamed',
        'Second',
      ]);

      await repository.delete('first');
      expect(repository.load(), [second]);
    },
  );
}

ExportTemplate _template(String id, String name) => ExportTemplate(
  id: id,
  name: name,
  selection: ExportSelection.custom({
    'bookmarks': const ExportNodeSelection.all('bookmarks'),
  }),
);
