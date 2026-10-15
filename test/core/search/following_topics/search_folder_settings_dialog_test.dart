import 'package:boorusama/core/search/following_topics/src/widgets/search_folder_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';

void main() {
  for (final keyboard in [false, true]) {
    testWidgets('folder settings fit at 320px, 2x text, keyboard $keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SearchFolderSettings? saved;
      await tester.pumpWidget(
        BooruLocalization(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                viewInsets: EdgeInsets.only(bottom: keyboard ? 280 : 0),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    saved = await showSearchFolderSettingsDialog(context);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Mixed topics');
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(find.text('1000'), findsOneWidget);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('2000').last);
      await tester.tap(find.text('2000').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(saved?.name, 'Mixed topics');
      expect(saved?.feedEnabled, isTrue);
      expect(saved?.maxPosts, 2000);
      expect(tester.takeException(), isNull);
    });
  }
}
