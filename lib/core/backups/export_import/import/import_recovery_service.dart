import 'import_journal.dart';
import 'import_transaction.dart';

final class ImportRecoveryResult {
  ImportRecoveryResult({
    required Iterable<String> recoveredTransactionIds,
    required Map<String, List<Object>> failures,
  }) : recoveredTransactionIds = List.unmodifiable(recoveredTransactionIds),
       failures = Map.unmodifiable(failures);

  final List<String> recoveredTransactionIds;
  final Map<String, List<Object>> failures;
}

final class ImportRecoveryService {
  const ImportRecoveryService({
    required this.store,
    required this.transaction,
    required this.sources,
  });

  final ImportJournalStore store;
  final ImportTransaction transaction;
  final Map<String, ImportTransactionSource> Function() sources;

  Future<ImportRecoveryResult> recoverPending() async {
    final recovered = <String>[];
    final failures = <String, List<Object>>{};
    for (final journal in await store.pending()) {
      if (journal.state == ImportJournalState.preparing ||
          journal.state == ImportJournalState.committed ||
          journal.state == ImportJournalState.recovered) {
        await store.delete(journal.transactionId);
        recovered.add(journal.transactionId);
        continue;
      }
      try {
        await store.verifyPlan(journal);
      } catch (error) {
        failures[journal.transactionId] = [error];
        continue;
      }
      final errors = await transaction.rollback(journal, sources());
      if (errors.isEmpty) {
        recovered.add(journal.transactionId);
      } else {
        failures[journal.transactionId] = errors;
      }
    }
    return ImportRecoveryResult(
      recoveredTransactionIds: recovered,
      failures: failures,
    );
  }
}
