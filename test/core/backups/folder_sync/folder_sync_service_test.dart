import 'dart:convert';
import 'dart:typed_data';

import 'package:boorusama/core/backups/folder_sync/protocol.dart';
import 'package:boorusama/core/backups/folder_sync/service.dart';
import 'package:boorusama/core/backups/folder_sync/storage.dart';
import 'package:flutter_test/flutter_test.dart';

const rootId = '10000000-0000-4000-8000-000000000001';
const childId = '10000000-0000-4000-8000-000000000002';
const futureId = '10000000-0000-4000-8000-000000000003';

void main() {
  test('signed documents verify their complete canonical content', () async {
    final identity = await SyncSigningIdentity.create();
    final document = await identity.sign({
      'protocol': 1,
      'publisher': identity.id,
      'revision': 1,
    });
    expect(
      (await verifySyncDocument(document, identity.publicKey))['revision'],
      1,
    );
    final envelope = decodeSyncObject(document);
    (envelope['content'] as Map)['revision'] = 2;
    await expectLater(
      verifySyncDocument(syncJsonBytes(envelope), identity.publicKey),
      throwsFormatException,
    );
    final other = await SyncSigningIdentity.create();
    await expectLater(
      verifySyncDocument(document, other.publicKey),
      throwsFormatException,
    );
  });

  test('sync paths reject traversal, URI and absolute paths', () {
    for (final path in [
      '../x',
      '/root',
      'a//b',
      'a/./b',
      'content://tree/x',
      r'a\b',
      '%2e%2e/x',
    ]) {
      expect(isSafeSyncPath(path), isFalse, reason: path);
    }
    expect(
      isSafeSyncPath(
        'devices/$rootId/collections/bookmarks/$childId/1.bsexport',
      ),
      isTrue,
    );
  });

  late _Storage storage;
  late _Metadata aMetadata;
  late _Metadata bMetadata;
  late _Port aPort;
  late _Port bPort;
  late FolderSyncService a;
  late FolderSyncService b;
  setUp(() async {
    storage = _Storage();
    aMetadata = _Metadata();
    bMetadata = _Metadata();
    aPort = _Port()..put(rootId, 'Source name', {'post:1'});
    bPort = _Port();
    a = FolderSyncService(
      metadata: aMetadata,
      port: aPort,
      storageFor: (_) => storage,
    );
    b = FolderSyncService(
      metadata: bMetadata,
      port: bPort,
      storageFor: (_) => storage,
    );
    await a.initialize();
    await b.initialize();
    await a.chooseFolder('shared');
    await b.chooseFolder('shared');
  });
  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  Future<Map<String, dynamic>> offer({String source = rootId}) async {
    final publisher = (await b.discover()).singleWhere(
      (p) => (p['collections'] as List).isNotEmpty,
    );
    await b.approvePublisher(
      publisher['publisher'] as String,
      publisher['publicKey'] as String,
    );
    return {
      'publisher': publisher['publisher'],
      'offer': (publisher['collections'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((p) => p['source'] == source),
    };
  }

  Future<String> subscribeRoot() async {
    await a.setPublication((await aPort.sources()).first, enabled: true);
    await a.synchronize();
    final found = await offer();
    await b.subscribe(
      offer: found['offer'] as Map<String, dynamic>,
      publisher: found['publisher'] as String,
      name: 'My local name',
    );
    await b.synchronize();
    return ((b.snapshot['subscriptions'] as Map).values.single
            as Map)['localId']
        as String;
  }

  test(
    'payload completes before signed descriptor and discovery catalog',
    () async {
      await a.setPublication((await aPort.sources()).first, enabled: true);
      await a.synchronize();
      final payload = storage.writes.indexWhere((p) => p.endsWith('.bsexport'));
      final descriptor = storage.writes.indexWhere(
        (p) => p.contains('/collections/') && p.endsWith('.json'),
      );
      final catalog = storage.writes.indexWhere((p) => p.contains('/catalog/'));
      expect(payload, greaterThanOrEqualTo(0));
      expect(descriptor, greaterThan(payload));
      expect(catalog, greaterThan(descriptor));
    },
  );

  test('explicit trust and subscription precede import', () async {
    await a.setPublication((await aPort.sources()).first, enabled: true);
    await a.synchronize();
    final publisher = (await b.discover()).single;
    expect(publisher['trusted'], false);
    await b.synchronize();
    expect(bPort.items, isEmpty);
    await expectLater(
      b.subscribe(
        offer:
            (publisher['collections'] as List).single as Map<String, dynamic>,
        publisher: publisher['publisher'] as String,
        name: 'Local',
      ),
      throwsStateError,
    );
  });

  test(
    'mirrors revision membership, retains local name and placement, no echo',
    () async {
      final localId = await subscribeRoot();
      expect(bPort.items[localId]!.members, {'post:1'});
      bPort.items[localId]!.name = 'Receiver rename';
      bPort.items[localId]!.parent = childId;
      aPort.items[rootId]!.name = 'Publisher rename';
      aPort.items[rootId]!.members = {'post:2'};
      await a.synchronize();
      await b.synchronize();
      expect(bPort.items[localId]!.members, {'post:2'});
      expect(bPort.items[localId]!.name, 'Receiver rename');
      expect(bPort.items[localId]!.parent, childId);
      expect((b.snapshot['publications'] as Map), isEmpty);
      await expectLater(
        b.setPublication((await bPort.sources()).single, enabled: true),
        throwsStateError,
      );
    },
  );

  test(
    'unchanged semantic content and label-only edit do not rewrite payload',
    () async {
      await subscribeRoot();
      final before = storage.files.keys
          .where((p) => p.endsWith('.bsexport'))
          .toSet();
      aPort.items[rootId]!.name = 'Renamed';
      await a.synchronize();
      expect(
        storage.files.keys.where((p) => p.endsWith('.bsexport')).toSet(),
        before,
      );
      await b.synchronize();
      expect(bPort.applies, 1);
    },
  );

  test(
    'unseen additions accumulate, removals subtract and seen is group-specific',
    () async {
      final localId = await subscribeRoot();
      Map subscription() =>
          (b.snapshot['subscriptions'] as Map).values.single as Map;
      expect(subscription()['unseen'], ['post:1']);
      aPort.items[rootId]!.members = {'post:1', 'post:2'};
      await a.synchronize();
      await b.synchronize();
      expect((subscription()['unseen'] as List).toSet(), {'post:1', 'post:2'});
      aPort.items[rootId]!.members = {'post:2'};
      await a.synchronize();
      await b.synchronize();
      expect(subscription()['unseen'], ['post:2']);
      await b.markSeen('bookmarks', localId);
      expect(subscription()['unseen'], isEmpty);
      expect(subscription()['changed'], false);
    },
  );

  test(
    'restart and replay do not duplicate imports or local identities',
    () async {
      final localId = await subscribeRoot();
      await b.dispose();
      b = FolderSyncService(
        metadata: bMetadata,
        port: bPort,
        storageFor: (_) => storage,
      );
      await b.initialize();
      await b.synchronize();
      expect(bPort.items.keys, [localId]);
      expect(bPort.applies, 1);
    },
  );

  test(
    'corrupt payload retains last committed receiver content and marker',
    () async {
      final localId = await subscribeRoot();
      aPort.items[rootId]!.members = {'post:2'};
      await a.synchronize();
      final newest = storage.files.keys
          .where((p) => p.endsWith('/2.bsexport'))
          .single;
      storage.files[newest] = Uint8List.fromList([0, 1, 2]);
      await b.synchronize();
      expect(bPort.items[localId]!.members, {'post:1'});
      final subscription =
          (b.snapshot['subscriptions'] as Map).values.single as Map;
      expect(subscription['applied'], 1);
      expect(subscription['state'], 'failed');
    },
  );

  test('missing descriptor never imports a half-written revision', () async {
    final localId = await subscribeRoot();
    aPort.items[rootId]!.members = {'post:2'};
    await a.synchronize();
    storage.files.removeWhere(
      (path, _) => path.contains('/collections/') && path.endsWith('/2.json'),
    );
    await b.synchronize();
    expect(bPort.items[localId]!.members, {'post:1'});
    expect(
      ((b.snapshot['subscriptions'] as Map).values.single as Map)['state'],
      'incomplete',
    );
  });

  test('local unexpected membership edit pauses in conflict', () async {
    final localId = await subscribeRoot();
    bPort.items[localId]!.members.add('local:unapproved');
    aPort.items[rootId]!.members = {'post:2'};
    await a.synchronize();
    await b.synchronize();
    expect(bPort.items[localId]!.members, contains('local:unapproved'));
    expect(
      ((b.snapshot['subscriptions'] as Map).values.single as Map)['state'],
      'conflict',
    );
  });

  test('unsupported schema pauses only the affected subscription', () async {
    final localId = await subscribeRoot();
    aPort.schema = 11;
    aPort.items[rootId]!.members.add('post:2');
    await a.synchronize();
    await b.synchronize();
    expect(bPort.items[localId]!.members, {'post:1'});
    expect(
      ((b.snapshot['subscriptions'] as Map).values.single as Map)['state'],
      'update_required',
    );
  });

  test('withdrawal and source deletion retain content', () async {
    final localId = await subscribeRoot();
    await a.setPublication((await aPort.sources()).single, enabled: false);
    await a.synchronize();
    await b.synchronize();
    expect(bPort.items[localId]!.members, {'post:1'});
    expect(
      ((b.snapshot['subscriptions'] as Map).values.single as Map)['state'],
      'withdrawn',
    );
    aPort.items.remove(rootId);
    await a.synchronize();
    await b.synchronize();
    expect(bPort.items.containsKey(localId), true);
    expect(
      ((b.snapshot['subscriptions'] as Map).values.single as Map)['state'],
      'deleted',
    );
  });

  test(
    'direct and inherited scope deduplicate; new children require both opt-ins',
    () async {
      aPort.put(childId, 'Child', {'post:2'}, parent: rootId);
      await a.setPublication(
        (await aPort.sources()).first,
        enabled: true,
        subtree: true,
        includeFutureChildren: true,
      );
      await a.setPublication((await aPort.sources()).last, enabled: true);
      await a.synchronize();
      final found = await offer();
      await b.subscribe(
        offer: found['offer'] as Map<String, dynamic>,
        publisher: found['publisher'] as String,
        name: 'Root',
        includeFutureChildren: true,
      );
      await b.synchronize();
      expect((b.snapshot['subscriptions'] as Map).length, 2);
      expect((a.snapshot['publications'] as Map).length, 2);
      aPort.put(futureId, 'Future', {'post:3'}, parent: rootId);
      await a.synchronize();
      await b.synchronize();
      expect((b.snapshot['subscriptions'] as Map).length, 3);
      expect(bPort.items.length, 3);
    },
  );

  test('future-child receive defaults off', () async {
    await a.setPublication(
      (await aPort.sources()).first,
      enabled: true,
      subtree: true,
      includeFutureChildren: true,
    );
    await a.synchronize();
    final found = await offer();
    await b.subscribe(
      offer: found['offer'] as Map<String, dynamic>,
      publisher: found['publisher'] as String,
      name: 'Root',
    );
    await b.synchronize();
    aPort.put(childId, 'Child', {'post:2'}, parent: rootId);
    await a.synchronize();
    await b.synchronize();
    expect((b.snapshot['subscriptions'] as Map).length, 1);
  });

  test(
    'confirmed local deletion cannot be resurrected by future parent scope',
    () async {
      aPort.put(childId, 'Child', {'post:2'}, parent: rootId);
      await a.setPublication(
        (await aPort.sources()).first,
        enabled: true,
        subtree: true,
        includeFutureChildren: true,
      );
      await a.synchronize();
      final found = await offer();
      await b.subscribe(
        offer: found['offer'] as Map<String, dynamic>,
        publisher: found['publisher'] as String,
        name: 'Root',
        includeFutureChildren: true,
      );
      await b.synchronize();
      final child = (b.snapshot['subscriptions'] as Map).values
          .cast<Map>()
          .singleWhere((s) => s['source'] == childId);
      final localId = child['localId'] as String;
      bPort.items.remove(localId);
      await b.groupsDeleted({localId});
      aPort.items[childId]!.members.add('post:3');
      await a.synchronize();
      await b.synchronize();
      expect(bPort.items.containsKey(localId), false);
      expect((b.snapshot['subscriptions'] as Map).length, 1);
    },
  );

  test(
    'failed durable metadata write restores last durable settings',
    () async {
      aMetadata.fail = true;
      await expectLater(
        a.setPublication((await aPort.sources()).first, enabled: true),
        throwsStateError,
      );
      expect(a.snapshot['rules'], isEmpty);
      aMetadata.fail = false;
    },
  );
  test(
    'failed outgoing source cannot stop an unrelated incoming update',
    () async {
      final localId = await subscribeRoot();
      bPort.put(childId, 'Local outgoing', {'local:1'});
      await b.setPublication(
        (await bPort.sources()).singleWhere((s) => s.id == childId),
        enabled: true,
      );
      bPort.failCapture.add(childId);
      aPort.items[rootId]!.members = {'post:2'};
      await a.synchronize();
      await b.synchronize();
      expect(bPort.items[localId]!.members, {'post:2'});
      expect(
        (b.snapshot['activity'] as List).any(
          (row) => row['state'] == 'publication_failed',
        ),
        true,
      );
    },
  );
  test(
    'definition changes use a separate seen dot and no numeric post additions',
    () async {
      aPort.kind = bPort.kind = 'following_topics';
      aPort.definitions = bPort.definitions = true;
      final localId = await subscribeRoot();
      await b.markSeen('following_topics', localId);
      aPort.items[rootId]!.members = {'query:changed'};
      await a.synchronize();
      await b.synchronize();
      final subscription =
          (b.snapshot['subscriptions'] as Map).values.single as Map;
      expect(subscription['unseen'], isEmpty);
      expect(subscription['changed'], true);
      await b.markSeen('following_topics', localId);
      expect(
        ((b.snapshot['subscriptions'] as Map).values.single as Map)['changed'],
        false,
      );
    },
  );
  test('restart forgets a locally deleted mirror even without a new remote revision', () async {
    final localId = await subscribeRoot();
    bPort.items.remove(localId);
    await b.synchronize();
    expect(b.snapshot['subscriptions'], isEmpty);
    expect(bPort.items, isEmpty);
  });
  test(
    'publication exclusions and provenance preserve independent direct rules',
    () async {
      aPort.put(childId, 'Child', {'post:2'}, parent: rootId);
      final sources = await aPort.sources();
      final root = sources.singleWhere((s) => s.id == rootId);
      final child = sources.singleWhere((s) => s.id == childId);
      await a.setPublication(
        root,
        enabled: true,
        subtree: true,
        includeFutureChildren: true,
      );
      expect(a.publicationSelection(child, sources).inherited, true);
      await a.excludeInherited(child, excluded: true);
      expect(a.publicationSelection(child, sources).excluded, true);
      expect(a.publicationSelection(child, sources).inherited, false);
      await a.setPublication(
        root,
        enabled: true,
        subtree: true,
        includeFutureChildren: false,
      );
      expect(a.publicationSelection(child, sources).excluded, true);
      await a.setPublication(child, enabled: true);
      final selection = a.publicationSelection(child, sources);
      expect(selection.direct, true);
      expect(selection.excluded, true);
      await a.synchronize();
      expect((a.snapshot['publications'] as Map).length, 2);
      await a.setPublication(child, enabled: false);
      await a.synchronize();
      expect(
        (a.snapshot['publications'] as Map)['bookmarks/$childId']['state'],
        'withdrawn',
      );
      await a.excludeInherited(child, excluded: false);
      expect(a.publicationSelection(child, sources).inherited, true);
    },
  );
  test('bounded retention preserves retained catalogs, current revisions and unknown/foreign files', () async {
    await a.setPublication((await aPort.sources()).first, enabled: true);
    final publisher = (a.snapshot['identity'] as Map)['id'] as String;
    final foreign = (b.snapshot['identity'] as Map)['id'] as String;
    final base = 'devices/$publisher/collections/bookmarks/$rootId';
    final foreignPath =
        'devices/$foreign/collections/bookmarks/$rootId/1.bsexport';
    storage.files['$base/notes.txt'] = Uint8List.fromList([9]);
    storage.files['$base/001.json'] = Uint8List.fromList([9]);
    storage.files[foreignPath] = Uint8List.fromList([8]);
    for (var i = 1; i <= 36; i++) {
      aPort.items[rootId]!.members = {'post:$i'};
      await a.synchronize();
    }
    final catalogs = await storage.list('devices/$publisher/catalog');
    expect(catalogs.length, lessThanOrEqualTo(16));
    expect(storage.files.containsKey('$base/36.bsexport'), true);
    expect(storage.files.containsKey('$base/36.json'), true);
    expect(storage.files.containsKey('$base/1.bsexport'), false);
    expect(storage.files.containsKey('$base/notes.txt'), true);
    expect(storage.files.containsKey('$base/001.json'), true);
    expect(storage.files.containsKey(foreignPath), true);
    storage.failWrite = '$base/37.json';
    aPort.items[rootId]!.members = {'post:37'};
    await expectLater(a.synchronize(), throwsStateError);
    expect(storage.files.containsKey('$base/36.bsexport'), true);
    expect(storage.files.containsKey('$base/36.json'), true);
  });
  test('missing own publication files are repaired as fresh immutable revisions without content edits', () async {
    final localId = await subscribeRoot();
    final owner = (a.snapshot['identity'] as Map)['id'] as String;
    storage.files.removeWhere((path, _) => path.startsWith('devices/$owner/'));
    await a.synchronize();
    expect(
      storage.files.keys.any(
        (path) => path.startsWith('devices/$owner/catalog/'),
      ),
      true,
    );
    final publication =
        (a.snapshot['publications'] as Map)['bookmarks/$rootId'] as Map;
    expect(publication['revision'], 2);
    expect(
      storage.files.containsKey(
        'devices/$owner/collections/bookmarks/$rootId/2.bsexport',
      ),
      true,
    );
    await b.synchronize();
    expect(bPort.items[localId]!.members, {'post:1'});
    storage.files.removeWhere(
      (path, _) => path.startsWith('devices/$owner/catalog/'),
    );
    await a.synchronize();
    expect(
      storage.files.keys.any(
        (path) => path.startsWith('devices/$owner/catalog/'),
      ),
      true,
    );
  });
  test('unsubscribe retains a read-only mirror, resume reuses mapping, detach explicitly enables editing', () async {
    final localId = await subscribeRoot();
    final key = (b.snapshot['subscriptions'] as Map).keys.single as String;
    await b.unsubscribe(key);
    expect((b.snapshot['subscriptions'] as Map)[key]['subscribed'], false);
    aPort.items[rootId]!.members = {'post:2'};
    await a.synchronize();
    await b.synchronize();
    expect(bPort.items[localId]!.members, {'post:1'});
    await expectLater(
      b.setPublication((await bPort.sources()).single, enabled: true),
      throwsStateError,
    );
    await b.resubscribe(key);
    await b.synchronize();
    expect(bPort.items.keys, [localId]);
    expect(bPort.items[localId]!.members, {'post:2'});
    await b.detach(key);
    expect(b.snapshot['subscriptions'], isEmpty);
    await b.setPublication((await bPort.sources()).single, enabled: true);
    expect((b.snapshot['rules'] as Map).length, 1);
  });
}

class _Metadata implements FolderSyncMetadataStore {
  Map<String, dynamic> value = {};
  bool fail = false;
  @override
  Future<Map<String, dynamic>> load() async =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  @override
  Future<void> save(Map<String, dynamic> data) async {
    if (fail) throw StateError('Disk failure');
    value = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }
}

class _Storage implements FolderSyncStorage {
  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) async {
    if (!isOwnedSyncRevisionPath(path, owner)) throw const FormatException();
    files.remove(path);
  }

  final files = <String, Uint8List>{};
  final writes = <String>[];
  String? failWrite;
  @override
  Future<List<String>> list(String path) async {
    final prefix = path.isEmpty ? '' : '$path/';
    return files.keys
        .where((key) => key.startsWith(prefix))
        .map((key) => key.substring(prefix.length).split('/').first)
        .toSet()
        .toList()
      ..sort();
  }

  @override
  Future<Uint8List?> read(
    String path, {
    int maxBytes = folderSyncMaxBytes,
  }) async {
    final value = files[path];
    if (value != null && value.length > maxBytes) throw const FormatException();
    return value;
  }

  @override
  Future<void> writeImmutable(String path, Uint8List bytes) async {
    if (path == failWrite) throw StateError('Interrupted publication');
    if (files.containsKey(path) &&
        base64Encode(files[path]!) != base64Encode(bytes))
      throw StateError('Immutable overwrite');
    files[path] = bytes;
    writes.add(path);
  }
}

class _Item {
  _Item(this.name, this.members, this.parent);
  String name;
  Set<String> members;
  String? parent;
}

class _Port implements SyncCollectionPort {
  final items = <String, _Item>{};
  var applies = 0;
  var kind = 'bookmarks';
  var definitions = false;
  final failCapture = <String>{};
  var schema = 10;
  void put(String id, String name, Set<String> members, {String? parent}) =>
      items[id] = _Item(name, members, parent);
  @override
  Future<List<SyncSourceCollection>> sources() async => [
    for (final entry in items.entries)
      SyncSourceCollection(
        kind: kind,
        id: entry.key,
        name: entry.value.name,
        parentId: entry.value.parent,
        container: items.values.any((i) => i.parent == entry.key),
      ),
  ];
  Uint8List _bytes(Set<String> members) =>
      syncJsonBytes({'members': members.toList()..sort()});
  @override
  Future<SyncCapturedCollection> capture(SyncSourceCollection source) async {
    if (failCapture.contains(source.id)) throw StateError('Source unavailable');
    final item = items[source.id]!;
    final bytes = _bytes(item.members);
    return SyncCapturedCollection(
      bytes: bytes,
      semanticHash: syncDigest(bytes),
      members: definitions ? {} : item.members,
      schema: schema,
    );
  }

  @override
  Future<SyncAppliedCollection?> inspect(String kind, String localId) async {
    final item = items[localId];
    return item == null
        ? null
        : SyncAppliedCollection(
            localId: localId,
            members: definitions ? {} : item.members,
            semanticHash: syncDigest(_bytes(item.members)),
          );
  }

  @override
  Future<SyncAppliedCollection> apply({
    required SyncRevision revision,
    required Uint8List bytes,
    required String localId,
    required String name,
    String? parentId,
  }) async {
    if (revision.schema != 10) throw const SyncUpdateRequired();
    final members = (decodeSyncObject(bytes)['members'] as List)
        .cast<String>()
        .toSet();
    final existing = items[localId];
    items[localId] = _Item(
      existing?.name ?? name,
      members,
      existing?.parent ?? parentId,
    );
    applies++;
    return (await inspect(kind, localId))!;
  }
}
