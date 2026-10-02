import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/backups/export_import/import/import_journal.dart';
import 'package:boorusama/core/backups/export_import/import/import_transaction.dart';
import 'package:boorusama/foundation/filesystem.dart';

import 'import_transaction_test_utils.dart';

void main() {
  late Directory directory;
  late ImportJournalStore store;
  const fs = IoFileSystem();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('import_transaction_');
    store = ImportJournalStore(fs: fs, rootPath: directory.path);
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'a successful transaction applies in order and removes its journal',
    () async {
      final log = <String>[];
      final first = FakeImportSource('first', fs, log: log);
      final second = FakeImportSource('second', fs, log: log);

      await ImportTransaction(store: store, fs: fs).execute(
        transactionId: 'success',
        plan: buildValidatedPlan(['first', 'second']),
        sources: {'first': first, 'second': second},
      );

      expect(log, ['apply:first', 'apply:second']);
      expect(first.value, 'imported:first');
      expect(second.value, 'imported:second');
      expect(
        await fs.directoryExists(store.transactionPath('success')),
        isFalse,
      );
    },
  );

  test(
    'a failed source restores the started and completed sources in reverse',
    () async {
      final log = <String>[];
      final first = FakeImportSource('first', fs, log: log);
      final second = FakeImportSource('second', fs, log: log, failApply: true);

      await expectLater(
        ImportTransaction(store: store, fs: fs).execute(
          transactionId: 'failure',
          plan: buildValidatedPlan(['first', 'second']),
          sources: {'first': first, 'second': second},
        ),
        throwsStateError,
      );

      expect(log, [
        'apply:first',
        'apply:second',
        'restore:second',
        'restore:first',
      ]);
      expect(first.value, 'old:first');
      expect(second.value, 'old:second');
      expect(
        await fs.directoryExists(store.transactionPath('failure')),
        isFalse,
      );
    },
  );

  test('a stale repository revision aborts before any data write', () async {
    final source = FakeImportSource('first', fs, revision: 'new');

    await expectLater(
      ImportTransaction(store: store, fs: fs).execute(
        transactionId: 'stale',
        plan: buildValidatedPlan(['first']),
        sources: {'first': source},
      ),
      throwsA(isA<StaleImportPlanException>()),
    );

    expect(source.applyCount, 0);
    expect(source.value, 'old:first');
  });

  test(
    'rollback data is durable before the transaction becomes prepared',
    () async {
      final recordingFs = _RecordingFileSystem();
      final recordingStore = ImportJournalStore(
        fs: recordingFs,
        rootPath: directory.path,
      );
      final source = FakeImportSource('first', recordingFs);

      await ImportTransaction(store: recordingStore, fs: recordingFs).execute(
        transactionId: 'durable',
        plan: buildValidatedPlan(['first']),
        sources: {'first': source},
      );

      final rollbackSync = recordingFs.syncs.indexWhere(
        (entry) => entry.endsWith('/rollback/first.data'),
      );
      final rollbackDirectorySync = recordingFs.syncs.indexWhere(
        (entry) => entry.endsWith('/rollback'),
        rollbackSync + 1,
      );
      final preparedJournalSync = recordingFs.syncs.indexWhere(
        (entry) => entry.endsWith('/journal.json.tmp'),
        rollbackDirectorySync + 1,
      );
      expect(rollbackSync, greaterThanOrEqualTo(0));
      expect(rollbackDirectorySync, greaterThan(rollbackSync));
      expect(preparedJournalSync, greaterThan(rollbackDirectorySync));
    },
  );
}

final class _RecordingFileSystem extends IoFileSystem {
  final syncs = <String>[];

  @override
  Future<void> syncFile(String path) async => syncs.add(path);

  @override
  Future<void> syncDirectory(String path) async => syncs.add(path);
}
