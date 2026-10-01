import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;

import 'package:boorusama/core/backups/export_import/import/import_recovery_gate.dart';
import 'package:boorusama/core/backups/export_import/import/import_recovery_service.dart';

void main() {
  testWidgets('startup continues only after pending imports recover', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ImportRecoveryResult(
          recoveredTransactionIds: const ['pending'],
          failures: const {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('App ready'), findsOneWidget);
    expect(find.text('Import recovery required'), findsNothing);
  });

  testWidgets('a rollback failure blocks the normal application', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ImportRecoveryResult(
          recoveredTransactionIds: const [],
          failures: {
            'pending': [StateError('restore failed')],
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('App ready'), findsNothing);
    expect(find.text('Import recovery required'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

Widget _app(ImportRecoveryResult result) => TranslationProvider(
  child: ProviderScope(
    overrides: [
      importRecoveryProvider.overrideWith(() => _FakeRecoveryNotifier(result)),
    ],
    child: const ImportRecoveryGate(
      child: MaterialApp(home: Text('App ready')),
    ),
  ),
);

class _FakeRecoveryNotifier extends ImportRecoveryNotifier {
  _FakeRecoveryNotifier(this.result);

  final ImportRecoveryResult result;

  @override
  Future<ImportRecoveryResult> build() async => result;
}
