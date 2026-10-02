// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import 'package:boorusama/core/backups/export_import/export/export_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/sources/export_import_source.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';

void main() {
  test('dynamic all remains different from every currently known child', () {
    const descriptor = ExportSelectionDescriptor.collection(
      id: 'bookmarks',
      children: [
        ExportSelectionNode(id: 'group-a'),
        ExportSelectionNode(id: 'group-b'),
      ],
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
        children: [
          ExportSelectionNode(id: 'group-a'),
          ExportSelectionNode(id: 'group-new'),
        ],
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

  test('nested descriptors expose and resolve every stable node identity', () {
    const descriptor = _nestedDescriptor;

    expect(descriptor.childIds, {
      'folder:art',
      'folder:landscapes',
      'folder:night',
      'search:moon',
      'search:sunrise',
    });
    expect(descriptor.findNode('search:moon')?.id, 'search:moon');
    expect(
      const ExportNodeSelection.explicit('pinned_searches', {
        'folder:landscapes',
      }).resolve(descriptor),
      {
        'folder:landscapes',
        'folder:night',
        'search:moon',
        'search:sunrise',
      },
    );
  });

  test('explicit leaves remain fixed when a folder gains another search', () {
    const selection = ExportNodeSelection.explicit('pinned_searches', {
      'search:moon',
    });
    const changed = ExportSelectionDescriptor.collection(
      id: 'pinned_searches',
      children: [
        ExportSelectionNode(
          id: 'folder:night',
          children: [
            ExportSelectionNode(id: 'search:moon'),
            ExportSelectionNode(id: 'search:new'),
          ],
        ),
      ],
    );

    expect(selection.resolve(changed), {'search:moon'});
  });

  test('nested selections retain the existing manifest JSON shape', () {
    final selection = ExportSelection.custom(const {
      'pinned_searches': ExportNodeSelection.explicit('pinned_searches', {
        'folder:landscapes',
        'search:moon',
      }),
    });
    final json = selection.toJson();

    expect(json, {
      'mode': 'custom',
      'nodes': [
        {
          'nodeId': 'pinned_searches',
          'kind': 'explicit',
          'childIds': ['folder:landscapes', 'search:moon'],
        },
      ],
    });
    expect(ExportSelection.fromJson(json), selection);
  });

  test('selecting a folder stores only its dynamic subtree identity', () {
    final container = ProviderContainer(
      overrides: [
        exportImportSourcesProvider.overrideWithValue(const [_NestedSource()]),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(exportFlowProvider.notifier)
      ..useCustomExport();

    notifier.toggleNode(
      _nestedDescriptor,
      _nestedDescriptor.findNode('folder:landscapes')!,
    );

    expect(
      container.read(exportFlowProvider).nodes['pinned_searches']?.childIds,
      {'folder:landscapes'},
    );
  });

  test('deselecting a nested leaf expands its selected ancestor safely', () {
    final container = ProviderContainer(
      overrides: [
        exportImportSourcesProvider.overrideWithValue(const [_NestedSource()]),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(exportFlowProvider.notifier)
      ..useCustomExport()
      ..toggleNode(
        _nestedDescriptor,
        _nestedDescriptor.findNode('folder:landscapes')!,
      );

    notifier.toggleNode(
      _nestedDescriptor,
      _nestedDescriptor.findNode('search:moon')!,
    );

    expect(
      container.read(exportFlowProvider).nodes['pinned_searches']?.childIds,
      {'search:sunrise'},
    );
  });
}

const _nestedDescriptor = ExportSelectionDescriptor.collection(
  id: 'pinned_searches',
  children: [
    ExportSelectionNode(
      id: 'folder:art',
      children: [
        ExportSelectionNode(
          id: 'folder:landscapes',
          children: [
            ExportSelectionNode(
              id: 'folder:night',
              children: [ExportSelectionNode(id: 'search:moon')],
            ),
            ExportSelectionNode(id: 'search:sunrise'),
          ],
        ),
      ],
    ),
  ],
);

class _NestedSource implements ExportImportSource {
  const _NestedSource();

  @override
  String get id => 'pinned_searches';

  @override
  int get priority => 0;

  @override
  int get schemaVersion => 1;

  @override
  ExportSelectionDescriptor get selectionDescriptor => _nestedDescriptor;

  @override
  Future<ExportSourceSnapshot> capture(ExportSourceRequest request) {
    throw UnimplementedError();
  }
}
