import 'dart:convert';

import '../../cache/misc_data_store.dart';
import 'bookmark_mirror_engine.dart' show SyncRevisionUnavailable;
import 'catalog.dart';
import 'protocol.dart';
import 'revision_transport.dart';
import 'storage.dart';

final class SyncRetentionResult {
  const SyncRetentionResult(this.deletedFiles, {required this.hasMore});
  final int deletedFiles;
  final bool hasMore;
}

/// Run only after the serialized publisher finishes. No foreign namespace,
/// identity, directory or unrecognized name is ever removed. Preserve two
/// authenticated complete catalogs, all their references, cached complete
/// revisions and the two newest local reservations (including partial tails).
final class SyncOwnedRetention {
  const SyncOwnedRetention({
    required this.storage,
    required this.identity,
    required this.preferences,
    this.maxDeletes = 128,
    this.maxCatalogChecks = 32,
    this.ensureCurrent,
    this.withDeletion,
  });
  final MiteMiteStorage storage;
  final SyncSigningIdentity identity;
  final MiscDataStore preferences;
  final int maxDeletes;
  final int maxCatalogChecks;
  final void Function()? ensureCurrent;
  final Future<void> Function(Future<void> Function())? withDeletion;

  Future<SyncRetentionResult> prune(SyncCatalog current) async {
    if (maxDeletes < 1 || maxCatalogChecks < 1) {
      throw ArgumentError('Positive retention budgets required');
    }
    ensureCurrent?.call();
    if (current.publisher != identity.id) throw const SyncConflict();
    final intentKey = 'mitemite.v1.outgoing.${identity.id}.catalog_intent';
    final intent = preferences.get(intentKey);
    if (intent == null ||
        canonicalSyncJson(
              (jsonDecode(intent) as Map<String, dynamic>)['catalog'],
            ) !=
            canonicalSyncJson(current.toJson())) {
      throw const SyncConflict();
    }
    final catalogCounterKey = 'mitemite.v1.outgoing.${identity.id}.catalog';
    final catalogCounter = preferences.get(catalogCounterKey);
    final catalogHighWater = catalogCounter == null
        ? null
        : jsonDecode(catalogCounter);
    if (catalogHighWater is! int ||
        catalogHighWater < current.sequence ||
        catalogHighWater > miteMiteMaxSequence) {
      throw const SyncConflict();
    }
    final captured = <String, String?>{
      intentKey: intent,
      catalogCounterKey: catalogCounter,
    };
    void checkCurrent() {
      ensureCurrent?.call();
      if (captured.entries.any(
        (entry) => preferences.get(entry.key) != entry.value,
      )) {
        throw const SyncConflict();
      }
    }

    final prefix = 'devices/${identity.id}';
    final numbers = [
      for (final name in await storage.list('$prefix/catalog'))
        if (RegExp(r'^[1-9][0-9]{0,15}\.json$').hasMatch(name))
          int.parse(name.split('.').first),
    ]..sort((a, b) => b.compareTo(a));
    if (numbers.isEmpty || numbers.first != current.sequence) {
      throw const SyncConflict();
    }
    final kept = <int, SyncCatalog>{};
    final invalid = <int>[];
    final verified = <String>{};
    var checked = 0;
    for (final number in numbers) {
      if (kept.length == 2 || checked == maxCatalogChecks) break;
      checked++;
      try {
        final bytes = await storage.read(
          '$prefix/catalog/$number.json',
          maxBytes: miteMiteMaxMetadataBytes,
        );
        if (bytes == null) throw const SyncRevisionUnavailable();
        final catalog = SyncCatalog.fromJson(
          await verifySyncDocument(bytes, identity.publicKey),
        );
        if (catalog.publisher != identity.id ||
            catalog.sequence != number ||
            (number == current.sequence &&
                canonicalSyncJson(catalog.toJson()) !=
                    canonicalSyncJson(current.toJson()))) {
          throw const SyncConflict();
        }
        for (final entry in catalog.entries) {
          if (entry.state != SyncPublicationState.active) continue;
          final revision = entry.revision!;
          final key = canonicalSyncJson(revision.toJson());
          if (verified.contains(key)) continue;
          if (await SyncRevisionTransport(storage)
                  .read(expected: revision, publisherKey: identity.publicKey) ==
              null) {
            throw const SyncRevisionUnavailable();
          }
          verified.add(key);
        }
        kept[number] = catalog;
      } on FormatException {
        if (number == current.sequence) rethrow;
        invalid.add(number);
      } on SyncRevisionUnavailable {
        if (number == current.sequence) rethrow;
        invalid.add(number);
      }
    }
    final incompleteScan = kept.length < 2 && checked < numbers.length;
    final obsolete = incompleteScan
        ? invalid
        : numbers.where((number) => !kept.containsKey(number)).toList();
    var deleted = 0;
    Future<void> delete(String path) async {
      checkCurrent();
      if (!isOwnedSyncRevisionPath(path, identity.id)) {
        throw const SyncConflict();
      }
      await storage.deleteOwnedRevision(path, owner: identity.id);
      deleted++;
    }

    Future<void> remove(String path) =>
        withDeletion == null ? delete(path) : withDeletion!(() => delete(path));

    for (final number in obsolete.take(maxDeletes)) {
      await remove('$prefix/catalog/$number.json');
    }
    if (incompleteScan || obsolete.length > deleted || deleted == maxDeletes) {
      return SyncRetentionResult(deleted, hasMore: true);
    }

    final protected = <String>{
      for (final catalog in kept.values)
        for (final entry in catalog.entries)
          if (entry.revision case final revision?) ...[
            revision.payloadPath,
            revision.descriptorPath,
          ],
    };
    final candidates = <String>[];
    final remaining = maxDeletes - deleted;
    for (final kind in const ['bookmarks', 'following_topics']) {
      if (candidates.length > remaining) break;
      for (final source in await storage.list('$prefix/collections/$kind')) {
        if (candidates.length > remaining) break;
        try {
          syncUuid(source);
        } on FormatException {
          continue;
        }
        final collection = SyncCollectionId(
          publisher: identity.id,
          kind: kind,
          source: source,
        );
        final counterKey =
            'mitemite.v1.outgoing.${identity.id}.${collection.key}';
        final counter = preferences.get(counterKey);
        if (counter == null) {
          continue; // Never infer local ownership from files alone.
        }
        captured[counterKey] = counter;
        final highWater = jsonDecode(counter);
        if (highWater is! int ||
            highWater < 1 ||
            highWater > miteMiteMaxSequence) {
          throw const FormatException('Invalid retention reservation');
        }
        final cacheKey = 'mitemite.v1.outgoing.${collection.key}.published';
        final cache = preferences.get(cacheKey);
        captured[cacheKey] = cache;
        if (cache != null) {
          final revision = SyncRevision.fromJson(
            jsonDecode(cache) as Map<String, dynamic>,
          );
          if (revision.collection != collection ||
              revision.revision > highWater) {
            throw const SyncConflict();
          }
          protected.addAll([revision.payloadPath, revision.descriptorPath]);
        }
        final path = '$prefix/collections/$kind/$source';
        final files =
            (await storage.list(path))
                .where(
                  (file) =>
                      RegExp(r'^[1-9][0-9]{0,15}\.(json|bsexport)$')
                          .hasMatch(file),
                )
                .toList()
              ..sort((a, b) {
                final number = int.parse(a.split('.').first)
                    .compareTo(int.parse(b.split('.').first));
                return number != 0
                    ? number
                    : (a.endsWith('.json') ? 0 : 1).compareTo(
                        b.endsWith('.json') ? 0 : 1,
                      );
              });
        for (final file in files) {
          if (int.parse(file.split('.').first) >= highWater - 1 ||
              protected.contains('$path/$file')) {
            continue;
          }
          candidates.add('$path/$file');
          if (candidates.length > remaining) break;
        }
      }
    }
    for (final path in candidates.take(remaining)) {
      await remove(path);
    }
    return SyncRetentionResult(deleted, hasMore: candidates.length > remaining);
  }
}
