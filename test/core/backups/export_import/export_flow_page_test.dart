import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;

import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/widgets/selection_tree.dart';

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
      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, true);
    });
  }
}

Widget _app(Widget child) => TranslationProvider(
  child: MaterialApp(home: Scaffold(body: child)),
);
