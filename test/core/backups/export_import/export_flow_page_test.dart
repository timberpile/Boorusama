import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:oktoast/oktoast.dart';

import 'package:boorusama/core/backups/export_import/export/export_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/export/export_flow_page.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/export_template.dart';
import 'package:boorusama/core/backups/export_import/sources/export_import_source.dart';
import 'package:boorusama/core/backups/export_import/widgets/selection_tree.dart';
import 'package:boorusama/core/backups/sources/providers.dart';

void main() {
  const descriptor = ExportSelectionDescriptor.collection(
    id: 'bookmarks',
    childIds: {'one', 'two'},
  );

  testWidgets('partially selected collections show an indeterminate parent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ExportSelectionTree(
          descriptors: const [descriptor],
          selections: const {
            'bookmarks': ExportNodeSelection.explicit('bookmarks', {'one'}),
          },
          onToggleSource: (_) {},
          onToggleChild: (_, _) {},
          sourceLabel: (_) => 'Bookmark groups',
          childLabel: (_, id) => id,
        ),
      ),
    );

    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isNull);
  });

  const cases = [
    (
      selection: ExportNodeSelection.all('bookmarks'),
      label: 'All, including future items',
    ),
    (
      selection: ExportNodeSelection.explicit('bookmarks', {'one', 'two'}),
      label: 'All current items',
    ),
  ];
  for (final c in cases) {
    testWidgets('distinguishes ${c.label.toLowerCase()} selection', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ExportSelectionTree(
            descriptors: const [descriptor],
            selections: {'bookmarks': c.selection},
            onToggleSource: (_) {},
            onToggleChild: (_, _) {},
            sourceLabel: (_) => 'Bookmark groups',
            childLabel: (_, id) => id,
          ),
        ),
      );

      expect(find.text(c.label), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        c.selection.kind == ExportNodeSelectionKind.all ? true : null,
      );
    });
  }

  testWidgets('saving a template returns to the export form without errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exportImportSourcesProvider.overrideWithValue(const [_FakeSource()]),
          exportSelectionLabelsProvider.overrideWithValue(
            const ExportSelectionLabels(children: {}),
          ),
          exportTemplatesProvider.overrideWith(_FakeTemplatesNotifier.new),
        ],
        child: OKToast(
          child: TranslationProvider(
            child: const MaterialApp(home: ExportFlowPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom export'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Save as template'), 500);
    await tester.tap(find.text('Save as template'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'QA bookmarks');
    await tester.tap(find.text('Save only'));
    await tester.pumpAndSettle();

    expect(find.text('QA bookmarks'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });
}

Widget _app(Widget child) => TranslationProvider(
  child: MaterialApp(home: Scaffold(body: child)),
);

class _FakeSource implements ExportImportSource {
  const _FakeSource();

  @override
  String get id => 'settings';

  @override
  int get priority => 0;

  @override
  int get schemaVersion => 1;

  @override
  ExportSelectionDescriptor get selectionDescriptor =>
      const ExportSelectionDescriptor.leaf(id: 'settings');

  @override
  Future<ExportSourceSnapshot> capture(ExportSourceRequest request) {
    throw UnimplementedError();
  }
}

class _FakeTemplatesNotifier extends ExportTemplatesNotifier {
  @override
  Future<List<ExportTemplate>> build() async => const [];

  @override
  Future<void> save(ExportTemplate template) async {
    state = AsyncData([...?state.valueOrNull, template]);
  }
}
