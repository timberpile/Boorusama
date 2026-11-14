import 'dart:typed_data';

import 'protocol.dart';
import 'storage.dart';

/// Authenticated transport bytes, not an import or deletion authorization.
/// The caller must still validate the export archive, schema and source scope,
/// then recheck the current catalog under the shared mutation coordinator.
final class VerifiedSyncPayload {
  VerifiedSyncPayload._(this.revision, Uint8List bytes)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final SyncRevision revision;
  final Uint8List bytes;
}

/// Reads the exact signed revision named by a previously verified catalog.
/// Missing descriptor/payload is retryable unavailability, never withdrawal.
/// No filesystem listing, older-revision fallback or app mutation occurs here.
final class SyncRevisionTransport {
  const SyncRevisionTransport(this.storage);

  final FolderSyncStorage storage;

  Future<VerifiedSyncPayload?> read({
    required SyncRevision expected,
    required List<int> publisherKey,
  }) async {
    final key = List<int>.unmodifiable(publisherKey);
    final descriptorBytes = await storage.read(
      expected.descriptorPath,
      maxBytes: folderSyncMaxMetadataBytes,
    );
    if (descriptorBytes == null) return null;
    final descriptor = SyncRevision.fromJson(
      await verifySyncDocument(descriptorBytes, key),
    );
    // Bind every field, not just the revision number. Paths are derived from
    // the expected identity; never follow a path supplied by shared metadata.
    if (canonicalSyncJson(descriptor.toJson()) !=
        canonicalSyncJson(expected.toJson())) {
      throw const FormatException('Sync descriptor does not match catalog');
    }
    final payload = await storage.read(
      expected.payloadPath,
      maxBytes: expected.length,
    );
    if (payload == null) return null;
    // Verify again even when an adapter promises to enforce its read bound.
    expected.verifyPayload(payload);
    return VerifiedSyncPayload._(expected, payload);
  }
}
