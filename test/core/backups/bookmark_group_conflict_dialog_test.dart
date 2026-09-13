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
}
