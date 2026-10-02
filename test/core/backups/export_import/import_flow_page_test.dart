import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';

import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_flow_page.dart';
import 'package:boorusama/core/backups/export_import/import/import_preflight.dart';
import 'package:boorusama/core/backups/export_import/models/export_item_presentation.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/export_import/widgets/import_action_editor.dart';

void main() {
  testWidgets('shows only actions that are valid for an imported item', (
    tester,
  ) async {
    final proposed = ProposedImportSource(
      id: 'bookmarks',
      kind: ImportSourceKind.collection,
      selectionComplete: false,
      availableActions: const {
        ImportAction.configureItems,
        ImportAction.skip,
      },
      defaultAction: ImportAction.configureItems,
      items: [
        ProposedImportItem(
          id: 'new',
          availableActions: const {ImportAction.copy, ImportAction.skip},
          defaultAction: ImportAction.copy,
          compatibleTargetIds: const {},
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        ImportActionEditor(
          proposed: proposed,
          resolved: ProposedImportPlan(
            sources: [proposed],
          ).resolveDefaults().sources.single,
          onChanged: (_) {},
          sourceLabel: (_) => 'Bookmark groups',
          itemLabel: (_) => 'New group',
          targetLabel: (id) => id,
        ),
      ),
    );

    expect(find.text('Import as a new copy'), findsOneWidget);
    expect(find.text('Update matching item'), findsNothing);
    expect(find.text('Merge into another item…'), findsNothing);
    expect(find.byType(DropdownButton<ImportAction>), findsNothing);
    expect(find.byType(KurumiSettingsTile<ImportAction>), findsNWidgets(2));
  });

  testWidgets('shows merge target only after merge into is selected', (
    tester,
  ) async {
    final proposed = ProposedImportSource(
      id: 'bookmarks',
      kind: ImportSourceKind.collection,
      selectionComplete: false,
      availableActions: const {ImportAction.configureItems},
      defaultAction: ImportAction.configureItems,
      items: [
        ProposedImportItem(
          id: 'incoming',
          availableActions: const {
            ImportAction.mergeIntoTarget,
            ImportAction.copy,
          },
          defaultAction: ImportAction.mergeIntoTarget,
          compatibleTargetIds: const {'reference'},
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        ImportActionEditor(
          proposed: proposed,
          resolved: ProposedImportPlan(
            sources: [proposed],
          ).resolveDefaults().sources.single,
          onChanged: (_) {},
          sourceLabel: (_) => 'Bookmark groups',
          itemLabel: (_) => 'Incoming',
          targetLabel: (_) => 'Reference',
        ),
      ),
    );

    expect(find.text('Target'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('shows a target picker for an ambiguous profile update', (
    tester,
  ) async {
    final proposed = ProposedImportSource(
      id: 'profiles',
      kind: ImportSourceKind.collection,
      selectionComplete: false,
      availableActions: const {ImportAction.configureItems},
      defaultAction: ImportAction.configureItems,
      items: [
        ProposedImportItem(
          id: 'profile:99',
          availableActions: const {
            ImportAction.update,
            ImportAction.copy,
            ImportAction.skip,
          },
          defaultAction: ImportAction.update,
          compatibleTargetIds: const {'profile:4', 'profile:5'},
          targetRequiredActions: const {ImportAction.update},
        ),
      ],
    );

    await tester.pumpWidget(
      _app(
        ImportActionEditor(
          proposed: proposed,
          resolved: ProposedImportPlan(
            sources: [proposed],
          ).resolveDefaults().sources.single,
          onChanged: (_) {},
          sourceLabel: (_) => 'Booru profiles',
          itemLabel: (_) => 'Remote',
          targetLabel: (id) => id,
        ),
      ),
    );

    expect(find.text('Target'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets(
    'groups incoming item actions and preserves unknown fallback rows',
    (
      tester,
    ) async {
      final proposed = ProposedImportSource(
        id: 'pinned_searches',
        kind: ImportSourceKind.collection,
        selectionComplete: false,
        availableActions: const {ImportAction.configureItems},
        defaultAction: ImportAction.configureItems,
        items: [
          for (final id in ['folder:one', 'search:one', 'search:unknown'])
            ProposedImportItem(
              id: id,
              availableActions: const {ImportAction.copy, ImportAction.skip},
              defaultAction: ImportAction.copy,
              compatibleTargetIds: const {},
            ),
        ],
      );
      await tester.pumpWidget(
        _app(
          ImportActionEditor(
            proposed: proposed,
            resolved: ProposedImportPlan(
              sources: [proposed],
            ).resolveDefaults().sources.single,
            onChanged: (_) {},
            sourceLabel: (_) => 'Pinned searches',
            itemLabel: (id) => id == 'search:unknown' ? 'Unknown search' : id,
            targetLabel: (id) => id,
            itemTree: const ExportSelectionDescriptor.collection(
              id: 'pinned_searches',
              children: [
                ExportSelectionNode(
                  id: 'folder:one',
                  children: [ExportSelectionNode(id: 'search:one')],
                ),
              ],
            ),
            itemPresentation: const ExportSelectionPresentation(
              items: {
                'folder:one': ExportItemPresentation(label: 'Landscapes'),
                'search:one': ExportItemPresentation(
                  label: 'Blue sky',
                  trailingLabel: 'Profile A',
                ),
              },
            ),
          ),
        ),
      );

      expect(find.text('Landscapes'), findsOneWidget);
      expect(find.text('Blue sky'), findsNothing);
      expect(find.text('Unknown search'), findsOneWidget);

      await tester.tap(find.text('Landscapes'));
      await tester.pumpAndSettle();

      expect(find.text('Blue sky'), findsWidgets);
      expect(find.text('Profile A'), findsOneWidget);
      expect(find.byType(KurumiSettingsTile<ImportAction>), findsNWidgets(4));
    },
  );

  testWidgets('failed imports show a friendly recovery action', (
    tester,
  ) async {
    var recovered = false;
    await tester.pumpWidget(
      _app(
        ImportErrorView(
          onChooseAnother: () => recovered = true,
        ),
      ),
    );

    expect(find.text('This export could not be opened'), findsOneWidget);
    expect(find.textContaining('StateError'), findsNothing);
    await tester.tap(find.text('Choose another export'));
    expect(recovered, true);
  });

  testWidgets('completed imports offer a clear way to leave', (
    tester,
  ) async {
    var done = false;
    await tester.pumpWidget(
      _app(ImportCompletionView(onDone: () => done = true)),
    );

    expect(find.text('Import complete'), findsOneWidget);
    await tester.tap(find.text('Done'));
    expect(done, true);
  });

  testWidgets('completed imports summarize what changed', (tester) async {
    await tester.pumpWidget(
      _app(
        ImportCompletionView(
          summary: const PlannedChangeSummary(created: 1, updated: 2),
          onDone: () {},
        ),
      ),
    );

    expect(find.text('Create 1 · Update 2'), findsOneWidget);
  });

  test('only mutations count as import work', () {
    expect(
      importHasChanges(const PlannedChangeSummary(unchanged: 4, preserved: 2)),
      false,
    );
    expect(importHasChanges(const PlannedChangeSummary(updated: 1)), true);
  });

  test('planned changes omit zero and unchanged counters', () {
    final labels = plannedChangeCountLabels(
      const PlannedChangeSummary(created: 2, deleted: 1, unchanged: 8),
      createdTemplate: 'Create {count}',
      updatedTemplate: 'Update {count}',
      deletedTemplate: 'Remove {count}',
    );

    expect(labels, ['Create 2', 'Remove 1']);
  });
}

Widget _app(Widget child) => TranslationProvider(
  child: MaterialApp(home: Scaffold(body: child)),
);
