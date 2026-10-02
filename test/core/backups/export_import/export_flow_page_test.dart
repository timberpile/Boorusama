import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:oktoast/oktoast.dart';
import 'package:kurumi/kurumi.dart';

import 'package:boorusama/core/backups/export_import/export/export_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/export/export_flow_page.dart';
import 'package:boorusama/core/backups/export_import/models/export_item_presentation.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/export_template.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
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
          onToggleNode: (_, _) {},
          sourceLabel: (_) => 'Bookmark groups',
          presentation: const ExportSelectionPresentation(items: {}),
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
      label: 'All current',
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
            onToggleNode: (_, _) {},
            sourceLabel: (_) => 'Bookmark groups',
            presentation: const ExportSelectionPresentation(items: {}),
          ),
        ),
      );

      expect(find.text(c.label), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        true,
      );
    });
  }

  testWidgets('explicit child selection shows a useful selected count', (
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
          onToggleNode: (_, _) {},
          sourceLabel: (_) => 'Bookmark groups',
          presentation: const ExportSelectionPresentation(items: {}),
        ),
      ),
    );

    expect(find.text('1 of 2 selected'), findsOneWidget);
  });

  testWidgets('leaf categories do not expose expansion semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ExportSelectionTree(
          descriptors: const [
            ExportSelectionDescriptor.leaf(id: 'settings'),
          ],
          selections: const {},
          onToggleSource: (_) {},
          onToggleNode: (_, _) {},
          sourceLabel: (_) => 'Settings',
          presentation: const ExportSelectionPresentation(items: {}),
        ),
      ),
    );

    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.byType(CheckboxListTile), findsOneWidget);
  });

  testWidgets('empty dynamic folders retain expansion semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ExportSelectionTree(
          descriptors: const [
            ExportSelectionDescriptor.collection(
              id: 'pinned_searches',
              children: [
                ExportSelectionNode(
                  id: 'folder:empty',
                  canHaveChildren: true,
                ),
              ],
            ),
          ],
          selections: const {},
          onToggleSource: (_) {},
          onToggleNode: (_, _) {},
          sourceLabel: (_) => 'Pinned searches',
          presentation: const ExportSelectionPresentation(
            items: {
              'folder:empty': ExportItemPresentation(label: 'Empty folder'),
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pinned searches'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNWidgets(2));
    expect(find.text('Empty folder'), findsOneWidget);
  });

  testWidgets('recursive collections expose partial state at every depth', (
    tester,
  ) async {
    const recursive = ExportSelectionDescriptor.collection(
      id: 'pinned_searches',
      children: [
        ExportSelectionNode(
          id: 'folder:top',
          children: [
            ExportSelectionNode(
              id: 'folder:nested',
              children: [
                ExportSelectionNode(
                  id: 'folder:deep',
                  children: [
                    ExportSelectionNode(id: 'search:selected'),
                    ExportSelectionNode(id: 'search:other'),
                  ],
                ),
              ],
            ),
            ExportSelectionNode(id: 'search:outside'),
          ],
        ),
      ],
    );
    const presentation = ExportSelectionPresentation(
      items: {
        'folder:top': ExportItemPresentation(label: 'Top'),
        'folder:nested': ExportItemPresentation(label: 'Nested'),
        'folder:deep': ExportItemPresentation(label: 'Deep'),
        'search:selected': ExportItemPresentation(label: 'Selected'),
        'search:other': ExportItemPresentation(label: 'Other'),
        'search:outside': ExportItemPresentation(label: 'Outside'),
      },
    );

    await tester.pumpWidget(
      _app(
        ExportSelectionTree(
          descriptors: const [recursive],
          selections: const {
            'pinned_searches': ExportNodeSelection.explicit(
              'pinned_searches',
              {'search:selected'},
            ),
          },
          onToggleSource: (_) {},
          onToggleNode: (_, _) {},
          sourceLabel: (_) => 'Pinned searches',
          presentation: presentation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Top'), findsOneWidget);
    expect(find.text('Nested'), findsOneWidget);
    expect(find.text('Deep'), findsOneWidget);
    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('1 of 3 selected'), findsNWidgets(2));
    expect(find.text('1 of 2 selected'), findsNWidgets(2));
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .take(4)
          .map(
            (checkbox) => checkbox.value,
          ),
      everyElement(isNull),
    );
  });

  testWidgets('container IDs and explicit leaves retain distinct summaries', (
    tester,
  ) async {
    const nested = ExportSelectionDescriptor.collection(
      id: 'bookmarks',
      children: [
        ExportSelectionNode(
          id: 'group:one',
          children: [
            ExportSelectionNode(id: 'bookmark:a'),
            ExportSelectionNode(id: 'bookmark:b'),
          ],
        ),
      ],
    );

    Future<void> pump(Set<String> ids) => tester.pumpWidget(
      _app(
        ExportSelectionTree(
          descriptors: const [nested],
          selections: {
            'bookmarks': ExportNodeSelection.explicit('bookmarks', ids),
          },
          onToggleSource: (_) {},
          onToggleNode: (_, _) {},
          sourceLabel: (_) => 'Bookmark groups',
          presentation: const ExportSelectionPresentation(items: {}),
        ),
      ),
    );

    await pump({'bookmark:a', 'bookmark:b'});
    await tester.pumpAndSettle();
    expect(find.text('All current'), findsNWidgets(2));

    await pump({'group:one'});
    await tester.pumpAndSettle();
    expect(find.text('All, including future items'), findsOneWidget);
    expect(find.text('All current'), findsOneWidget);
  });

  testWidgets('searches and feeds show subdued trailing profile names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const descriptors = [
      ExportSelectionDescriptor.collection(
        id: 'pinned_searches',
        children: [
          ExportSelectionNode(
            id: 'folder:one',
            children: [ExportSelectionNode(id: 'search:one')],
          ),
        ],
      ),
      ExportSelectionDescriptor.collection(
        id: 'following_feeds',
        children: [ExportSelectionNode(id: 'feed:one')],
      ),
    ];
    const presentation = ExportSelectionPresentation(
      items: {
        'folder:one': ExportItemPresentation(label: 'Folder'),
        'search:one': ExportItemPresentation(
          label: 'Landscape',
          trailingLabel: 'A very long profile name that must fit',
        ),
        'feed:one': ExportItemPresentation(
          label: 'Landscape',
          trailingLabel: 'Another very long profile name that must fit',
        ),
      },
    );

    await tester.pumpWidget(
      _app(
        ExportSelectionTree(
          descriptors: descriptors,
          selections: const {
            'pinned_searches': ExportNodeSelection.all('pinned_searches'),
            'following_feeds': ExportNodeSelection.all('following_feeds'),
          },
          onToggleSource: (_) {},
          onToggleNode: (_, _) {},
          sourceLabel: (id) => id,
          presentation: presentation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Folder'));
    await tester.pumpAndSettle();
    expect(find.text('Landscape'), findsNWidgets(2));
    final profileTexts =
        [
          'A very long profile name that must fit',
          'Another very long profile name that must fit',
        ].map(
          (label) => tester.widget<Text>(find.text(label)),
        );
    final expectedColor = Theme.of(
      tester.element(find.text('A very long profile name that must fit')),
    ).colorScheme.onSurfaceVariant;
    expect(
      profileTexts.map((text) => text.style?.color),
      everyElement(expectedColor),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving a template returns to the export form without errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exportImportSourcesProvider.overrideWithValue(const [_FakeSource()]),
          exportSelectionPresentationProvider.overrideWithValue(
            const ExportSelectionPresentation(items: {}),
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
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Save as template')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Cancel')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Save')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Save only')),
      findsNothing,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Save & export')),
      findsNothing,
    );
    await tester.enterText(find.byType(TextField), 'QA bookmarks');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('QA bookmarks'), findsOneWidget);
    expect(find.text('Saved on this device only.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('suggested actions use the standard settings selector', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exportImportSourcesProvider.overrideWithValue(
            const [_FakeCollectionSource()],
          ),
          exportSelectionPresentationProvider.overrideWithValue(
            const ExportSelectionPresentation(
              items: {
                'one': ExportItemPresentation(label: 'Favorites'),
              },
            ),
          ),
          exportTemplatesProvider.overrideWith(_FakeTemplatesNotifier.new),
        ],
        child: TranslationProvider(
          child: const MaterialApp(home: ExportFlowPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom export'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suggested import behavior'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('recommendation:bookmarks')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<ImportAction?>), findsNothing);
    expect(
      find.byWidgetPredicate((widget) => widget is KurumiSettingsTile),
      findsOneWidget,
    );
  });

  testWidgets(
    'suggested actions reveal selected items through their hierarchy',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exportImportSourcesProvider.overrideWithValue(
              const [_FakePinnedSearchSource()],
            ),
            exportSelectionPresentationProvider.overrideWithValue(
              const ExportSelectionPresentation(
                items: {
                  'folder:one': ExportItemPresentation(label: 'Landscapes'),
                  'search:one': ExportItemPresentation(
                    label: 'Blue sky',
                    trailingLabel: 'Profile A',
                  ),
                  'search:two': ExportItemPresentation(
                    label: 'Sunset',
                    trailingLabel: 'Profile B',
                  ),
                },
              ),
            ),
            exportTemplatesProvider.overrideWith(_FakeTemplatesNotifier.new),
          ],
          child: TranslationProvider(
            child: const MaterialApp(home: ExportFlowPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Custom export'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suggested import behavior'));
      await tester.pumpAndSettle();

      final recommendations = find.byKey(
        const ValueKey('recommendation:pinned_searches'),
      );
      expect(
        find.descendant(
          of: recommendations,
          matching: find.text('Landscapes'),
        ),
        findsNothing,
      );
      await tester.tap(recommendations);
      await tester.pumpAndSettle();
      final folder = find.descendant(
        of: recommendations,
        matching: find.text('Landscapes'),
      );
      expect(folder, findsOneWidget);
      expect(
        find.descendant(of: recommendations, matching: find.text('Blue sky')),
        findsNothing,
      );

      await tester.tap(folder);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: recommendations, matching: find.text('Blue sky')),
        findsWidgets,
      );
      expect(
        find.descendant(of: recommendations, matching: find.text('Sunset')),
        findsWidgets,
      );
      expect(
        find.descendant(of: recommendations, matching: find.text('Profile A')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: recommendations, matching: find.text('Profile B')),
        findsOneWidget,
      );
    },
  );

  testWidgets('ready exports summarize the selection and allow editing', (
    tester,
  ) async {
    var edited = false;
    await tester.pumpWidget(
      _app(
        ExportReadySummary(
          state: const ExportFlowState(
            isFull: false,
            nodes: {
              'bookmarks': ExportNodeSelection.explicit('bookmarks', {'one'}),
            },
            includeCredentials: false,
            status: ExportFlowStatus.ready,
            packagePath: '/tmp/test.bsexport',
          ),
          descriptors: const [descriptor],
          sourceLabel: (_) => 'Bookmark groups',
          onEdit: () => edited = true,
        ),
      ),
    );

    expect(find.text('Custom export'), findsOneWidget);
    expect(find.text('Bookmark groups · 1 selected'), findsOneWidget);
    await tester.tap(find.text('Edit selection'));
    expect(edited, true);
  });

  testWidgets('ready summary preserves dynamic-all and leaf meaning', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ExportReadySummary(
          state: const ExportFlowState(
            isFull: false,
            nodes: {
              'bookmarks': ExportNodeSelection.all('bookmarks'),
              'settings': ExportNodeSelection.leaf('settings'),
            },
            includeCredentials: false,
            status: ExportFlowStatus.ready,
            packagePath: '/tmp/test.bsexport',
          ),
          descriptors: const [
            descriptor,
            ExportSelectionDescriptor.leaf(id: 'settings'),
          ],
          sourceLabel: (id) => switch (id) {
            'bookmarks' => 'Bookmark groups',
            _ => 'Settings',
          },
          onEdit: () {},
        ),
      ),
    );

    expect(
      find.text('Bookmark groups · All, including future items'),
      findsOneWidget,
    );
    expect(find.text('Settings · Selected'), findsOneWidget);
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

class _FakeCollectionSource implements ExportImportSource {
  const _FakeCollectionSource();

  @override
  String get id => 'bookmarks';

  @override
  int get priority => 0;

  @override
  int get schemaVersion => 1;

  @override
  ExportSelectionDescriptor get selectionDescriptor =>
      const ExportSelectionDescriptor.collection(
        id: 'bookmarks',
        childIds: {'one'},
      );

  @override
  Future<ExportSourceSnapshot> capture(ExportSourceRequest request) {
    throw UnimplementedError();
  }
}

class _FakePinnedSearchSource implements ExportImportSource {
  const _FakePinnedSearchSource();

  @override
  String get id => 'pinned_searches';

  @override
  int get priority => 0;

  @override
  int get schemaVersion => 1;

  @override
  ExportSelectionDescriptor get selectionDescriptor =>
      const ExportSelectionDescriptor.collection(
        id: 'pinned_searches',
        children: [
          ExportSelectionNode(
            id: 'folder:one',
            children: [
              ExportSelectionNode(id: 'search:one'),
              ExportSelectionNode(id: 'search:two'),
            ],
          ),
        ],
      );

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
