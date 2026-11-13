import 'dart:convert';
import 'dart:typed_data';

import '../../../foundation/data_mutation_coordinator.dart';
import '../../cache/misc_data_store.dart';
import 'protocol.dart';

/// Signature and anti-rollback evidence, NOT a collection import/deletion plan.
/// Validate each descriptor/package/schema and explicit withdrawal separately.
final class VerifiedSyncCatalog {
  VerifiedSyncCatalog._({
    required this.publisher,
    required this.fingerprint,
    required this.sequence,
    required this.digest,
    required Map<String, dynamic> content,
  }) : content = _freeze(content) as Map<String, dynamic>;

  final String publisher;
  final String fingerprint;
  final int sequence;
  final String digest;
  final Map<String, dynamic> content;
}

/// Uses the existing app-local store and the SAME mutation coordinator as the
/// importing service. No discovery path creates trust. A checkpoint records the
/// highest verified catalog observed, not the last successfully applied payload.
/// Missing payloads therefore retry the same catalog, never an older catalog.
final class SyncCatalogGate {
  const SyncCatalogGate({required this.store, required this.mutations});
  final MiscDataStore store;
  final DataMutationCoordinator mutations;

  String _key(String publisher) => 'folder_sync.v1.publisher.$publisher';

  _Trust? _read(String publisher) {
    final encoded = store.get(_key(publisher));
    if (encoded == null) return null;
    final value = jsonDecode(encoded);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid local publisher trust');
    }
    return _Trust.fromJson(value, publisher);
  }

  /// Call only after explicit fingerprint approval. Reapproval is idempotent;
  /// neither a key replacement nor a checkpoint reset is implicit approval.
  Future<void> approvePublisher({
    required String publisher,
    required List<int> publicKey,
  }) async {
    final captured = List<int>.unmodifiable(publicKey);
    final id = syncUuid(publisher);
    if (captured.length != 32 ||
        captured.any((byte) => byte < 0 || byte > 255)) {
      throw const FormatException('Invalid publisher key');
    }
    return mutations.runExclusive(() async {
      final prior = _read(id);
      final key = base64Encode(captured);
      if (prior != null) {
        if (prior.publicKey != key) {
          throw const FormatException('Publisher key changed');
        }
        return;
      }
      await store.put(_key(id), jsonEncode(_Trust(
        publisher: id, publicKey: key, sequence: 0, digest: null,
      ).toJson()));
    });
  }

  Future<VerifiedSyncCatalog> verifyAndCheckpoint({
    required String publisher,
    required int expectedSequence,
    required Uint8List bytes,
  }) async {
    final id = syncUuid(publisher);
    syncPositiveInteger(expectedSequence);
    if (bytes.length > folderSyncMaxMetadataBytes) {
      throw const FormatException('Sync metadata exceeds byte limit');
    }
    final captured = Uint8List.fromList(bytes);
    return mutations.runExclusive(() async {
      final trust = _read(id);
      if (trust == null) throw const SyncTrustRequired();
      final key = base64Decode(trust.publicKey);
      final content = await verifySyncDocument(captured, key);
      final sequence = syncPositiveInteger(content['sequence']);
      final collections = content['collections'];
      final name = content['deviceName'];
      if (content['publisher'] != id || sequence != expectedSequence ||
          collections is! List || collections.length > folderSyncMaxEntries ||
          name is! String || name.trim().isEmpty || name.length > 160 ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
        throw const FormatException('Invalid signed sync catalog');
      }
      final digest = syncDigest(syncJsonBytes(content));
      if (sequence < trust.sequence ||
          (sequence == trust.sequence && digest != trust.digest)) {
        throw const SyncReplayRejected();
      }
      final verified = VerifiedSyncCatalog._(
        publisher: id, fingerprint: syncDigest(key), sequence: sequence,
        digest: digest, content: content,
      );
      if (sequence > trust.sequence) {
        // Persist before returning evidence to a consumer that might delete.
        // Storage failure grants no authority; no optimistic in-memory mark.
        await store.put(_key(id), jsonEncode(_Trust(
          publisher: id,
          publicKey: trust.publicKey,
          sequence: sequence,
          digest: digest,
        ).toJson()));
      }
      return verified;
    });
  }

  /// Revalidate after asynchronous payload preparation, under the existing
  /// transaction lock. The callback still owns package/schema checks, mirror
  /// ownership, journal recovery and the last-APPLIED marker. Do not do discovery
  /// or network preparation inside it. All trust changes must use the same lock.
  Future<T> withCurrentCatalog<T>(
    VerifiedSyncCatalog catalog,
    Future<T> Function() commit,
  ) => mutations.runExclusive(() async {
    final trust = _read(catalog.publisher);
    if (trust == null) throw const SyncTrustRequired();
    if (trust.sequence != catalog.sequence || trust.digest != catalog.digest ||
        syncDigest(base64Decode(trust.publicKey)) != catalog.fingerprint) {
      throw const SyncReplayRejected();
    }
    return commit();
  });
}

final class _Trust {
  const _Trust({
    required this.publisher,
    required this.publicKey,
    required this.sequence,
    required this.digest,
  });
  factory _Trust.fromJson(Map<String, dynamic> json, String publisher) {
    if (json['version'] != 1) throw const SyncUpdateRequired();
    final key = syncString(json['publicKey']);
    final sequence = json['sequence'];
    final digest = json['digest'];
    if (json['publisher'] != publisher || base64Decode(key).length != 32 ||
        sequence is! int || sequence < 0 || sequence > folderSyncMaxSequence ||
        (sequence == 0
          ? digest != null
          : digest is! String || !isSyncDigest(digest))) {
      throw const FormatException('Invalid local publisher checkpoint');
    }
    return _Trust(
      publisher: publisher,
      publicKey: key,
      sequence: sequence,
      digest: digest as String?,
    );
  }
  final String publisher;
  final String publicKey;
  final int sequence;
  final String? digest;
  Map<String, Object?> toJson() => {
    'version': 1,
    'publisher': publisher,
    'publicKey': publicKey,
    'sequence': sequence,
    'digest': digest,
  };
}

Object? _freeze(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(
      value.map((key, item) => MapEntry(key, _freeze(item))),
    );
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}
