import 'dart:convert';

import '../../../foundation/data_mutation_coordinator.dart';
import '../../cache/misc_data_store.dart';
import 'catalog.dart';
import 'bookmark_package.dart';
import 'protocol.dart';
import 'storage.dart';
import 'revision_transport.dart';
import '../sources/bookmark_backup_data.dart';

/// Durable reservations are consumed before shared writes. Failed/crashed
/// attempts leave gaps, never a reused immutable revision or catalog winner.
final class SyncPublicationSequences {
  const SyncPublicationSequences({
    required this.store,
    required this.mutations,
    this.ensureCurrent,
  });
  final MiscDataStore store;
  final DataMutationCoordinator mutations;
  final void Function()? ensureCurrent;

  Future<int> reserve(String publisher, {SyncCollectionId? collection}) {
    final id = syncUuid(publisher);
    if (collection != null && collection.publisher != id) {
      throw const FormatException('Foreign publication counter');
    }
    final key = 'folder_sync.v1.outgoing.$id.${collection?.key ?? 'catalog'}';
    return mutations.runExclusive(() async {
      ensureCurrent?.call();
      final raw = store.get(key);
      final value = raw == null ? 0 : jsonDecode(raw);
      if (value is! int || value < 0 || value >= folderSyncMaxSequence) {
        throw const FormatException('Invalid publication high-water mark');
      }
      final next = value + 1;
      await store.put(key, jsonEncode(next));
      return next;
    });
  }

