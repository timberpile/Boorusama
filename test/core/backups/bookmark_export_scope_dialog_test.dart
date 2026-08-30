import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';

import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/widgets/bookmark_export_scope_dialog.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';

void main() {
  setUpAll(() async {
    await ensureI18nInitialized('en-US');
  });

  final groups = [
    const BookmarkGroup(id: 10, name: 'Favorites'),
    const BookmarkGroup(id: 20, name: 'Other'),
  ];

  Future<void> openDialog(
    WidgetTester tester,
    void Function(Future<BookmarkExportScope?> result) onOpened,
  ) async {
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                onOpened(
                  showBookmarkExportScopeDialog(
                    context,
                    groups: groups,
                  ),
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
  }

  testWidgets('defaults to exporting all bookmarks', (tester) async {
    late Future<BookmarkExportScope?> resultFuture;
    await openDialog(tester, (result) => resultFuture = result);

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(await resultFuture, const BookmarkExportScope.all());
  });

  testWidgets('cancelling the dialog returns no export scope', (tester) async {
    late Future<BookmarkExportScope?> resultFuture;
    await openDialog(tester, (result) => resultFuture = result);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await resultFuture, isNull);
  });

  testWidgets('returns selected groups and No group', (tester) async {
    late Future<BookmarkExportScope?> resultFuture;
    await openDialog(tester, (result) => resultFuture = result);

    await tester.tap(find.text('Selected groups'));
    await tester.pump();
    await tester.tap(find.text('Favorites'));
    await tester.pump();
    await tester.tap(find.text('No group'));
    await tester.pump();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result?.groupIds, {10});
    expect(result?.includeUngrouped, isTrue);
  });
}
