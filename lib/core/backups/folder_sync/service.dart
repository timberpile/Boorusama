import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../foundation/data_mutation_coordinator.dart';
import '../../../foundation/filesystem.dart';
import '../../bookmarks/src/types/bookmark_group.dart';
import '../../bookmarks/src/types/bookmark_group_repository.dart';
import '../../bookmarks/src/types/bookmark_group_tree.dart';
import '../../bookmarks/src/types/bookmark_mirror_state.dart';
import '../../bookmarks/src/types/unified_bookmark_store.dart';
import '../../cache/misc_data_store.dart';
import '../sources/bookmark_backup_codec.dart';
import '../sources/bookmark_backup_data.dart';
import 'bookmark_mirror_engine.dart';
import 'bookmark_package.dart';
import 'catalog.dart';
import 'catalog_gate.dart';
import 'protocol.dart';
import 'publication.dart';
import 'receive_preparation.dart';
import 'storage.dart';

/// Untrusted discovery never grants approval or applies a package.
final class DiscoveredSyncDevice {
  const DiscoveredSyncDevice(this.id, this.key, this.catalog);
  final String id;
  final List<int> key;
  final SyncCatalog catalog;
  String get fingerprint => syncDigest(key);
}

typedef SyncStorageFactory = Future<FolderSyncStorage> Function(
  String location,
);

