import 'package:boorusama/core/search/subscriptions/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    String? initialName,
    bool isPinned = false,
    required void Function(String?) onResult,
  }) async {
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => onResult(
                  await showPinSearchDialog(
                    context,
                    query: 'cat rating:safe',
                    initialName: initialName,
                    isPinned: isPinned,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the query as context and starts with an empty name', (
    tester,
  ) async {
    await open(tester, onResult: (_) {});
    expect(find.text('cat rating:safe'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets(
    'opening leaves the keyboard closed and tapping the name allows editing',
    (tester) async {
      await open(tester, onResult: (_) {});
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
    },
  );

  for (final c in [
    (input: '   ', result: ''),
    (input: '  Safe cats  ', result: 'Safe cats'),
  ]) {
    testWidgets('submitting "${c.input}" returns "${c.result}"', (
      tester,
    ) async {
      String? result;
      await open(tester, onResult: (value) => result = value);
      await tester.enterText(find.byType(TextField), c.input);
      await tester.tap(find.text('Pin'));
      await tester.pumpAndSettle();
      expect(result, c.result);
    });
  }

  testWidgets('cancelling returns null without saving the entered name', (
    tester,
  ) async {
    String? result = 'not cancelled';
    await open(tester, onResult: (value) => result = value);
    await tester.enterText(find.byType(TextField), 'Cats');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('an existing pin pre-fills its name and saves edits', (
    tester,
  ) async {
    String? result;
    await open(
      tester,
      initialName: 'Cats',
      isPinned: true,
      onResult: (value) => result = value,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Cats',
    );
    expect(find.text('Pin'), findsNothing);
    await tester.enterText(find.byType(TextField), '  Kittens  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, 'Kittens');
  });
}
