import 'package:crypto/crypto.dart';

import '../../../../foundation/filesystem.dart';
import 'import_journal.dart';
import 'import_plan.dart';
import 'import_preflight.dart';
import '../models/import_action.dart';

abstract interface class ImportTransactionSource {
  String get id;

  Future<String> revisionToken();
  Future<void> captureRollback(String outputPath);
  Future<void> apply(ResolvedImportSource plan);
  Future<void> restore(String rollbackPath);
}

class StaleImportPlanException implements Exception {
  const StaleImportPlanException(this.sourceIds);

  final Set<String> sourceIds;
}

class ImportRollbackException implements Exception {
  const ImportRollbackException({
    required this.importError,
    required this.rollbackErrors,
    required this.transactionId,
  });

  final Object importError;
  final List<Object> rollbackErrors;
  final String transactionId;
}

final class ImportTransaction {
  const ImportTransaction({required this.store, required this.fs});

  final ImportJournalStore store;
  final AppFileSystem fs;

  Future<void> execute({
    required String transactionId,
    required ValidatedImportPlan plan,
    required Map<String, ImportTransactionSource> sources,
  }) async {
    final selectedPlans = [
      for (final source in plan.plan.sources)
        if (source.action != ImportAction.skip) source,
    ];
    for (final source in selectedPlans) {
      if (sources[source.id] == null) {
        throw StateError('Import source is unavailable: ${source.id}');
      }
    }
    var journal = await store.create(transactionId, plan);
    try {
      final rollbackHashes = <String, String>{};
      for (final sourcePlan in selectedPlans) {
        final path = '${store.rollbackPath(transactionId, sourcePlan.id)}.data';
        await sources[sourcePlan.id]!.captureRollback(path);
        await fs.syncFile(path);
        rollbackHashes[sourcePlan.id] = await _digest(path);
      }
      await fs.syncDirectory(
        '${store.transactionPath(transactionId)}/rollback',
      );
      journal = journal.copyWith(
        state: ImportJournalState.prepared,
        rollbackHashes: rollbackHashes,
      );
      await store.write(journal);

      final stale = <String>{};
      for (final sourcePlan in selectedPlans) {
        final actual = await sources[sourcePlan.id]!.revisionToken();
        if (actual != plan.revisionTokens[sourcePlan.id]) {
          stale.add(sourcePlan.id);
        }
      }
      if (stale.isNotEmpty) {
        await store.delete(transactionId);
        throw StaleImportPlanException(stale);
      }

      for (final sourcePlan in selectedPlans) {
        journal = journal.copyWith(
          state: ImportJournalState.applying,
          currentSourceId: sourcePlan.id,
        );
        await store.write(journal);
        await sources[sourcePlan.id]!.apply(sourcePlan);
        journal = journal.copyWith(
          state: ImportJournalState.applied,
          completedSourceIds: [...journal.completedSourceIds, sourcePlan.id],
          clearCurrentSource: true,
        );
        await store.write(journal);
      }
      journal = journal.copyWith(state: ImportJournalState.committed);
      await store.write(journal);
      await store.delete(transactionId);
    } on StaleImportPlanException {
      rethrow;
    } catch (error, stackTrace) {
      final rollbackErrors = await rollback(journal, sources);
      if (rollbackErrors.isNotEmpty) {
        throw ImportRollbackException(
          importError: error,
          rollbackErrors: rollbackErrors,
          transactionId: transactionId,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<List<Object>> rollback(
    ImportJournal journal,
    Map<String, ImportTransactionSource> sources,
  ) async {
    final errors = <Object>[];
    var current = journal.copyWith(state: ImportJournalState.rollingBack);
    await store.write(current);
    final restoreIds = <String>[
      ?journal.currentSourceId,
      ...journal.completedSourceIds.reversed.where(
        (id) => id != journal.currentSourceId,
      ),
    ];
    for (final id in restoreIds) {
      try {
        final source = sources[id];
        if (source == null) {
          throw StateError('Import source is unavailable: $id');
        }
        final path = '${store.rollbackPath(journal.transactionId, id)}.data';
        if (await _digest(path) != journal.rollbackHashes[id]) {
          throw StateError('Rollback payload failed verification: $id');
        }
        await source.restore(path);
      } catch (error) {
        errors.add(error);
      }
    }
    if (errors.isEmpty) {
      current = current.copyWith(
        state: ImportJournalState.recovered,
        clearCurrentSource: true,
      );
      await store.write(current);
      await store.delete(journal.transactionId);
    } else {
      await store.write(
        current.copyWith(
          state: ImportJournalState.recoveryRequired,
          error: errors.join('\n'),
        ),
      );
    }
    return errors;
  }

  Future<String> _digest(String path) async =>
      (await sha256.bind(fs.openRead(path)).first).toString();
}
