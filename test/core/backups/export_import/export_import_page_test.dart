import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:oktoast/oktoast.dart';

import 'package:boorusama/core/backups/export_import/clipboard/export_clipboard_service.dart';
import 'package:boorusama/core/backups/export_import/export/export_flow_page.dart';
import 'package:boorusama/core/backups/export_import/export_import_page.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/core/settings/src/pages/backup_and_restore_page.dart';

void main() {
  testWidgets('export and import actions are inside the system safe area', (
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

    expect(
      find.ancestor(of: find.byType(ListView), matching: find.byType(SafeArea)),
      findsOneWidget,
    );
  });

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

  testWidgets('nearby send asks before broadcasting private data', (
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

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Include private data?'), findsOneWidget);
    expect(find.text('Start sending'), findsOneWidget);
  });

  testWidgets('clipboard failures use a friendly recovery message', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exportClipboardServiceProvider.overrideWithValue(
            const ExportClipboardService(
              fs: IoFileSystem(),
              clipboard: _InvalidClipboard(),
            ),
          ),
        ],
        child: OKToast(
          child: TranslationProvider(
            child: const MaterialApp(home: ExportImportPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import from clipboard'));
    await tester.pump();

    expect(
      find.text('This export could not be opened. Choose another export file.'),
      findsOneWidget,
    );
    expect(find.textContaining('StateError'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('settings opens directly on export and import actions', (
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
          child: const MaterialApp(
            home: BackupAndRestorePage(includeAutomaticExports: false),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Create export'), findsOneWidget);
  });
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

final class _InvalidClipboard implements ExportClipboardPort {
  const _InvalidClipboard();

  @override
  Future<bool> containsExport() async => true;

  @override
  Future<String?> read() async => throw StateError('raw parser detail');

  @override
  Future<void> write(String value) async {}
}
