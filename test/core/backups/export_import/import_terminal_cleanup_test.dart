import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/backups/export_import/import/import_journal.dart';
import 'package:boorusama/core/backups/export_import/import/import_recovery_service.dart';
import 'package:boorusama/core/backups/export_import/import/import_transaction.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';

import 'import_transaction_test_utils.dart';

void main() {
  late Directory root;
  late _CleanupFaultFileSystem fs;
  late ImportJournalStore store;
  late FakeImportSource source;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('import_terminal_cleanup_');
    fs = _CleanupFaultFileSystem('interrupted');
    store = ImportJournalStore(fs: fs, rootPath: root.path);
    source = FakeImportSource('first', fs);
  });
  tearDown(() => root.delete(recursive: true));

  Future<void> execute() => ImportTransaction(store: store, fs: fs).execute(
    transactionId: 'interrupted',
    plan: buildValidatedPlan(['first']),
    sources: {'first': source},
  );

  for (final fault in _CleanupFault.values) {
    test('committed import survives ${fault.name} and cold recovery', () async {
      fs.fault = fault;
      await execute();
      expect(fs.injected, isTrue);
      expect(source.value, 'imported:first');

      final reopened = ImportJournalStore(
        fs: const IoFileSystem(),
        rootPath: root.path,
      );
      final result = await ImportRecoveryService(
        store: reopened,
        transaction: ImportTransaction(store: reopened, fs: reopened.fs),
        sources: () => throw StateError('Terminal cleanup cannot restore data'),
      ).recoverPending();

      expect(result.failures, isEmpty);
      expect(await root.list().toList(), isEmpty);
      expect(source.value, 'imported:first');
    });
  }
  test(
    'rollback remains recovered and preserves the original apply error',
    () async {
      source = FakeImportSource('first', fs, failApply: true);
      fs.fault = _CleanupFault.partialDelete;
      await expectLater(execute(), throwsStateError);
      expect(fs.injected, isTrue);
      expect(source.value, 'old:first');

      expect(await store.pending(), isEmpty);
      expect(await root.list().toList(), isEmpty);
    },
  );

  test('a stale plan retains its error through cleanup failure', () async {
    source = FakeImportSource('first', fs, revision: 'changed');
    fs.fault = _CleanupFault.partialDelete;
    await expectLater(execute(), throwsA(isA<StaleImportPlanException>()));
    expect(fs.injected, isTrue);
    expect(source.applyCount, 0);
    expect(await store.pending(), isEmpty);
  });

  test(
    'a nonterminal journal cannot be retired or mistaken for cleanup',
    () async {
      final journal = await store.create(
        'interrupted',
        buildValidatedPlan(['first']),
      );
      final applying = journal.copyWith(
        state: ImportJournalState.applying,
        currentSourceId: 'first',
      );
      await store.write(applying);
      await expectLater(store.retire(applying), throwsFormatException);

      final retired = '${root.path}/.retired-interrupted';
      await Directory(store.transactionPath('interrupted')).rename(retired);
      await expectLater(store.pending(), throwsFormatException);
      expect(File('$retired/journal.json').existsSync(), isTrue);
    },
  );

  test('stale preparing snapshot cannot retire an applying journal', () async {
    final previous = await store.create(
      'interrupted',
      buildValidatedPlan(['first']),
    );
    final applying = previous.copyWith(
      state: ImportJournalState.applying,
      currentSourceId: 'first',
    );
    await store.write(applying);
    await expectLater(store.retire(previous), throwsFormatException);
    expect(await store.read('interrupted'), applying);
  });

  for (final suffix in ['tmp', 'bak']) {
    test(
      'a released terminal journal in .$suffix survives interrupted retirement',
      () async {
        final journal = await store.create(
          'interrupted',
          buildValidatedPlan(['first']),
        );
        await store.write(
          journal.copyWith(state: ImportJournalState.committed),
        );
        final primary = File(
          '${store.transactionPath('interrupted')}/journal.json',
        );
        await primary.rename('${primary.path}.$suffix');
        fs.fault = _CleanupFault.partialDelete;
        final recovery = ImportRecoveryService(
          store: store,
          transaction: ImportTransaction(store: store, fs: fs),
          sources: () =>
              throw StateError('Terminal cleanup cannot restore data'),
        );
        expect((await recovery.recoverPending()).failures, isEmpty);
        expect(fs.injected, isTrue);
        expect((await recovery.recoverPending()).failures, isEmpty);
        expect(await root.list().toList(), isEmpty);
      },
    );
  }

  test('retired identity must match its directory', () async {
    final journal = await store.create(
      'interrupted',
      buildValidatedPlan(['first']),
    );
    final retired = await Directory('${root.path}/.retired-mismatch').create();
    await File('${retired.path}/journal.json')
        .writeAsString(jsonEncode(journal.toJson()));
    await expectLater(store.pending(), throwsFormatException);
    expect(retired.existsSync(), isTrue);
  });

  test(
    'a pending retirement reserves its ID and unsafe IDs are rejected',
    () async {
      fs.fault = _CleanupFault.beforeDelete;
      await execute();
      final plan = buildValidatedPlan(['first']);
      await expectLater(store.create('interrupted', plan), throwsStateError);
      for (final id in [
        '../escape',
        'a/b',
        r'a\b',
        '',
        '.retired-interrupted',
      ]) {
        await expectLater(store.create(id, plan), throwsFormatException);
      }
    },
  );

  for (final state in [
    ImportJournalState.preparing,
    ImportJournalState.committed,
    ImportJournalState.recovered,
  ]) {
    test('startup retires a legacy ${state.name} directory', () async {
      final journal = await store.create(
        'interrupted',
        buildValidatedPlan(['first']),
      );
      await store.write(journal.copyWith(state: state));
      fs.fault = _CleanupFault.partialDelete;
      final recovery = ImportRecoveryService(
        store: store,
        transaction: ImportTransaction(store: store, fs: fs),
        sources: () => throw StateError('Terminal cleanup cannot restore data'),
      );
      expect((await recovery.recoverPending()).failures, isEmpty);
      expect(fs.injected, isTrue);
      expect((await recovery.recoverPending()).failures, isEmpty);
      expect(await root.list().toList(), isEmpty);
    });
  }
}

