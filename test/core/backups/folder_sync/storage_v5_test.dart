// Shared-directory checks must not block the UI isolate; keep async I/O.
// ignore_for_file: avoid_slow_async_io

import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/backups/folder_sync/storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new storage uses only the approved v1 root', () async {
    final directory = await Directory.systemTemp.createTemp('sync-v5-');
    try {
      final storage = DirectoryFolderSyncStorage(directory.path);
      await storage.writeImmutable(
        'devices/test/1.json',
        Uint8List.fromList([1]),
      );
      expect(
        await File('${directory.path}/v1/devices/test/1.json').exists(),
        isTrue,
      );
      expect(
        await Directory('${directory.path}/BoorusamaSync').exists(),
        isFalse,
      );
      expect(await storage.read('devices/missing/1.json'), isNull);
      await expectLater(
        storage.read('devices/test/1.json', maxBytes: -1),
        throwsArgumentError,
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('SAF identifiers must never be interpreted as filesystem paths', () {
    expect(
      () => DirectoryFolderSyncStorage('content://documents/tree/example'),
      throwsArgumentError,
    );
  });
}
