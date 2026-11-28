import 'dart:typed_data';

import 'bookmark_buckets.dart';
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

  final MiteMiteStorage storage;

  Future<bool> _descriptorAvailable(
    SyncRevision expected,
    List<int> publisherKey,
  ) async {
    final key = List<int>.unmodifiable(publisherKey);
    final descriptorBytes = await storage.read(
      expected.descriptorPath,
      maxBytes: miteMiteMaxMetadataBytes,
    );
    if (descriptorBytes == null) return false;
    final descriptor = SyncRevision.fromJson(
      await verifySyncDocument(descriptorBytes, key),
    );
    // Bind every field, not just the revision number. Paths are derived from
    // the expected identity; never follow a path supplied by shared metadata.
    if (canonicalSyncJson(descriptor.toJson()) !=
        canonicalSyncJson(expected.toJson())) {
      throw const FormatException('Sync descriptor does not match catalog');
    }
    return true;
  }

  Future<VerifiedSyncPayload?> read({
    required SyncRevision expected,
    required List<int> publisherKey,
  }) async {
    if (expected.bookmarkTables || expected.bookmarkManifest) {
      throw const SyncUpdateRequired();
    }
    if (!await _descriptorAvailable(expected, publisherKey)) return null;
    final payload = await storage.read(
      expected.payloadPath,
      maxBytes: expected.length,
    );
    if (payload == null) return null;
    // Verify again even when an adapter promises to enforce its read bound.
    await verifySyncPayloadAsync(expected, payload);
    return VerifiedSyncPayload._(expected, payload);
  }

  /// A verified private, newly created file owned by the caller's staging scope.
  Future<bool> readToFile({
    required SyncRevision expected,
    required List<int> publisherKey,
    required String destination,
  }) async {
    if (!await _descriptorAvailable(expected, publisherKey)) return false;
    return copyMiteMitePayloadFromStorage(
      storage,
      expected.payloadPath,
      destination: destination,
      length: expected.length,
      sha256: expected.sha256,
    );
  }

  Future<bool> verify({
    required SyncRevision expected,
    required List<int> publisherKey,
  }) async {
    if (expected.bookmarkManifest) {
      final manifest = await SyncBookmarkManifest.read(storage, expected);
      if (manifest == null) return false;
      for (final chunk in manifest.chunks) {
        if (await readSyncBookmarkChunk(storage, expected.collection, chunk) ==
            null) {
          return false;
        }
      }
      return true;
    }
    if (expected.collection.kind != 'bookmarks') {
      return await read(expected: expected, publisherKey: publisherKey) != null;
    }
    if (!await _descriptorAvailable(expected, publisherKey)) return false;
    return copyMiteMitePayloadFromStorage(
      storage,
      expected.payloadPath,
      length: expected.length,
      sha256: expected.sha256,
    );
  }

  /// Writes the authenticated payload before the publisher exposes its signed
  /// descriptor. The source is a private staged file, never a remote pathname.
  Future<void> writeFile({
    required SyncRevision revision,
    required String sourcePath,
  }) {
    if (!revision.bookmarkTables) {
      throw ArgumentError.value(revision.schema, 'revision.schema');
    }
    return writeMiteMitePayloadToStorage(
      storage,
      revision.payloadPath,
      sourcePath: sourcePath,
      length: revision.length,
      sha256: revision.sha256,
    );
  }
}
