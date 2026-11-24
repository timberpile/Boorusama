import 'package:collection/collection.dart';

import 'protocol.dart';
import 'storage.dart';

/// A different Storage Location can recover publication without changing local
/// signing identity, source IDs, trust, counters or receiver journals.
final class SyncOwnIdentityUnavailable implements Exception {
  const SyncOwnIdentityUnavailable();
}

Future<void> writeOwnSyncIdentity(
  MiteMiteStorage storage,
  SyncSigningIdentity identity,
) async {
  final path = 'devices/${identity.id}/identity.json';
  final expected = syncJsonBytes(identity.publicJson());
  bool differs(List<int> bytes) =>
      !const ListEquality<int>().equals(bytes, expected);
  final existing = await storage.read(
    path,
    maxBytes: miteMiteMaxMetadataBytes,
  );
  if (existing != null) {
    if (differs(existing)) throw const SyncOwnIdentityUnavailable();
    return;
  }
  try {
    await storage.writeImmutable(path, expected);
  } catch (_) {
    // A provider may have retained a partial final document. Never overwrite it
    // or silently rotate the publisher; a fresh location is the safe repair.
    try {
      final retained = await storage.read(
        path,
        maxBytes: miteMiteMaxMetadataBytes,
      );
      if (retained != null && differs(retained)) {
        throw const SyncOwnIdentityUnavailable();
      }
    } on SyncOwnIdentityUnavailable {
      rethrow;
    } catch (_) {
      /* Retain the original I/O failure. */
    }
    rethrow;
  }
}
