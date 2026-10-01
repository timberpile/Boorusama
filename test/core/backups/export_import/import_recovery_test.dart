import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/backups/export_import/import/import_journal.dart';
import 'package:boorusama/core/backups/export_import/import/import_recovery_service.dart';
import 'package:boorusama/core/backups/export_import/import/import_transaction.dart';
import 'package:boorusama/foundation/filesystem.dart';

import 'import_transaction_test_utils.dart';

void main() {
  test('startup recovery retries a retained rollback checkpoint', () async {
    final directory = await Directory.systemTemp.createTemp('import_recovery_');
    addTearDown(() => directory.delete(recursive: true));
    const fs = IoFileSystem();
    final store = ImportJournalStore(fs: fs, rootPath: directory.path);
    final source = FakeImportSource(
      'first',
      fs,
      failRestore: true,
      failApply: true,
    );
    final transaction = ImportTransaction(store: store, fs: fs);

    await expectLater(
      transaction.execute(
        transactionId: 'pending',
        plan: buildValidatedPlan(['first']),
        sources: {'first': source},
      ),
      throwsA(isA<ImportRollbackException>()),
    );
    expect(
      (await store.read('pending')).state,
      ImportJournalState.recoveryRequired,
    );

    source.failRestore = false;
    final result = await ImportRecoveryService(
      store: store,
      transaction: transaction,
      sources: () => {'first': source},
    ).recoverPending();

    expect(result.recoveredTransactionIds, ['pending']);
    expect(result.failures, isEmpty);
    expect(source.value, 'old:first');
    expect(await fs.directoryExists(store.transactionPath('pending')), isFalse);
  });
}
