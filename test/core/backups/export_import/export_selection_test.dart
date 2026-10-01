// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';

void main() {
  test('dynamic all remains different from every currently known child', () {
    const descriptor = ExportSelectionDescriptor.collection(
      id: 'bookmarks',
      childIds: {'group-a', 'group-b'},
    );
    const dynamicAll = ExportNodeSelection.all('bookmarks');
    const explicit = ExportNodeSelection.explicit(
      'bookmarks',
      {'group-a', 'group-b'},
    );

    expect(dynamicAll, isNot(explicit));
    expect(dynamicAll.resolve(descriptor), {'group-a', 'group-b'});
    expect(explicit.resolve(descriptor), {'group-a', 'group-b'});
  });

  test(
    'dynamic all includes future children while explicit selection does not',
    () {
      const dynamicAll = ExportNodeSelection.all('bookmarks');
      const explicit = ExportNodeSelection.explicit('bookmarks', {'group-a'});
      const changed = ExportSelectionDescriptor.collection(
        id: 'bookmarks',
        childIds: {'group-a', 'group-new'},
      );

      expect(dynamicAll.resolve(changed), {'group-a', 'group-new'});
      expect(explicit.resolve(changed), {'group-a'});
    },
  );

  test('full export follows sources registered after it was selected', () {
    final registry = BackupRegistry();
    final selection = ExportSelection.full(registry);
    registry.registerDescriptor(const ExportSelectionDescriptor.leaf(id: 'a'));
    expect(selection.sourceIds, {'a'});

    registry.registerDescriptor(const ExportSelectionDescriptor.leaf(id: 'b'));
    expect(selection.sourceIds, {'a', 'b'});
  });
}