  bool isWithdrawnRevision(SyncRevision revision) {
    final encoded = store.get(
      'folder_sync.v1.outgoing.${revision.collection.publisher}.catalog_intent',
    );
    if (encoded == null) return false;
    final raw = jsonDecode(encoded);
    if (raw is! Map<String, dynamic> ||
        raw['version'] != 1 ||
        raw['withdrawals'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid outgoing catalog state');
    }
    final value =
        (raw['withdrawals'] as Map<String, dynamic>)[revision.collection.key];
    if (value == null) return false;
    if (value is! int || value < 0 || value > folderSyncMaxSequence) {
      throw const FormatException('Invalid withdrawal barrier');
    }
    return revision.revision <= value;
  }

  /// Journal the complete outgoing intent before publishing it. Interrupted
  /// catalog writes may leave gaps, but cannot make a stale source authoritative.
  Future<void> stageCatalog(
    SyncCatalog catalog,
  ) => mutations.runExclusive(() async {
    ensureCurrent?.call();
    final key = 'folder_sync.v1.outgoing.${catalog.publisher}.catalog_intent';
    final encoded = store.get(key);
    final barriers = <String, int>{};
    if (encoded != null) {
      final raw = jsonDecode(encoded);
      if (raw is! Map<String, dynamic> ||
          raw['version'] != 1 ||
          raw['catalog'] is! Map<String, dynamic> ||
          raw['withdrawals'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid outgoing catalog state');
      }
      final previous = SyncCatalog.fromJson(
        raw['catalog'] as Map<String, dynamic>,
      );
      for (final entry
          in (raw['withdrawals'] as Map<String, dynamic>).entries) {
        final value = entry.value;
        if (value is! int || value < 0 || value > folderSyncMaxSequence) {
          throw const FormatException('Invalid withdrawal barrier');
        }
        barriers[entry.key] = value;
      }
      if (catalog.sequence <= previous.sequence) {
        throw const SyncReplayRejected();
      }
      final next = {for (final entry in catalog.entries) entry.id: entry};
      for (final prior in previous.entries) {
        final entry = next[prior.id];
        if (entry == null) {
          throw const FormatException('Explicit withdrawal required');
        }
        final before = prior.revision;
        final after = entry.revision;
        if (before != null &&
            (after == null ||
                after.revision < before.revision ||
                (after.revision == before.revision &&
                    canonicalSyncJson(after.toJson()) !=
                        canonicalSyncJson(before.toJson())))) {
          throw const SyncReplayRejected();
        }
      }
    }
    for (final entry in catalog.entries) {
      final barrier = barriers[entry.id.key];
      if (entry.state == SyncPublicationState.active) {
        if (barrier != null && entry.revision!.revision <= barrier) {
          throw const SyncReplayRejected();
        }
      } else {
        // Include revisions reserved before a tombstone, even when their
        // descriptor/catalog was never written. A delayed old writer cannot
        // resurrect that source through a null-revision withdrawal.
        final counterKey =
            'folder_sync.v1.outgoing.${catalog.publisher}.${entry.id.key}';
        final rawCounter = store.get(counterKey);
        final counter = rawCounter == null ? 0 : jsonDecode(rawCounter);
        if (counter is! int || counter < 0 || counter > folderSyncMaxSequence) {
          throw const FormatException('Invalid publication high-water mark');
        }
        final candidates = [
          barrier ?? 0,
          counter,
          entry.revision?.revision ?? 0,
        ]..sort();
        barriers[entry.id.key] = candidates.last;
      }
    }
    await store.put(
      key,
      canonicalSyncJson({
        'version': 1,
        'catalog': catalog.toJson(),
        'withdrawals': barriers,
      }),
    );
  });
}

/// Own-namespace writer. Receivers accept only catalog-advertised, signed,
/// complete packages; this writer never lists, overwrites or deletes files.
final class SyncPublicationWriter {
  const SyncPublicationWriter({
    required this.storage,
    required this.sequences,
    required this.identity,
  });
  final FolderSyncStorage storage;
  final SyncPublicationSequences sequences;
  final SyncSigningIdentity identity;

  Future<SyncRevision> publishRevision(
    ValidatedSyncBookmarkPackage package,
  ) async {
    if (!package.forPublication) {
      throw const FormatException('Incoming payload cannot be republished');
    }
    final collection = package.collection;
    if (collection.publisher != identity.id) {
      throw const FormatException('Foreign publisher');
    }
    final bytes = package.bytes;
    final semanticHash = package.semanticHash;
    const schema = ValidatedSyncBookmarkPackage.schema;
    final number = await sequences.reserve(identity.id, collection: collection);
    final revision = SyncRevision(
      collection: collection,
      revision: number,
      length: bytes.length,
      sha256: syncDigest(bytes),
      semanticHash: semanticHash,
      schema: schema,
    );
    final descriptor = await identity.sign(revision.toJson());
    await storage.writeImmutable(
      'devices/${identity.id}/identity.json',
      syncJsonBytes(identity.publicJson()),
    );
    await storage.writeImmutable(revision.payloadPath, bytes);
    await storage.writeImmutable(revision.descriptorPath, descriptor);
    return revision;
  }

  /// Call with the complete locally persisted advertisement set only after all
  /// referenced revision writes succeed. Omitted sources never mean withdrawal.
  Future<SyncCatalog> publishCatalog({
    required String name,
    required Iterable<SyncCatalogEntry> entries,
  }) async {
    final captured = List<SyncCatalogEntry>.of(entries);
    // Validate before consuming a reservation; no shared writes for bad input.
    SyncCatalog(
      publisher: identity.id,
      sequence: 1,
      name: name,
      entries: captured,
    );
    final sequence = await sequences.reserve(identity.id);
    final catalog = SyncCatalog(
      publisher: identity.id,
      sequence: sequence,
      name: name,
      entries: captured,
    );
    // A local advertisement is not proof that its payload survived a partial
    // write. Authenticate exactly the bytes before exposing a commit catalog.
    for (final entry in captured) {
      if (entry.state != SyncPublicationState.active) continue;
      final expected = entry.revision!;
      final descriptorBytes = await storage.read(
        expected.descriptorPath,
        maxBytes: folderSyncMaxMetadataBytes,
      );
      final bytes = await storage.read(
        expected.payloadPath,
        maxBytes: expected.length,
      );
      if (descriptorBytes == null ||
          bytes == null ||
          canonicalSyncJson(
                await verifySyncDocument(descriptorBytes, identity.publicKey),
              ) !=
              canonicalSyncJson(expected.toJson())) {
        throw const FormatException('Outgoing revision is incomplete');
      }
      expected.verifyPayload(bytes);
    }
    final signed = await identity.sign(catalog.toJson());
    await sequences.stageCatalog(catalog);
    await storage.writeImmutable(
      'devices/${identity.id}/identity.json',
      syncJsonBytes(identity.publicJson()),
    );
    await storage.writeImmutable(catalog.path, signed);
    return catalog;
  }
}

/// One shared publisher work queue serializes expensive preparation outside the
/// application's domain mutation coordinator. Callers must supply only local,
/// consistent snapshots and enforce ownership before invoking this service.
/// Lifecycle/dirty signals and complete catalog assembly are separate wiring.
final class SyncBookmarkPublisher {
  SyncBookmarkPublisher({
    required this.writer,
    required this.builder,
    required this.workQueue,
  }) {
    if (identical(workQueue, writer.sequences.mutations)) {
      throw ArgumentError(
        'Publication preparation requires a separate work queue',
      );
    }
  }
  final SyncPublicationWriter writer;
  final SyncBookmarkPackageBuilder builder;
  final DataMutationCoordinator workQueue;

  Future<SyncRevision> publishIfChanged({
    required SyncCollectionId collection,
    required BookmarkBackupData data,
    required String appVersion,
    required DateTime createdAt,
  }) => workQueue.runExclusive(() async {
    if (collection.publisher != writer.identity.id) {
      throw const FormatException('Foreign publisher');
    }
    requireSyncBookmarkScope(data, collection);
    final semantic = syncBookmarkSemanticHash(data, builder.codec);
    final key = 'folder_sync.v1.outgoing.${collection.key}.published';
    final encoded = writer.sequences.store.get(key);
    if (encoded != null) {
      final raw = jsonDecode(encoded);
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid local publication');
      }
      final prior = SyncRevision.fromJson(raw);
      if (prior.collection != collection) {
        throw const FormatException('Foreign local publication');
      }
      if (prior.schema == ValidatedSyncBookmarkPackage.schema &&
          prior.semanticHash == semantic &&
          !writer.sequences.isWithdrawnRevision(prior)) {
        // Incomplete/offline data never becomes an empty revision or withdrawal.
        // A missing immutable file may be republished at a fresh reserved number.
        final retained = await SyncRevisionTransport(writer.storage)
            .read(expected: prior, publisherKey: writer.identity.publicKey);
        if (retained != null) return prior;
      }
    }
    final package = await builder.build(
      collection: collection,
      data: data,
      appVersion: appVersion,
      createdAt: createdAt,
    );
    if (package.semanticHash != semantic) {
      throw StateError('Source snapshot changed during preparation');
    }
    final revision = await writer.publishRevision(package);
    await writer.sequences.mutations.runExclusive(() async {
      writer.sequences.ensureCurrent?.call();
      await writer.sequences.store.put(
        key,
        canonicalSyncJson(revision.toJson()),
      );
    });
    return revision;
  });
}
