import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;

import 'package:boorusama/core/backups/export_import/clipboard/export_clipboard_service.dart';
import 'package:boorusama/core/backups/export_import/export/export_flow_page.dart';
import 'package:boorusama/core/backups/export_import/export_import_page.dart';
import 'package:boorusama/foundation/filesystem.dart';

void main() {
  testWidgets(
    'clipboard action stays named as an import when none is detected',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exportClipboardServiceProvider.overrideWithValue(
              const ExportClipboardService(
                fs: IoFileSystem(),
                clipboard: _EmptyClipboard(),
              ),
            ),
          ],
          child: TranslationProvider(
            child: const MaterialApp(home: ExportImportPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Import from clipboard'), findsOneWidget);
      expect(find.text('Paste Base64 export'), findsNothing);
    },
  );
}

final class _EmptyClipboard implements ExportClipboardPort {
  const _EmptyClipboard();

  @override
  Future<bool> containsExport() async => false;

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String value) async {}
}