/// Coordinates real repositories, immutable packages and the shared journal.
/// Transport relocation changes only the location; identity/trust/counters stay
/// in installation-local storage. No missing advertisement authorizes removal.
final class FolderSyncService extends ChangeNotifier {
  FolderSyncService({
    required this.preferences,
    required this.store,
    required this.groups,
    required this.fs,
    required this.codec,
    required this.storageFor,
    required this.identity,
    required this.mutations,
    this.onApplied,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    if (store is! BookmarkMirrorStore ||
        !identical((store as BookmarkMirrorStore).coordinator, mutations)) {
      throw ArgumentError(
        'Sync requires the real coordinated mirror repository',
      );
    }
    final raw = preferences.get(_settingsKey);
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != 1) {
        throw const FormatException('Unsupported Sync settings');
      }
      location = data['location'] as String?;
      name = syncLabel(data['name']);
      publishedRoots = Set.unmodifiable((data['roots'] as List).map(syncUuid));
    }
  }
  static const _settingsKey = 'folder_sync.v1.settings';
  final MiscDataStore preferences;
  final UnifiedBookmarkStore store;
  final BookmarkGroupRepository groups;
  final AppFileSystem fs;
  final BookmarkBackupCodec codec;
  final SyncStorageFactory storageFor;
  final SyncSigningIdentity identity;
  final DataMutationCoordinator mutations;
  final Future<void> Function()? onApplied;
  final DateTime Function() now;
  final _operations = DataMutationCoordinator();
  final _preparation = DataMutationCoordinator();
  String? location;
  String name = 'Boorusama';
  Set<String> publishedRoots = const {};
  List<DiscoveredSyncDevice> devices = const [];
  Map<String, Object> deviceFailures = const {};
  bool busy = false;
  bool applying = false;
  Object? failure;
  DateTime? lastSync;
  bool _disposed = false;
  bool get configured => location != null;
  SyncCatalogGate get gate =>
      SyncCatalogGate(store: preferences, mutations: mutations);
  BookmarkMirrorStore get mirrors => store as BookmarkMirrorStore;

  Future<void> _save(
    String? nextLocation,
    String nextName,
    Set<String> roots,
  ) => mutations.runExclusive(() {
    _ensureCurrent();
    return preferences.put(
      _settingsKey,
      canonicalSyncJson({
        'version': 1,
        'location': nextLocation,
        'name': nextName,
        'roots': roots.toList()..sort(),
      }),
    );
  });

  void _ensureCurrent() {
    if (_disposed) throw StateError('Sync service disposed');
  }

  Future<FolderSyncStorage> _open(String location) async {
    _ensureCurrent();
    final storage = await storageFor(location);
    _ensureCurrent();
    return _CurrentStorage(storage, _ensureCurrent);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<T> _run<T>(Future<T> Function() action) =>
      _operations.runExclusive(() async {
        if (_disposed) throw StateError('Sync service disposed');
        busy = true;
        failure = null;
        _notify();
        try {
          return await action();
        } catch (error) {
          failure = error;
          rethrow;
        } finally {
          busy = false;
          _notify();
        }
      });

  /// Explicit setup only. Verify the new transport before replacing settings.
  Future<void> configure(String nextLocation, {String? deviceName}) =>
      _run(() async {
        final nextName = syncLabel(deviceName ?? name);
        final storage = await _open(nextLocation);
        await storage.list('');
        await storage.writeImmutable(
          'devices/${identity.id}/identity.json',
          syncJsonBytes(identity.publicJson()),
        );
        await _save(nextLocation, nextName, publishedRoots);
        location = nextLocation;
        name = nextName;
        await _sync(storage);
      });

  Future<void> rename(String nextName) => _run(() async {
    final checked = syncLabel(nextName);
    await _save(location, checked, publishedRoots);
    name = checked;
    if (location != null) await _sync(await _open(location!));
  });

  Future<void> publishRoots(Set<String> roots) => _run(() async {
    final captured = Set<String>.of(roots.map(syncUuid));
    await store.runReadWriteScope(() async {
      final local = {for (final group in await groups.getGroups()) group.id};
      final ownership = await mirrors.readMirrorState();
      if (!local.containsAll(captured) || captured.any(ownership.isReceived)) {
        throw const BookmarkMirrorReadOnly();
      }
      await _save(location, name, captured);
    });
    publishedRoots = Set.unmodifiable(captured);
    if (location != null) await _sync(await _open(location!));
  });

  Future<void> synchronize() => _run(() async {
    if (location == null) return;
    await _sync(await _open(location!));
  });

  SyncBookmarkMirrorEngine _engine(FolderSyncStorage storage) =>
      SyncBookmarkMirrorEngine(
        store: store,
        groups: groups,
        gate: gate,
        preparation: SyncReceivePreparation(
          storage: storage,
          fs: fs,
          codec: codec,
        ),
        now: now,
        ensureCurrent: _ensureCurrent,
      );

  Future<void> _applied(Future<void> Function() operation) async {
    _ensureCurrent();
    applying = true;
    try {
      await operation();
      _ensureCurrent();
      await onApplied?.call();
    } finally {
      applying = false;
    }
  }

  Future<void> approve(DiscoveredSyncDevice device) => _run(() async {
    await gate.approvePublisher(publisher: device.id, publicKey: device.key);
    final storage = await _open(location!);
    await _engine(storage).approvePublisher(device.id);
    await _sync(storage);
  });
  Future<void> subscribe(String publisher, Set<String> roots) => _run(() async {
    final storage = await _open(location!);
    final device = devices.singleWhere((device) => device.id == publisher);
    final ticket = await _ticket(storage, device);
    await _applied(
      () => _engine(
        storage,
      ).receive(ticket: ticket, publisherKey: device.key, directRoots: roots),
    );
  });
  Future<void> unsubscribe(String publisher, String source) => _run(() async {
    // Management requires no working shared directory.
    await _applied(
      () => _engine(_OfflineStorage()).unsubscribe(publisher, source),
    );
  });
  Future<void> forget(String publisher) => _run(() async {
    await _applied(() => _engine(_OfflineStorage()).forgetDevice(publisher));
  });
  Future<BookmarkGroup> localCopy(String groupId) => _run(() async {
    late BookmarkGroup copied;
    await _applied(() async {
      copied = await _engine(_OfflineStorage()).createLocalCopy(groupId);
    });
    return copied;
  });
  Future<void> acknowledge(String groupId, int revision) => _run(
    () => _applied(
      () => _engine(_OfflineStorage()).acknowledgeArrival(groupId, revision),
    ),
  );
  Future<void> markRead(String groupId, Set<String> identities) => _run(
    () => _applied(
      () => _engine(_OfflineStorage()).markRead(groupId, identities),
    ),
  );

  Future<VerifiedSyncCatalog> _ticket(
    FolderSyncStorage storage,
    DiscoveredSyncDevice device,
  ) async {
    final bytes = await storage.read(
      device.catalog.path,
      maxBytes: folderSyncMaxMetadataBytes,
    );
    if (bytes == null) throw const SyncRevisionUnavailable();
    return gate.verifyAndCheckpoint(
      publisher: device.id,
      expectedSequence: device.catalog.sequence,
      bytes: bytes,
    );
  }

  Future<void> _sync(FolderSyncStorage storage) async {
    await _publish(storage);
    final found = <DiscoveredSyncDevice>[];
    final errors = <String, Object>{};
    for (final publisher in await storage.list('devices')) {
      if (publisher == identity.id) continue;
      try {
        syncUuid(publisher);
        final bytes = await storage.read(
          'devices/$publisher/identity.json',
          maxBytes: folderSyncMaxMetadataBytes,
        );
        if (bytes == null) continue;
        final document = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        if (document['id'] != publisher ||
            document['protocol'] != folderSyncProtocol) {
          throw const SyncUpdateRequired();
        }
        final key = base64Decode(syncString(document['publicKey']));
        if (key.length != 32) {
          throw const FormatException('Invalid signing key');
        }
        final approved = gate.approvedKey(publisher);
        if (approved != null && syncDigest(approved) != syncDigest(key)) {
          throw const SyncTrustRequired();
        }
        final numbers = [
          for (final file in await storage.list('devices/$publisher/catalog'))
            if (RegExp(r'^[1-9][0-9]{0,15}\.json$').hasMatch(file))
              int.parse(file.split('.').first),
        ]..sort();
        if (numbers.isEmpty) continue;
        final sequence = numbers.last;
        final catalogBytes = await storage.read(
          'devices/$publisher/catalog/$sequence.json',
          maxBytes: folderSyncMaxMetadataBytes,
        );
        if (catalogBytes == null) continue;
        // An approved publisher advances OBSERVED before compatibility checks.
        final content = approved == null
            ? await verifySyncDocument(catalogBytes, key)
            : (await gate.verifyAndCheckpoint(
                publisher: publisher,
                expectedSequence: sequence,
                bytes: catalogBytes,
              )).content;
        final catalog = SyncCatalog.fromJson(content);
        if (catalog.publisher != publisher || catalog.sequence != sequence) {
          throw const FormatException('Catalog identity mismatch');
        }
        final device = DiscoveredSyncDevice(
          publisher,
          List.unmodifiable(key),
          catalog,
        );
        found.add(device);
        if (approved != null) {
          final ticket = await _ticket(storage, device);
          final subscriptions =
              (await mirrors.readMirrorState()).subscriptions[publisher];
          if (subscriptions?.isNotEmpty ?? false) {
            await _applied(
              () => _engine(storage).receive(ticket: ticket, publisherKey: key),
            );
          }
        }
      } catch (error) {
        errors[publisher] = error;
      }
    }
    devices = List.unmodifiable(found);
    deviceFailures = Map.unmodifiable(errors);
    lastSync = now().toUtc();
    _notify();
  }

  Future<void> _publish(FolderSyncStorage storage) async {
    final snapshot = await store.runReadWriteScope(
      () async => (
        records: await store.readAll(),
        groups: await groups.getGroups(),
        mirrors: await mirrors.readMirrorState(),
      ),
    );
    final local = {
      for (final group in snapshot.groups)
        if (!snapshot.mirrors.isReceived(group.id)) group.id: group,
    };
    final tree = BookmarkGroupTree(local.values);
    final covered = {
      for (final root in publishedRoots)
        if (local.containsKey(root)) ...tree.subtreeIds(root),
    };
    final writer = SyncPublicationWriter(
      storage: storage,
      sequences: SyncPublicationSequences(
        store: preferences,
        mutations: mutations,
        ensureCurrent: _ensureCurrent,
      ),
      identity: identity,
    );
    final publisher = SyncBookmarkPublisher(
      writer: writer,
      builder: SyncBookmarkPackageBuilder(fs: fs, codec: codec),
      workQueue: _preparation,
    );
    final entries = <SyncCatalogEntry>[];
    for (final id in covered) {
      final group = local[id]!;
      final data = BookmarkBackupData.unified(
        records: snapshot.records.where(
          (record) => group.bookmarkIds.contains(record.id),
        ),
        groups: [
          BookmarkGroupBackup(
            id: id,
            name: group.name,
            bookmarkIds: group.bookmarkIds.toList(),
            addedAt: group.addedAt,
          ),
        ],
      );
      final revision = await publisher.publishIfChanged(
        collection: SyncCollectionId(
          publisher: identity.id,
          kind: 'bookmarks',
          source: id,
        ),
        data: data,
        appVersion: 'Boorusama',
        createdAt: now(),
      );
      entries.add(
        SyncCatalogEntry(
          id: revision.collection,
          name: group.name,
          state: SyncPublicationState.active,
          revision: revision,
          parent: group.parentGroupId,
          position: group.position,
        ),
      );
    }
    final intent = preferences.get(
      'folder_sync.v1.outgoing.${identity.id}.catalog_intent',
    );
    SyncCatalog? prior;
    if (intent != null) {
      prior = SyncCatalog.fromJson(
        (jsonDecode(intent) as Map<String, dynamic>)['catalog']
            as Map<String, dynamic>,
      );
    }
    for (final old in prior?.entries ?? <SyncCatalogEntry>[]) {
      if (covered.contains(old.id.source)) continue;
      entries.add(
        SyncCatalogEntry(
          id: old.id,
          name: old.name,
          state: local.containsKey(old.id.source)
              ? SyncPublicationState.withdrawn
              : SyncPublicationState.deleted,
          revision: old.revision,
          parent: old.parent,
          position: old.position,
        ),
      );
    }
    final content = canonicalSyncJson({
      'name': name,
      'entries': entries.map((entry) => entry.toJson()).toList()
        ..sort(
          (a, b) => (a['source']! as String).compareTo(b['source']! as String),
        ),
    });
    final same =
        prior != null &&
        content ==
            canonicalSyncJson({
              'name': prior.name,
              'entries': prior.entries.map((entry) => entry.toJson()).toList()
                ..sort(
                  (a, b) => (a['source']! as String).compareTo(
                    b['source']! as String,
                  ),
                ),
            });
    if (same) {
      try {
        final retained = await storage.read(
          prior.path,
          maxBytes: folderSyncMaxMetadataBytes,
        );
        if (retained != null) {
          final verified = await verifySyncDocument(
            retained,
            identity.publicKey,
          );
          if (canonicalSyncJson(verified) ==
              canonicalSyncJson(prior.toJson())) {
            return;
          }
        }
      } on FormatException {
        // Repair our own incomplete/corrupt publication at a fresh sequence.
        // Existing immutable bytes must never be overwritten.
      }
    }
    if (entries.isEmpty && prior == null) return;
    await writer.publishCatalog(name: name, entries: entries);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final class _OfflineStorage implements FolderSyncStorage {
  Never _offline() =>
      throw StateError('Offline management must not use transport');
  @override
  Future<List<String>> list(String path) async => _offline();
  @override
  Future<Uint8List?> read(
    String path, {
    int maxBytes = folderSyncMaxBytes,
  }) async => _offline();
  @override
  Future<void> writeImmutable(String path, Uint8List bytes) async => _offline();
  @override
  Future<void> deleteOwnedRevision(
    String path, {
    required String owner,
  }) async => _offline();
}

/// Cancellation is checked again after each transport await, before authority
/// can advance or prepared data can reach a replaced repository generation.
final class _CurrentStorage implements FolderSyncStorage {
  _CurrentStorage(this.delegate, this.ensureCurrent);
  final FolderSyncStorage delegate;
  final void Function() ensureCurrent;
  @override
  Future<List<String>> list(String path) async {
    ensureCurrent();
    final result = await delegate.list(path);
    ensureCurrent();
    return result;
  }

  @override
  Future<Uint8List?> read(
    String path, {
    int maxBytes = folderSyncMaxBytes,
  }) async {
    ensureCurrent();
    final result = await delegate.read(path, maxBytes: maxBytes);
    ensureCurrent();
    return result;
  }

  @override
  Future<void> writeImmutable(String path, Uint8List bytes) async {
    ensureCurrent();
    await delegate.writeImmutable(path, bytes);
    ensureCurrent();
  }

  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) async {
    ensureCurrent();
    await delegate.deleteOwnedRevision(path, owner: owner);
    ensureCurrent();
  }
}
