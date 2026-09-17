import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_name_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';

void main() {
  for (final action in ['Save', 'Cancel', 'Back', 'Outside', 'Submit']) {
    testWidgets('closing with $action safely completes the dialog transition', (
      tester,
    ) async {
      String? result;
      var completed = false;
      await tester.pumpWidget(
        BooruLocalization(
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showBookmarkGroupNameDialog(
                    context,
                    title: 'Create group',
                    initialName: 'Original',
                  );
                  completed = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Edited  ');
      switch (action) {
        case 'Save' || 'Cancel':
          await tester.tap(find.text(action));
        case 'Back':
          await tester.binding.handlePopRoute();
        case 'Outside':
          await tester.tapAt(const Offset(10, 10));
        case 'Submit':
          await tester.testTextInput.receiveAction(TextInputAction.done);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(completed, isTrue);
      expect(result, action == 'Save' || action == 'Submit' ? 'Edited' : null);
    });
  }

  testWidgets('hiding input retains the name and allows further editing', (
    tester,
  ) async {
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showBookmarkGroupNameDialog(
                context,
                title: 'Create group',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'DismissalProbe');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    tester.testTextInput.hide();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.text('DismissalProbe'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Edited after dismissal');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
