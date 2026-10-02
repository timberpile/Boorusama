import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;

import 'package:boorusama/core/backups/export_import/import/import_issue_message.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';

void main() {
  testWidgets('describes a missing selected item without internal codes', (
    tester,
  ) async {
    late String message;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              message = importIssueMessage(
                context,
                const ImportPlanIssue(
                  code: 'unknown_selected_item',
                  sourceId: 'bookmarks',
                  itemId: 'group:references',
                ),
                sourceNames: const {'bookmarks': 'Bookmark groups'},
                itemLabels: const {'group:references': 'References'},
              );
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(
      message,
      'References is selected but missing from Bookmark groups.',
    );
    expect(message, isNot(contains('unknown_selected_item')));
  });
}
