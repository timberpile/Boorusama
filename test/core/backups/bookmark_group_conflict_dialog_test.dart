// Package imports:
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';

// Project imports:
import 'package:boorusama/core/backups/sources/bookmark_import_plan.dart';
import 'package:boorusama/core/backups/widgets/bookmark_group_conflict_dialog.dart';

void main() {
  const conflict = BookmarkGroupImport(
    id: '550e8400-e29b-41d4-a716-446655440000',
    name: 'Shared',
    bookmarkIds: {},
    conflicts: true,
  );

  testWidgets('returns merge with apply to remaining selected', (tester) async {
    BookmarkGroupConflictDecision? result;
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showBookmarkGroupConflictDialog(
                  context,
                  conflict: conflict,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();

    expect(result?.choice, BookmarkGroupConflictChoice.merge);
    expect(result?.applyToRemaining, isTrue);
  });

  testWidgets('cancelling any conflict cancels the entire import', (
    tester,
  ) async {
    BookmarkImportPlan? result;
    const plan = BookmarkImportPlan(
      bookmarks: [],
      missingBookmarks: [],
      groups: [conflict],
    );
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await resolveBookmarkGroupConflicts(context, plan);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('apply to remaining resolves later conflicts without prompting', (
    tester,
  ) async {
    BookmarkImportPlan? result;
    const plan = BookmarkImportPlan(
      bookmarks: [],
      missingBookmarks: [],
      groups: [
        conflict,
        BookmarkGroupImport(
          id: '5f1d7f5e-3114-4dc7-a347-18f95852fc31',
          name: 'Second',
          bookmarkIds: {},
          conflicts: true,
        ),
      ],
    );
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await resolveBookmarkGroupConflicts(context, plan);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    expect(find.text('Second'), findsNothing);
    expect(
      result?.groups.map((group) => group.choice),
      everyElement(BookmarkGroupConflictChoice.replace),
    );
  });
}
