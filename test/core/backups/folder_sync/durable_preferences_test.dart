import 'dart:io';

import 'package:boorusama/core/backups/folder_sync/durable_preferences.dart';
import 'package:boorusama/core/cache/hive_misc_data_store.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  test(
    'authority writes wait for file and parent-directory durability',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sync_authority_',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<String>('sync_preferences');
      final fs = _Barriers();
      final store = DurableSyncPreferences(HiveMiscDataStore(box), fs);
      try {
        await store.put('identity', 'private-local-only');
        expect(fs.calls, [box.path, directory.path]);
        expect(store.get('identity'), 'private-local-only');
        fs.fail = true;
        await expectLater(store.put('sequence', '2'), throwsStateError);
        // A failed barrier must not be reported as a successful reservation.
      } finally {
        await box.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

class _Barriers extends IoFileSystem {
  final calls = <String>[];
  bool fail = false;
  @override
  Future<void> syncFile(String path) async {
    calls.add(path);
    if (fail) throw StateError('Injected sync failure');
    await super.syncFile(path);
  }

  @override
  Future<void> syncDirectory(String path) async {
    calls.add(path);
    await super.syncDirectory(path);
  }
}
