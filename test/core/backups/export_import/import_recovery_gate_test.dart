import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;

import 'package:boorusama/core/backups/export_import/import/import_recovery_gate.dart';
import 'package:boorusama/core/backups/export_import/import/import_recovery_service.dart';

void main() {
  testWidgets('ordinary startup does not claim an import is recovering', (
    tester,
  ) async {
    final pending = Completer<ImportRecoveryResult>();
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            importRecoveryProvider.overrideWith(
              () => _PendingRecoveryNotifier(pending.future),
            ),
          ],
          child: const ImportRecoveryGate(
            child: MaterialApp(home: Text('App ready')),
          ),
        ),
      ),
    );

    expect(find.text('Recovering an interrupted import…'), findsNothing);
    pending.complete(
      ImportRecoveryResult(
        recoveredTransactionIds: [],
        failures: {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('App ready'), findsOneWidget);
  });

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

class _PendingRecoveryNotifier extends ImportRecoveryNotifier {
  _PendingRecoveryNotifier(this.pending);

  final Future<ImportRecoveryResult> pending;

  @override
  Future<ImportRecoveryResult> build() => pending;
}
