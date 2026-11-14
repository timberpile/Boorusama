import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/backups/folder_sync/storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late DirectoryFolderSyncStorage storage;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('folder-sync-storage-');
    storage = DirectoryFolderSyncStorage(directory.path);
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test('desktop immutable publication is bounded and byte verified', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    await storage.writeImmutable('devices/test/1.bsexport', bytes);
    expect(await storage.read('devices/test/1.bsexport'), bytes);
    await storage.writeImmutable('devices/test/1.bsexport', bytes);
    await expectLater(
      storage.writeImmutable(
        'devices/test/1.bsexport',
        Uint8List.fromList([4]),
      ),
      throwsStateError,
    );
    await expectLater(
      storage.read('devices/test/1.bsexport', maxBytes: 2),
      throwsFormatException,
    );
    expect(await storage.list('devices/test'), ['1.bsexport']);
  });
  test('separate storage writers cannot replace an immutable winner', () async {
    final other = DirectoryFolderSyncStorage(directory.path);
    final a = Uint8List.fromList([1]);
    final b = Uint8List.fromList([2]);
    final results = await Future.wait([
      storage
          .writeImmutable('devices/test/1.json', a)
          .then((_) => true, onError: (_) => false),
      other
          .writeImmutable('devices/test/1.json', b)
          .then((_) => true, onError: (_) => false),
    ]);
    expect(results.where((value) => value), hasLength(1));
    final bytes = await storage.read('devices/test/1.json');
    expect(bytes, anyOf(equals(a), equals(b)));
    expect(
      (await storage.list('devices/test'))
          .where((name) => name.endsWith('.partial')),
      isEmpty,
    );
  });
  test(
    'shared-folder symbolic links and traversal never read external files',
    () async {
      await Directory('${storage.root.path}/devices').create(recursive: true);
      final outside = File('${directory.path}/outside.txt');
      await outside.writeAsString('private');
      await Link('${storage.root.path}/devices/linked').create(outside.path);
      await expectLater(storage.read('devices/linked'), throwsFormatException);
      await expectLater(storage.read('../outside.txt'), throwsFormatException);
      await expectLater(
        storage.writeImmutable('/absolute', Uint8List(0)),
        throwsFormatException,
      );
    },
    skip: Platform.isWindows
        ? 'Symlink creation requires Windows privileges'
        : false,
  );
  test(
    'retention deletion accepts only exact own revision and catalog identities',
    () async {
      const owner = '10000000-0000-4000-8000-000000000001';
      const foreign = '10000000-0000-4000-8000-000000000002';
      const source = '10000000-0000-4000-8000-000000000003';
      final bytes = Uint8List.fromList([1]);
      const owned = 'devices/$owner/collections/bookmarks/$source/1.bsexport';
      const other = 'devices/$foreign/collections/bookmarks/$source/1.bsexport';
      await storage.writeImmutable(owned, bytes);
      await storage.writeImmutable(other, bytes);
      for (final path in [
        other,
        'devices/$owner/identity.json',
        'devices/$owner/catalog/notes.json',
        'devices/$owner/collections/bookmarks/$source/001.json',
        'devices/$owner/collections/bookmarks/$source/1.partial',
      ]) {
        await expectLater(
          storage.deleteOwnedRevision(path, owner: owner),
          throwsFormatException,
        );
      }
      await storage.deleteOwnedRevision(owned, owner: owner);
      expect(await storage.read(owned), isNull);
      expect(await storage.read(other), bytes);
    },
  );
}
