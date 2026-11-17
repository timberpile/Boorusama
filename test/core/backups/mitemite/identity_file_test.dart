import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/backups/mitemite/identity_file.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:boorusama/core/backups/mitemite/storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('partial own identity bytes remain immutable; a different folder retains the same publisher', () async {
    final directory = await Directory.systemTemp.createTemp('sync_identity_');
    try {
      final identity = await SyncSigningIdentity.create();
      final broken = DirectoryMiteMiteStorage('${directory.path}/broken');
      final path = 'devices/${identity.id}/identity.json';
      final partial = Uint8List.fromList([123]);
      await broken.writeImmutable(path, partial);
      await expectLater(
        writeOwnSyncIdentity(broken, identity),
        throwsA(isA<SyncOwnIdentityUnavailable>()),
      );
      expect(await broken.read(path), partial);
      final recovered = DirectoryMiteMiteStorage(
        '${directory.path}/recovered',
      );
      await writeOwnSyncIdentity(recovered, identity);
      await writeOwnSyncIdentity(recovered, identity);
      expect(await recovered.read(path), syncJsonBytes(identity.publicJson()));
      expect(await broken.read(path), partial);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
