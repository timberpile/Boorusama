import 'package:boorusama/core/backups/mitemite/name_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'long original name remains reachable with enlarged text and keyboard',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetViewInsets);
      final original = List.filled(20, 'Source').join(' ');
      String? saved;
      await tester.pumpWidget(
        BooruLocalization(
          child: MaterialApp(
            builder: (context, child) =>
                MaterialUiCompatibilityBridge(child: child!),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await showSyncNameDialog(
                    context,
                    title: 'Edit Alias',
                    initial: 'Private name',
                    sourceName: original,
                    allowEmpty: true,
                    hint: 'Leave empty to use the original name.',
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
      expect(find.text('Original Name: $original'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextField));
      await tester.showKeyboard(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, '');
      expect(tester.takeException(), isNull);
    },
  );
}
