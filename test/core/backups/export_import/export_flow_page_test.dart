import 'package:flutter/gestures.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:material_ui/material_ui.dart';
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

  test('legacy templates resolve No Group to the real Default group', () {
    final container = ProviderContainer(
      overrides: [
        exportImportSourcesProvider.overrideWithValue(const []),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(exportFlowProvider.notifier);
    notifier.applyTemplate(
      ExportTemplate(
        id: 'legacy',
        name: 'Legacy',
        selection: ExportSelection.custom(const {
          'bookmarks': ExportNodeSelection.explicit('bookmarks', {'ungrouped'}),
        }),
        itemRecommendedActions: const {
          'bookmarks': {'ungrouped': ImportAction.update},
        },
      ),
    );
    final state = container.read(exportFlowProvider);
    expect(state.nodes['bookmarks']!.childIds, {
      'group:$defaultBookmarkGroupId',
    });
    expect(state.itemRecommendedActions['bookmarks'], {
      'group:$defaultBookmarkGroupId': ImportAction.merge,
    });
  });

  testWidgets(
    'leaf sibling drag retains explicit membership and cascading parent semantics',
    (tester) async {
      const tree = ExportSelectionDescriptor.collection(
        id: 'bookmarks',
        childIds: {'one', 'two', 'three'},
      );
      var ids = <String>{'one'};
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => ExportSelectionTree(
              descriptors: const [tree],
              selections: {
                'bookmarks': ExportNodeSelection.explicit('bookmarks', ids),
              },
              onToggleSource: (_) =>
                  fail('leaf drag toggled a cascading parent'),
              onToggleNode: (_, node) => setState(() {
                if (!ids.add(node.id)) ids.remove(node.id);
              }),
              sourceLabel: (_) => 'Bookmarks',
              presentation: const ExportSelectionPresentation(items: {}),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('two')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
      await gesture.moveTo(tester.getCenter(find.text('three')));
      await tester.pump();
      expect(ids, {'one', 'two', 'three'});
      expect(find.text('All Current'), findsOneWidget);
      expect(find.text('All, Including Future Items'), findsNothing);
      await gesture.moveTo(tester.getCenter(find.text('two')));
      await tester.pump();
      expect(ids, {'one', 'two'});
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isNull,
      );
    },
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
      label: 'All, Including Future Items',
    ),
    (
      selection: ExportNodeSelection.explicit('bookmarks', {'one', 'two'}),
      label: 'All Current',
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

  testWidgets('tree rows use compact and consistent indentation', (
    tester,
  ) async {
    const nested = ExportSelectionDescriptor.collection(
      id: 'pinned_searches',
      children: [
        ExportSelectionNode(
          id: 'folder:one',
          children: [
            ExportSelectionNode(id: 'search:one'),
            ExportSelectionNode(
              id: 'folder:two',
              children: [ExportSelectionNode(id: 'search:two')],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        ExportSelectionTree(
          descriptors: const [
            ExportSelectionDescriptor.leaf(id: 'settings'),
            nested,
          ],
          selections: const {
            'settings': ExportNodeSelection.leaf('settings'),
            'pinned_searches': ExportNodeSelection.explicit(
              'pinned_searches',
              {'search:one', 'search:two'},
            ),
          },
          onToggleSource: (_) {},
          onToggleNode: (_, _) {},
          sourceLabel: (id) => id,
          presentation: const ExportSelectionPresentation(items: {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double checkboxX(String key) {
      final tileFinder = find.byKey(ValueKey(key));
      final tile = tester.widget(tileFinder);
      return switch (tile) {
        ExpansionTile(:final leading) =>
          tester.getTopLeft(find.byWidget(leading!)).dx,
        CheckboxListTile() =>
          tester
              .getTopLeft(
                find
                    .descendant(
                      of: tileFinder,
                      matching: find.byType(Checkbox),
                    )
                    .first,
              )
              .dx,
        _ => throw StateError('Unsupported tile ${tile.runtimeType}'),
      };
    }

    final rootLeafX = checkboxX('settings');
    final rootCollectionX = checkboxX('pinned_searches');
    final firstLevelCollectionX = checkboxX('pinned_searches:folder:one');
    final secondLevelLeafX = checkboxX('pinned_searches:search:one');
    final secondLevelCollectionX = checkboxX('pinned_searches:folder:two');
    final thirdLevelLeafX = checkboxX('pinned_searches:search:two');

    expect(rootCollectionX, rootLeafX);
    expect(secondLevelCollectionX, secondLevelLeafX);
    expect(
      tester.getTopLeft(find.text('pinned_searches')).dx,
      tester.getTopLeft(find.text('settings')).dx,
    );
    expect(
      tester.getTopLeft(find.text('folder:two')).dx,
      tester.getTopLeft(find.text('search:one')).dx,
    );
    expect(firstLevelCollectionX - rootCollectionX, 8);
    expect(secondLevelCollectionX - firstLevelCollectionX, 8);
    expect(thirdLevelLeafX - secondLevelCollectionX, 8);
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
          sourceLabel: (_) => 'Topics',
          presentation: const ExportSelectionPresentation(
            items: {
              'folder:empty': ExportItemPresentation(label: 'Empty folder'),
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Topics'));
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
          sourceLabel: (_) => 'Topics',
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
    expect(find.text('All Current'), findsNWidgets(2));

    await pump({'group:one'});
    await tester.pumpAndSettle();
    expect(find.text('All, Including Future Items'), findsOneWidget);
    expect(find.text('All Current'), findsOneWidget);
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
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72);
    expect(
      profileTexts.map((text) => text.style?.color),
      everyElement(expectedColor),
    );
    expect(
      profileTexts.map((text) => text.style?.fontSize),
      everyElement(
        Theme.of(
          tester.element(find.text('A very long profile name that must fit')),
        ).textTheme.bodySmall?.fontSize,
      ),
    );
    expect(profileTexts.map((text) => text.maxLines), everyElement(1));
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

    await tester.tap(find.text('Custom Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    final patternField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Export file name (optional)',
    );
    final formScrollable = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      patternField,
      350,
      scrollable: formScrollable,
    );
    expect(tester.widget<TextField>(patternField).controller!.text, isEmpty);
    expect(
      tester.widget<TextField>(patternField).decoration!.hintText,
      'boorusama-{timestamp}',
    );
    await tester.enterText(patternField, 'favorites-{date:yyyy-MM-dd}');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save as Template'),
      500,
      scrollable: formScrollable,
    );
    await tester.tap(find.text('Save as Template'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Save as Template')),
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
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)),
      'QA bookmarks',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('QA bookmarks'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ExportFlowPage)),
    );
    final template = container
        .read(exportTemplatesProvider)
        .valueOrNull!
        .single;
    expect(template.fileNamePattern, 'favorites-{date:yyyy-MM-dd}');
    container
        .read(exportFlowProvider.notifier)
        .setFileNamePattern('other-{timestamp}');
    await tester.pumpAndSettle();
    container.read(exportFlowProvider.notifier).applyTemplate(template);
    await tester.pumpAndSettle();
    expect(
      container.read(exportFlowProvider).fileNamePattern,
      'favorites-{date:yyyy-MM-dd}',
    );
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

    await tester.tap(find.text('Custom Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suggested Import Behavior'));
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
              const [_FakeFollowingTopicSource()],
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

      await tester.tap(find.text('Custom Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suggested Import Behavior'));
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

    expect(find.text('Custom Export'), findsOneWidget);
    expect(find.text('Bookmark groups · 1 selected'), findsOneWidget);
    await tester.tap(find.text('Edit Selection'));
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
      find.text('Bookmark groups · All, Including Future Items'),
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

class _FakeFollowingTopicSource implements ExportImportSource {
  const _FakeFollowingTopicSource();

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
