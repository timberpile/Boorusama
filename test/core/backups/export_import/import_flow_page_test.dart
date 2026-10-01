import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;

import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
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
}

Widget _app(Widget child) => TranslationProvider(
  child: MaterialApp(home: Scaffold(body: child)),
);