enum _CleanupFault {
  beforeRename,
  retirementSync,
  obsoleteBackup,
  beforeDelete,
  partialDelete,
  afterDelete,
}

final class _CleanupFaultFileSystem extends IoFileSystem {
  _CleanupFaultFileSystem(this.transactionId);

  final String transactionId;
  _CleanupFault? fault;
  var injected = false;

  var publishingCommit = false;

  @override
  Future<void> writeString(String path, String content, {bool flush = false}) {
    if (path.endsWith('/journal.json.tmp')) {
      publishingCommit = jsonDecode(content)['state'] == 'committed';
    }
    return super.writeString(path, content, flush: flush);
  }

  @override
  Future<void> deleteFileIfExists(String path) => Future<void>.sync(() {
    if (fault == _CleanupFault.obsoleteBackup &&
        publishingCommit &&
        !injected &&
        path.endsWith('/journal.json.bak')) {
      injected = true;
      throw FileSystemException(
        'Injected obsolete backup cleanup failure',
        path,
      );
    }
    return super.deleteFileIfExists(path);
  });

  @override
  Future<void> renameDirectory(String source, String destination) =>
      Future<void>.sync(() {
        if (fault == _CleanupFault.beforeRename && !injected) {
          injected = true;
          throw FileSystemException(
            'Injected retirement rename failure',
            source,
          );
        }
        return super.renameDirectory(source, destination);
      });

  @override
  Future<void> syncDirectory(String path) => Future<void>.sync(() {
    if (fault == _CleanupFault.retirementSync &&
        !injected &&
        directoryExistsSync('$path/.retired-$transactionId')) {
      injected = true;
      throw FileSystemException('Injected retirement sync failure', path);
    }
    return super.syncDirectory(path);
  });

  @override
  Future<void> deleteDirectory(String path, {bool recursive = false}) async {
    if (fault == null ||
        injected ||
        !(path.endsWith('/$transactionId') ||
            path.endsWith('/.retired-$transactionId'))) {
      return super.deleteDirectory(path, recursive: recursive);
    }
    injected = true;
    switch (fault!) {
      case _CleanupFault.beforeRename:
      case _CleanupFault.retirementSync:
      case _CleanupFault.obsoleteBackup:
        return super.deleteDirectory(path, recursive: recursive);
      case _CleanupFault.beforeDelete:
        break;
      case _CleanupFault.partialDelete:
        await deleteFile('$path/journal.json');
        await deleteFileIfExists('$path/rollback/first.data');
      case _CleanupFault.afterDelete:
        await super.deleteDirectory(path, recursive: recursive);
    }
    throw FileSystemException('Injected terminal cleanup interruption', path);
  }
}
