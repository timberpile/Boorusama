import 'identity_file.dart';

import 'dart:convert';
import 'dart:typed_data';

import '../../../foundation/data_mutation_coordinator.dart';
import '../../cache/misc_data_store.dart';
import 'catalog.dart';
import 'bookmark_package.dart';
import '../sources/bookmark_backup_schema.dart';
import 'following_package.dart';
import '../sources/following_topic_backup_data.dart';
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
    final key = 'mitemite.v1.outgoing.$id.${collection?.key ?? 'catalog'}';
    return mutations.runExclusive(() async {
      ensureCurrent?.call();
      final raw = store.get(key);
      final value = raw == null ? 0 : jsonDecode(raw);
      if (value is! int || value < 0 || value >= miteMiteMaxSequence) {
        throw const FormatException('Invalid publication high-water mark');
      }
      final next = value + 1;
      await store.put(key, jsonEncode(next));
      return next;
    });
  }

  bool isWithdrawnRevision(SyncRevision revision) {
    final encoded = store.get(
      'mitemite.v1.outgoing.${revision.collection.publisher}.catalog_intent',
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
    if (value is! int || value < 0 || value > miteMiteMaxSequence) {
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
    final key = 'mitemite.v1.outgoing.${catalog.publisher}.catalog_intent';
    final encoded = store.get(key);
    final barriers = <String, int>{};
    void retire(SyncCatalogEntry entry) {
      // Include versions reserved before removal, even if their files never
      // reached the catalog.
      final counterKey =
          'mitemite.v1.outgoing.${catalog.publisher}.${entry.id.key}';
      final raw = store.get(counterKey);
      final counter = raw == null ? 0 : jsonDecode(raw);
      if (counter is! int || counter < 0 || counter > miteMiteMaxSequence) {
        throw const FormatException('Invalid publication high-water mark');
      }
      barriers[entry.id.key] = [
        barriers[entry.id.key] ?? 0,
        counter,
        entry.revision?.revision ?? 0,
      ].reduce((left, right) => left > right ? left : right);
    }

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
        if (value is! int || value < 0 || value > miteMiteMaxSequence) {
          throw const FormatException('Invalid withdrawal barrier');
        }
        barriers[entry.key] = value;
      }
      if (catalog.sequence <= previous.sequence ||
          (previous.completeSnapshot && !catalog.completeSnapshot)) {
        throw const SyncReplayRejected();
      }
      final next = {for (final entry in catalog.entries) entry.id: entry};
      for (final prior in previous.entries) {
        final entry = next[prior.id];
        if (entry == null) {
          if (!catalog.completeSnapshot) {
            throw const FormatException('Explicit withdrawal required');
          }
          retire(prior);
          continue;
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
        retire(entry);
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
  final MiteMiteStorage storage;
  final SyncPublicationSequences sequences;
  final SyncSigningIdentity identity;

  Future<SyncRevision> publishRevision(
    ValidatedSyncBookmarkPackage package,
  ) => Future.sync(() {
    if (!package.forPublication) {
      throw const FormatException('Incoming payload cannot be republished');
    }
    return _writeRevision(
      collection: package.collection,
      bytes: package.bytes,
      semanticHash: package.semanticHash,
      schema: package.schemaVersion,
    );
  });

  Future<SyncRevision> publishFollowingRevision(
    ValidatedSyncFollowingPackage package,
  ) => Future.sync(() {
    if (!package.forPublication) {
      throw const FormatException('Incoming payload cannot be republished');
    }
    return _writeRevision(
      collection: package.collection,
      bytes: package.bytes,
      semanticHash: package.semanticHash,
      schema: ValidatedSyncFollowingPackage.schema,
    );
  });

  Future<SyncRevision> _writeRevision({
    required SyncCollectionId collection,
    required Uint8List bytes,
    required String semanticHash,
    required int schema,
  }) async {
    if (collection.publisher != identity.id) {
      throw const FormatException('Foreign publisher');
    }
    final number = await sequences.reserve(identity.id, collection: collection);
    final revision = SyncRevision(
      collection: collection,
      revision: number,
      length: bytes.length,
      sha256: await syncPayloadDigestAsync(bytes),
      semanticHash: semanticHash,
      schema: schema,
    );
    final descriptor = await identity.sign(revision.toJson());
    await writeOwnSyncIdentity(storage, identity);
    await storage.writeImmutable(revision.payloadPath, bytes);
    await storage.writeImmutable(revision.descriptorPath, descriptor);
    return revision;
  }

  /// Call with the complete locally persisted advertisement set only after all
  /// referenced revision writes succeed.
  Future<SyncCatalog> publishCatalog({
    required String name,
    required Iterable<SyncCatalogEntry> entries,
    Set<SyncCollectionId>? publicationRoots,
    bool completeSnapshot = false,
  }) async {
    final captured = List<SyncCatalogEntry>.of(entries);
    final roots = publicationRoots == null
        ? null
        : Set<SyncCollectionId>.of(publicationRoots);
    // Validate before consuming a reservation; no shared writes for bad input.
    SyncCatalog(
      publisher: identity.id,
      sequence: 1,
      name: name,
      entries: captured,
      publicationRoots: roots,
      completeSnapshot: completeSnapshot,
    );
    final sequence = await sequences.reserve(identity.id);
    final catalog = SyncCatalog(
      publisher: identity.id,
      sequence: sequence,
      name: name,
      entries: captured,
      publicationRoots: roots,
      completeSnapshot: completeSnapshot,
    );
    // A local advertisement is not proof that its payload survived a partial
    // write. Authenticate exactly the bytes before exposing a commit catalog.
    for (final entry in captured) {
      if (entry.state != SyncPublicationState.active) continue;
      final expected = entry.revision!;
      final descriptorBytes = await storage.read(
        expected.descriptorPath,
        maxBytes: miteMiteMaxMetadataBytes,
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
      await verifySyncPayloadAsync(expected, bytes);
    }
    final signed = await identity.sign(catalog.toJson());
    await sequences.stageCatalog(catalog);
    await writeOwnSyncIdentity(storage, identity);
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
    bool verifyExisting = true,
    Future<void> Function()? validateSnapshot,
  }) => workQueue.runExclusive(() async {
    if (collection.publisher != writer.identity.id) {
      throw const FormatException('Foreign publisher');
    }
    requireSyncBookmarkScope(data, collection);
    final semantic = await builder.semanticHash(data);
    await validateSnapshot?.call();
    final key = 'mitemite.v1.outgoing.${collection.key}.published';
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
      if (prior.schema == bookmarkTransferVersion(data.records) &&
          prior.semanticHash == semantic &&
          !writer.sequences.isWithdrawnRevision(prior)) {
        // Incomplete/offline data never becomes an empty revision or withdrawal.
        // A missing immutable file may be republished at a fresh reserved number.
        if (!verifyExisting) return prior;
        VerifiedSyncPayload? retained;
        try {
          retained = await SyncRevisionTransport(writer.storage)
              .read(expected: prior, publisherKey: writer.identity.publicKey);
        } on FormatException {
          // Repair only this installation's immutable publication at a fresh number.
        }
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
    await validateSnapshot?.call();
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

final class SyncFollowingPublisher {
  SyncFollowingPublisher({
    required this.writer,
    required this.builder,
    required this.workQueue,
  }) {
    if (identical(workQueue, writer.sequences.mutations)) {
      throw ArgumentError(
        'Following preparation requires a separate work queue',
      );
    }
  }
  final SyncPublicationWriter writer;
  final SyncFollowingPackageBuilder builder;
  final DataMutationCoordinator workQueue;

  Future<SyncRevision> publishIfChanged({
    required SyncCollectionId collection,
    required FollowingTopicBackupData data,
    required String appVersion,
    required DateTime createdAt,
    bool verifyExisting = true,
    Future<void> Function()? validateSnapshot,
  }) => workQueue.runExclusive(() async {
    if (collection.publisher != writer.identity.id) {
      throw const FormatException('Foreign publisher');
    }
    requireSyncFollowingScope(data, collection);
    final semantic = await builder.semanticHash(data);
    await validateSnapshot?.call();
    final key = 'mitemite.v1.outgoing.${collection.key}.published';
    final encoded = writer.sequences.store.get(key);
    if (encoded != null) {
      final prior = SyncRevision.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      if (prior.collection != collection) {
        throw const FormatException('Foreign local publication');
      }
      if (prior.schema == ValidatedSyncFollowingPackage.schema &&
          prior.semanticHash == semantic &&
          !writer.sequences.isWithdrawnRevision(prior)) {
        if (!verifyExisting) return prior;
        VerifiedSyncPayload? retained;
        try {
          retained = await SyncRevisionTransport(writer.storage).read(
            expected: prior,
            publisherKey: writer.identity.publicKey,
          );
        } on FormatException {
          // Repair only this installation's immutable publication at a fresh number.
        }
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
      throw StateError('Following source changed during preparation');
    }
    await validateSnapshot?.call();
    final revision = await writer.publishFollowingRevision(package);
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
