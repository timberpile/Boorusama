import 'dart:io';

import 'package:boorusama/core/backups/export_import/import/import_journal.dart';
import 'package:boorusama/core/backups/export_import/import/import_transaction.dart';
import 'package:boorusama/core/backups/folder_sync/mirror_guard.dart';
import 'package:boorusama/core/backups/folder_sync/protocol.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';

import '../export_import/import_transaction_test_utils.dart';

void main() {
  test(
    'startup authority rejects a corrupted private rollback before any grant',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'verified-recovery-',
      );
      addTearDown(() => directory.delete(recursive: true));
      const fs = IoFileSystem();
      final store = ImportJournalStore(fs: fs, rootPath: directory.path);
      var journal = await store.create(
        'received',
        buildValidatedPlan(['first']),
      );
      final source = FakeImportSource('first', fs);
      final path = '${store.rollbackPath('received', 'first')}.data';
      await source.captureRollback(path);
      final digest = syncDigest(await fs.readBytes(path));
      journal = journal.copyWith(
        state: ImportJournalState.applying,
        currentSourceId: 'first',
        rollbackHashes: {'first': digest},
      );
      await store.write(journal);
      await fs.writeString(path, 'unverified replacement');
      final guard = CollectionMirrorGuard()
        ..replaceFollowingBindings(['mirror']);
      var grants = 0;
      final transaction = ImportTransaction(
        store: store,
        fs: fs,
        verifiedLocalRestore: (restore) {
          grants++;
          return guard.recoverVerifiedLocalSnapshot(restore);
        },
      );
      final errors = await transaction.rollback(journal, {'first': source});
      expect(errors, hasLength(1));
      expect(grants, 0);
      expect(source.value, 'old:first');
      expect(
        (await store.read('received')).state,
        ImportJournalState.recoveryRequired,
      );
      expect(
        () => guard.validateFollowingEdit('mirror', definitionChanged: true),
        throwsA(isA<CollectionMirrorReadOnly>()),
      );
    },
  );
}
