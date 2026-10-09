import 'package:boorusama/core/backups/export_import/export/export_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/export/export_flow_page.dart';
import 'package:boorusama/core/backups/export_import/export/export_save_service.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/export_import/models/export_item_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:oktoast/oktoast.dart';

void main() {
  testWidgets('a renamed export uses the custom name when saving', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final destination = _SaveDestination('saved');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exportImportSourcesProvider.overrideWithValue(const []),
          exportSelectionPresentationProvider.overrideWithValue(
            const ExportSelectionPresentation(items: {}),
          ),
          exportFlowProvider.overrideWith(_ReadyExport.new),
          androidExportSaveServiceProvider.overrideWithValue(destination),
        ],
        child: TranslationProvider(
          child: const OKToast(child: MaterialApp(home: ExportFlowPage())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editButton = find.byTooltip('Edit file name');
    await tester.ensureVisible(editButton);
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    final dialog = find.byType(KurumiDialog);
    expect(dialog, findsOneWidget);
    for (final invalid in ['../invalid', 'Favorites .bsexport']) {
      await tester.enterText(
        find.byKey(const ValueKey('export-file-name-input')),
        invalid,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a valid file name without reserved characters.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(of: dialog, matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNull,
      );
    }

    await tester.enterText(
      find.byKey(const ValueKey('export-file-name-input')),
      'My favorites',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, 'Save'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My favorites.bsexport'), findsOneWidget);

    final saveButton = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
    expect(destination.receivedFileName, 'My favorites.bsexport');
    await tester.pump(const Duration(seconds: 5));
  });

  for (final result in ['error', 'cancel', 'saved']) {
    testWidgets('$result saving shows only the appropriate feedback', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exportImportSourcesProvider.overrideWithValue(const []),
            exportSelectionPresentationProvider.overrideWithValue(
              const ExportSelectionPresentation(items: {}),
            ),
            exportFlowProvider.overrideWith(_ReadyExport.new),
            androidExportSaveServiceProvider.overrideWithValue(
              _SaveDestination(result),
            ),
          ],
          child: TranslationProvider(
            child: const OKToast(child: MaterialApp(home: ExportFlowPage())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Export saved'),
        result == 'saved' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text(
          'Could not save the export to this folder. Choose another folder and try again.',
        ),
        result == 'error' ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
    });
  }
}

class _ReadyExport extends ExportFlowNotifier {
  @override
  ExportFlowState build() => const ExportFlowState(
    isFull: true,
    nodes: {},
    includeCredentials: true,
    status: ExportFlowStatus.ready,
    packagePath: '/cache/export.bsexport',
  );
}

class _SaveDestination extends AndroidExportSaveService {
  _SaveDestination(this.result);
  final String result;
  String? receivedFileName;

  @override
  Future<bool> save(String source, {String? fileName}) async {
    receivedFileName = fileName;
    if (result == 'error') throw PlatformException(code: 'export_save_failed');
    return result == 'saved';
  }
}
