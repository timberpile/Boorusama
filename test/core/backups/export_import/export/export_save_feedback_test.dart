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
import 'package:oktoast/oktoast.dart';

void main() {
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
  const _SaveDestination(this.result);
  final String result;

  @override
  Future<bool> save(String source) async {
    if (result == 'error') throw PlatformException(code: 'export_save_failed');
    return result == 'saved';
  }
}
