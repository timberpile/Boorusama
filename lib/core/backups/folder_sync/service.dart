import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'protocol.dart';
import 'storage.dart';

final class SyncSourceCollection {
  const SyncSourceCollection({
    required this.kind,
    required this.id,
    required this.name,
    this.parentId,
    this.container = false,
  });
  final String kind;
  final String id;
  final String name;
  final String? parentId;
  final bool container;
  String get key => '$kind/$id';
}

final class SyncPublicationSelection {
  const SyncPublicationSelection({
    required this.direct,
    required this.inherited,
    required this.excluded,
    required this.canRestore,
  });
  final bool direct;
  final bool inherited;
  final bool excluded;
  final bool canRestore;
}

final class SyncCapturedCollection {
  const SyncCapturedCollection({
    required this.bytes,
    required this.semanticHash,
    required this.members,
    required this.schema,
  });
  final Uint8List bytes;
  final String semanticHash;
  final Set<String> members;
  final int schema;
}

final class SyncAppliedCollection {
  const SyncAppliedCollection({
    required this.localId,
    required this.members,
    required this.semanticHash,
  });
  final String localId;
  final Set<String> members;
  final String semanticHash;
}

abstract interface class SyncCollectionPort {
  Future<List<SyncSourceCollection>> sources();
  Future<SyncCapturedCollection> capture(SyncSourceCollection source);
  Future<SyncAppliedCollection?> inspect(String kind, String localId);

  /// The caller has approved this exact publisher/identity. The port validates
  /// and imports through the existing journaled pipeline, retaining local name
  /// and placement. Returning success means the local transaction committed.
  Future<SyncAppliedCollection> apply({
    required SyncRevision revision,
    required Uint8List bytes,
    required String localId,
    required String name,
    String? parentId,
  });
}

abstract interface class FolderSyncMetadataStore {
  Future<Map<String, dynamic>> load();
  Future<void> save(Map<String, dynamic> value);
}

final class FolderSyncService {
  FolderSyncService({
    required this.metadata,
    required this.port,
    required this.storageFor,
    this.bindingsChanged,
    this.followingBindingsChanged,
    this.now = DateTime.now,
  });
  final FolderSyncMetadataStore metadata;
  final SyncCollectionPort port;
  final FolderSyncStorage Function(String location) storageFor;
  final void Function(Set<String> groupIds)? bindingsChanged;
  final void Function(Set<String> ids)? followingBindingsChanged;
  final DateTime Function() now;
  Map<String, dynamic> _data = {};
  Map<String, dynamic> _committed = {};
  Future<void>? _initialization;
  Future<void> _tail = Future.value();
  final _changes = StreamController<void>.broadcast(sync: true);
  Stream<void> get changes => _changes.stream;
  bool get configured => _data['location'] is String;
  String? get location => _data['location'] as String?;
  var busy = false;
  Object? lastError;
  DateTime? lastSync;
  Map<String, dynamic>? _view;
  Map<String, dynamic> get snapshot =>
      _view ??= Map<String, dynamic>.unmodifiable(
        _freeze(_data)! as Map<String, dynamic>,
      );
  Object? _freeze(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(
        value.map((k, v) => MapEntry(k, _freeze(v))),
      );
    }
    if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
    return value;
  }

  Map<String, dynamic> get _subscriptions =>
      _data['subscriptions'] as Map<String, dynamic>;
  Map<String, dynamic> get _publications =>
      _data['publications'] as Map<String, dynamic>;
  Map<String, dynamic> get _rules => _data['rules'] as Map<String, dynamic>;
  Map<String, dynamic> get _trust => _data['trust'] as Map<String, dynamic>;
  SyncSigningIdentity get _identity =>
      SyncSigningIdentity.fromJson(_data['identity'] as Map<String, dynamic>);

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    _data = await metadata.load();
    if (_data.isNotEmpty && _data['version'] != 1) {
      throw const SyncUpdateRequired();
    }
    if (_data.isEmpty) {
      _data = {
        'version': 1,
        'identity': (await SyncSigningIdentity.create()).localJson(),
        'sequence': 0,
        'rules': <String, dynamic>{},
        'publications': <String, dynamic>{},
        'subscriptions': <String, dynamic>{},
        'trust': <String, dynamic>{},
        'activity': <dynamic>[],
      };
      await _persist();
    }
    _committed = jsonDecode(jsonEncode(_data)) as Map<String, dynamic>;
    _notifyBindings();
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final pending = _tail.then((_) async {
      await initialize();
      try {
        return await operation();
      } catch (_) {
        _data = jsonDecode(jsonEncode(_committed)) as Map<String, dynamic>;
        _notifyBindings();
        rethrow;
      }
    });
    _tail = pending.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return pending;
  }

  Future<void> _persist() async {
    await metadata.save(_data);
    _view = null;
    _committed = jsonDecode(jsonEncode(_data)) as Map<String, dynamic>;
    _notifyBindings();
    if (!_changes.isClosed) _changes.add(null);
  }

  void _notifyBindings() {
    final subscriptions =
        (_data['subscriptions'] as Map<String, dynamic>? ?? {}).values;
    bindingsChanged?.call({
      for (final value in subscriptions)
        if (value is Map &&
            value['kind'] == 'bookmarks' &&
            value['localId'] is String)
          value['localId'] as String,
    });
    followingBindingsChanged?.call({
      for (final value in subscriptions)
        if (value is Map &&
            value['kind'] == 'following_topics' &&
            value['localId'] is String)
          value['localId'] as String,
    });
  }

  Future<void> chooseFolder(String location) => _serialized(() async {
    await storageFor(location).list('');
    _data['location'] = location;
    await _persist();
  });

  SyncPublicationSelection publicationSelection(
    SyncSourceCollection source,
    List<SyncSourceCollection> sources,
  ) {
    final byId = {
      for (final item in sources.where((s) => s.kind == source.kind))
        item.id: item,
    };
    final path = <String>{source.id};
    var current = source;
    while (current.parentId != null) {
      final parent = current.parentId!;
      if (!path.add(parent)) break;
      final next = byId[parent];
      if (next == null) break;
      current = next;
    }
    var inherited = false;
    var excluded = false;
    var canRestore = false;
    for (final raw in _rules.values) {
      final rule = raw as Map<String, dynamic>;
      if (rule['kind'] != source.kind ||
          rule['source'] == source.id ||
          rule['subtree'] != true ||
          !path.contains(rule['source']))
        continue;
      if (rule['future'] != true &&
          !(rule['captured'] as List).contains(source.id))
        continue;
      final exclusions = (rule['excluded'] as List).cast<String>().toSet();
      if (exclusions.intersection(path).isEmpty)
        inherited = true;
      else {
        excluded = true;
        canRestore = canRestore || exclusions.contains(source.id);
      }
    }
    return SyncPublicationSelection(
      direct: _rules.containsKey(source.key),
      inherited: inherited,
      excluded: excluded,
      canRestore: canRestore,
    );
  }

  Future<void> excludeInherited(
    SyncSourceCollection source, {
    required bool excluded,
  }) => _serialized(() async {
    final sources = await port.sources();
    for (final raw in _rules.values) {
      final rule = raw as Map<String, dynamic>;
      if (rule['kind'] != source.kind ||
          rule['source'] == source.id ||
          rule['subtree'] != true)
        continue;
      final root = sources
          .where((s) => s.kind == source.kind && s.id == rule['source'])
          .firstOrNull;
      if (root == null || !_descendants(root, sources).contains(source.id))
        continue;
      if (rule['future'] != true &&
          !(rule['captured'] as List).contains(source.id))
        continue;
      final exclusions = (rule['excluded'] as List).cast<String>().toSet();
      if (excluded)
        exclusions.add(source.id);
      else
        exclusions.remove(source.id);
      rule['excluded'] = exclusions.toList()..sort();
    }
    await _persist();
  });

  Future<void> setPublication(
    SyncSourceCollection source, {
    required bool enabled,
    bool subtree = false,
    bool includeFutureChildren = false,
    Set<String>? exclusions,
  }) => _serialized(() async {
    if (_subscriptions.values.any(
      (s) => s['kind'] == source.kind && s['localId'] == source.id,
    )) {
      throw StateError('Received collections cannot be published');
    }
    if (enabled) {
      final all = await port.sources();
      final captured = _descendants(source, all);
      _rules[source.key] = {
        'kind': source.kind,
        'source': source.id,
        'subtree': subtree,
        'future': includeFutureChildren,
        'captured': captured.toList()..sort(),
        'excluded':
            (exclusions ??
                    (_rules[source.key]?['excluded'] as List?)
                        ?.cast<String>()
                        .toSet() ??
                    const <String>{})
                .toList()
              ..sort(),
      };
    } else {
      _rules.remove(source.key);
    }
    await _persist();
  });
  Set<String> _descendants(
    SyncSourceCollection root,
    List<SyncSourceCollection> all,
  ) {
    final ids = <String>{root.id};
    final children = <String, List<SyncSourceCollection>>{};
    for (final source in all.where((s) => s.kind == root.kind)) {
      if (source.parentId case final parent?) {
        (children[parent] ??= []).add(source);
      }
    }
    final pending = [root.id];
    while (pending.isNotEmpty) {
      for (final child
          in children[pending.removeLast()] ?? const <SyncSourceCollection>[]) {
        if (ids.add(child.id)) pending.add(child.id);
      }
    }
    return ids;
  }

  Future<void> approvePublisher(String publisher, String publicKey) =>
      _serialized(() async {
        syncUuid(publisher);
        if (base64Decode(publicKey).length != 32) {
          throw const FormatException('Invalid publisher key');
        }
        final previous = _trust[publisher];
        if (previous != null && previous != publicKey) {
          throw const FormatException('Publisher key changed');
        }
        _trust[publisher] = publicKey;
        await _persist();
      });

  Future<List<Map<String, dynamic>>> discover() => _serialized(_discover);
  Future<List<Map<String, dynamic>>> _discover() async {
    if (!configured) return const [];
    final storage = storageFor(location!);
    final found = <Map<String, dynamic>>[];
    for (final publisher in await storage.list('devices')) {
      if (!Uuid.isValidUUID(fromString: publisher) ||
          publisher == _identity.id) {
        continue;
      }
      try {
        final bytes = await storage.read(
          'devices/$publisher/identity.json',
          maxBytes: 4096,
        );
        if (bytes == null) continue;
        final identity = decodeSyncObject(bytes, maximum: 4096);
        if (identity['protocol'] != folderSyncProtocol ||
            identity['id'] != publisher) {
          continue;
        }
        final keyText = identity['publicKey'] as String;
        final key = base64Decode(keyText);
        if (key.length != 32 ||
            (_trust[publisher] != null && _trust[publisher] != keyText)) {
          throw const FormatException('Publisher key changed');
        }
        final names =
            (await storage.list('devices/$publisher/catalog'))
                .where((n) => RegExp(r'^[1-9][0-9]{0,15}\.json$').hasMatch(n))
                .toList()
              ..sort(
                (a, b) =>
                    int.parse(b.split('.').first)
                        .compareTo(int.parse(a.split('.').first)),
              );
        // An incomplete newest catalog cannot hide the last complete revision.
        Map<String, dynamic>? catalog;
        for (final name in names.take(8)) {
          try {
            final bytes = await storage.read(
              'devices/$publisher/catalog/$name',
              maxBytes: 256 * 1024,
            );
            if (bytes == null) continue;
            final candidate = await verifySyncDocument(bytes, key);
            if (candidate['publisher'] != publisher ||
                candidate['sequence'] != int.parse(name.split('.').first)) {
              continue;
            }
            final collections = candidate['collections'];
            if (collections is! List ||
                collections.length > folderSyncMaxEntries) {
              continue;
            }
            catalog = candidate;
            break;
          } on FormatException {
            continue;
          }
        }
        found.add({
          'publisher': publisher,
          'publicKey': keyText,
          'fingerprint': syncDigest(key),
          'trusted': _trust[publisher] == keyText,
          'collections': catalog?['collections'] ?? const [],
          'sequence': catalog?['sequence'],
        });
      } catch (error) {
        _activity('discovery_failed', publisher, error: error);
      }
    }
    return found;
  }

  Future<void> subscribe({
    required Map<String, dynamic> offer,
    required String publisher,
    required String name,
    String? parentId,
    bool includeFutureChildren = false,
    bool copyStructure = true,
  }) => _serialized(() async {
    if (_trust[publisher] == null) {
      throw StateError('Publisher approval required');
    }
    if (offer['state'] != 'active') {
      throw StateError('Publication is unavailable');
    }
    final root = SyncCollectionId(
      publisher: publisher,
      kind: offer['kind'] as String,
      source: offer['source'] as String,
    );
    final subscription = _addSubscription(
      offer,
      publisher,
      name,
      parentId,
      direct: true,
    );
    subscription['future'] = includeFutureChildren;
    subscription['copyStructure'] = copyStructure;
    if (offer['container'] == true) {
      final publisherData = (await _discover())
          .where((p) => p['publisher'] == publisher)
          .firstOrNull;
      if (publisherData != null) {
        _includeChildren(
          subscription,
          (publisherData['collections'] as List)
              .whereType<Map<String, dynamic>>()
              .toList(),
          initial: true,
        );
      }
    }
    _subscriptions[root.key] = subscription;
    await _persist();
  });
  Map<String, dynamic> _addSubscription(
    Map<String, dynamic> offer,
    String publisher,
    String name,
    String? parentId, {
    required bool direct,
    String? inherited,
  }) {
    final id = SyncCollectionId(
      publisher: publisher,
      kind: offer['kind'] as String,
      source: offer['source'] as String,
    );
    final existing = _subscriptions[id.key] as Map<String, dynamic>?;
    if (existing != null) {
      if (direct) existing['direct'] = true;
      existing['subscribed'] = true;
      if (existing['state'] == 'unsubscribed')
        existing['state'] = (existing['applied'] as int) > 0
            ? 'ready'
            : 'pending';
      if (inherited != null) {
        existing['inherited'] = {
          ...(existing['inherited'] as List? ?? const []).cast<String>(),
          inherited,
        }.toList();
      }
      return existing;
    }
    final value = <String, dynamic>{
      'publisher': publisher,
      'kind': id.kind,
      'source': id.source,
      'localId': const Uuid().v4(),
      'name': name.trim().isEmpty ? offer['name'] : name.trim(),
      'parentId': parentId,
      'applied': 0,
      'seen': 0,
      'members': <String>[],
      'unseen': <String>[],
      'future': false,
      'subscribed': true,
      'direct': direct,
      'inherited': [?inherited],
      'excluded': <String>[],
      'state': 'pending',
    };
    _subscriptions[id.key] = value;
    return value;
  }

  void _includeChildren(
    Map<String, dynamic> root,
    List<Map<String, dynamic>> offers, {
    required bool initial,
  }) {
    final scopeKey = '${root['publisher']}/${root['kind']}/${root['source']}';
    final pending = [root['source'] as String];
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final sourceParent = pending.removeAt(0);
      if (!visited.add(sourceParent)) continue;
      for (final offer in offers) {
        if (offer['kind'] != root['kind'] ||
            offer['parentId'] != sourceParent ||
            offer['state'] != 'active') {
          continue;
        }
        final source = offer['source'] as String;
        if ((root['excluded'] as List? ?? const []).contains(source)) continue;
        final key = '${root['publisher']}/${root['kind']}/$source';
        final existing = _subscriptions[key];
        if (!initial &&
            existing == null &&
            (root['future'] != true || offer['futureAllowed'] != true)) {
          continue;
        }
        final mappedParent =
            _subscriptions['${root['publisher']}/${root['kind']}/$sourceParent'];
        _addSubscription(
          offer,
          root['publisher'] as String,
          offer['name'] as String,
          root['copyStructure'] == true
              ? (mappedParent?['localId'] as String?)
              : (root['parentId'] as String?),
          direct: false,
          inherited: scopeKey,
        );
        pending.add(source);
      }
    }
  }

  Future<void> unsubscribe(String key) => _serialized(() async {
    final removed = _subscriptions[key] as Map<String, dynamic>?;
    if (removed == null) return;
    removed['direct'] = false;
    if ((removed['inherited'] as List? ?? const []).isEmpty) {
      removed['subscribed'] = false;
      removed['state'] = 'unsubscribed';
    }
    for (final entry in _subscriptions.entries.toList()) {
      final value = entry.value as Map<String, dynamic>;
      final inherited = (value['inherited'] as List? ?? const [])
          .cast<String>()
          .where((scope) => scope != key)
          .toList();
      value['inherited'] = inherited;
      if (value['direct'] != true && inherited.isEmpty) {
        value['subscribed'] = false;
        value['state'] = 'unsubscribed';
      }
    }
    await _persist();
  });
  Future<void> resubscribe(String key) => _serialized(() async {
    final value = _subscriptions[key] as Map<String, dynamic>?;
    if (value == null || _trust[value['publisher']] == null)
      throw StateError('Subscription approval required');
    value['direct'] = true;
    value['subscribed'] = true;
    value['state'] = (value['applied'] as int) > 0 ? 'ready' : 'pending';
    await _persist();
  });

  Future<void> detach(String key) => _serialized(() async {
    final removed = _subscriptions.remove(key) as Map<String, dynamic>?;
    if (removed != null) {
      for (final parent
          in (removed['inherited'] as List? ?? const []).cast<String>()) {
        final scope = _subscriptions[parent];
        if (scope != null) {
          scope['excluded'] = {
            ...(scope['excluded'] as List? ?? const []).cast<String>(),
            removed['source'] as String,
          }.toList();
        }
      }
    }
    for (final entry in _subscriptions.entries.toList()) {
      final value = entry.value as Map<String, dynamic>;
      value['inherited'] = (value['inherited'] as List? ?? const [])
          .where((scope) => scope != key)
          .toList();
      if (value['direct'] != true && (value['inherited'] as List).isEmpty)
        _subscriptions.remove(entry.key);
    }
    await _persist();
  });
  Future<void> groupsDeleted(Set<String> ids) => _serialized(() async {
    for (final entry in _subscriptions.entries.toList()) {
      if (entry.value['kind'] == 'bookmarks' &&
          ids.contains(entry.value['localId'])) {
        _forgetBinding(entry.key);
      }
    }
    await _persist();
  });
  void _forgetBinding(String key) {
    final removed = _subscriptions.remove(key) as Map<String, dynamic>?;
    if (removed == null) return;
    for (final scope
        in (removed['inherited'] as List? ?? const []).cast<String>()) {
      final parent = _subscriptions[scope];
      if (parent != null) {
        parent['excluded'] = {
          ...(parent['excluded'] as List? ?? const []).cast<String>(),
          removed['source'] as String,
        }.toList();
      }
    }
    for (final entry in _subscriptions.entries.toList()) {
      final value = entry.value as Map<String, dynamic>;
      value['inherited'] = (value['inherited'] as List? ?? const [])
          .where((scope) => scope != key)
          .toList();
      if (value['direct'] != true && (value['inherited'] as List).isEmpty)
        _subscriptions.remove(entry.key);
    }
  }

  Future<void> markSeen(String kind, String localId) => _serialized(() async {
    for (final s in _subscriptions.values) {
      if (s['kind'] == kind && s['localId'] == localId) {
        s['seen'] = s['applied'];
        s['unseen'] = <String>[];
        s['changed'] = false;
      }
    }
    await _persist();
  });

  Future<void> synchronize() => _serialized(() async {
    if (!configured || busy) return;
    busy = true;
    lastError = null;
    _changes.add(null);
    try {
      final localKeys = {for (final source in await port.sources()) source.key};
      for (final entry in _subscriptions.entries.toList()) {
        final subscription = entry.value;
        if ((subscription['applied'] as int) > 0 &&
            !localKeys.contains(
              '${subscription['kind']}/${subscription['localId']}',
            )) {
          _forgetBinding(entry.key);
        }
      }
      await _publish();
      final publishers = await _discover();
      for (final publisher in publishers.where((p) => p['trusted'] == true)) {
        for (final subscription in _subscriptions.values.toList()) {
          if (subscription['publisher'] == publisher['publisher'] &&
              subscription['subscribed'] != false) {
            _includeChildren(
              subscription as Map<String, dynamic>,
              (publisher['collections'] as List)
                  .whereType<Map<String, dynamic>>()
                  .toList(),
              initial: false,
            );
          }
        }
        final offers = {
          for (final raw in publisher['collections'] as List)
            if (raw is Map<String, dynamic>)
              '${raw['kind']}/${raw['source']}': raw,
        };
        for (final entry in _subscriptions.entries.toList()) {
          final s = entry.value as Map<String, dynamic>;
          if (s['publisher'] != publisher['publisher'] ||
              s['subscribed'] == false)
            continue;
          final offer = offers['${s['kind']}/${s['source']}'];
          if (offer == null) {
            s['state'] = 'unavailable';
            continue;
          }
          if (offer['state'] != 'active') {
            s['state'] = offer['state'];
            continue;
          }
          try {
            await _receive(s, offer);
          } catch (error) {
            s['state'] = error is SyncProfileRequired
                ? 'profile_required'
                : error is SyncUpdateRequired
                ? 'update_required'
                : error is SyncConflict
                ? 'conflict'
                : 'failed';
            _activity(s['state'] as String, entry.key, error: error);
          }
        }
      }
      lastSync = now().toUtc();
      await _persist();
    } catch (error) {
      lastError = error;
      rethrow;
    } finally {
      busy = false;
      _changes.add(null);
    }
  });

  Future<void> _publish() async {
    final storage = storageFor(location!);
    final identity = _identity;
    await storage.writeImmutable(
      'devices/${identity.id}/identity.json',
      syncJsonBytes(identity.publicJson()),
    );
    final sources = await port.sources();
    final byKey = {for (final s in sources) s.key: s};
    final effective = <String>{};
    final futureEffective = <String>{};
    for (final raw in _rules.values) {
      final rule = raw as Map<String, dynamic>;
      final key = '${rule['kind']}/${rule['source']}';
      final root = byKey[key];
      if (root == null) continue;
      final ids = rule['subtree'] == true
          ? _descendants(root, sources)
          : {root.id};
      if (rule['future'] != true) {
        ids.retainAll((rule['captured'] as List).cast<String>());
      }
      for (final excluded in (rule['excluded'] as List).cast<String>()) {
        final node = byKey['${root.kind}/$excluded'];
        ids.removeAll(node == null ? {excluded} : _descendants(node, sources));
      }
      for (final id in ids) {
        if (!_subscriptions.values.any(
          (s) => s['kind'] == root.kind && s['localId'] == id,
        )) {
          effective.add('${root.kind}/$id');
          if (rule['future'] == true) futureEffective.add('${root.kind}/$id');
        }
      }
    }
    for (final key in effective.toList()..sort()) {
      final source = byKey[key]!;
      final SyncCapturedCollection captured;
      try {
        captured = await port.capture(source);
      } catch (error) {
        _activity('publication_failed', key, error: error);
        continue;
      }
      final prior = _publications[key] as Map<String, dynamic>?;
      if (prior != null &&
          prior['semanticHash'] == captured.semanticHash &&
          prior['state'] == 'active' &&
          await _publicationIntact(
            storage,
            identity,
            SyncRevision.fromJson(prior),
          )) {
        prior['name'] = source.name;
        prior['parentId'] = source.parentId;
        prior['container'] = source.container;
        prior['futureAllowed'] = futureEffective.contains(key);
        continue;
      }
      final revisionNumber = (prior?['revision'] as int? ?? 0) + 1;
      final revision = SyncRevision(
        collection: SyncCollectionId(
          publisher: identity.id,
          kind: source.kind,
          source: source.id,
        ),
        revision: revisionNumber,
        length: captured.bytes.length,
        sha256: syncDigest(captured.bytes),
        semanticHash: captured.semanticHash,
        schema: captured.schema,
      );
      // Reserve revision before writing; crashes never reuse immutable names.
      _publications[key] = {
        ...revision.toJson(),
        'name': source.name,
        'parentId': source.parentId,
        'container': source.container,
        'futureAllowed': futureEffective.contains(key),
        'state': 'preparing',
      };
      await _persist();
      await storage.writeImmutable(revision.payloadPath, captured.bytes);
      await storage.writeImmutable(
        revision.descriptorPath,
        await identity.sign(revision.toJson()),
      );
      _publications[key]['state'] = 'active';
    }
    for (final key in _publications.keys.toList()) {
      if (effective.contains(key)) continue;
      _publications[key]['state'] = byKey.containsKey(key)
          ? 'withdrawn'
          : 'deleted';
    }
    final collections = [
      for (final key in _publications.keys.toList()..sort())
        if (_publications[key]['state'] != 'preparing') _publications[key],
    ];
    final catalogHash = syncDigest(syncJsonBytes(collections));
    if (_data['catalogHash'] == catalogHash &&
        await _catalogIntact(storage, identity, catalogHash)) {
      if (_data['retentionPending'] == true) await _tryPrune(storage, identity);
      return;
    }
    final sequence = (_data['sequence'] as int) + 1;
    _data['sequence'] = sequence;
    await _persist();
    await storage.writeImmutable(
      'devices/${identity.id}/catalog/$sequence.json',
      await identity.sign({
        'protocol': folderSyncProtocol,
        'publisher': identity.id,
        'sequence': sequence,
        'collections': collections,
      }),
    );
    _data['catalogHash'] = catalogHash;
    _data['retentionPending'] = true;
    await _persist();
    await _tryPrune(storage, identity);
  }

  Future<bool> _publicationIntact(
    FolderSyncStorage storage,
    SyncSigningIdentity identity,
    SyncRevision revision,
  ) async {
    try {
      final descriptor = await storage.read(
        revision.descriptorPath,
        maxBytes: 16384,
      );
      if (descriptor == null) return false;
      final content = await verifySyncDocument(descriptor, identity.publicKey);
      if (canonicalSyncJson(content) != canonicalSyncJson(revision.toJson()))
        return false;
      final payload = await storage.read(revision.payloadPath);
      if (payload == null) return false;
      revision.verifyPayload(payload);
      return true;
    } on FormatException {
      return false;
    } on SyncUpdateRequired {
      return false;
    }
  }

  Future<bool> _catalogIntact(
    FolderSyncStorage storage,
    SyncSigningIdentity identity,
    String semanticHash,
  ) async {
    try {
      final bytes = await storage.read(
        'devices/${identity.id}/catalog/${_data['sequence']}.json',
        maxBytes: 256 * 1024,
      );
      if (bytes == null) return false;
      final content = await verifySyncDocument(bytes, identity.publicKey);
      return content['publisher'] == identity.id &&
          content['sequence'] == _data['sequence'] &&
          syncDigest(syncJsonBytes(content['collections'])) == semanticHash;
    } on FormatException {
      return false;
    } on SyncUpdateRequired {
      return false;
    }
  }

  Future<void> _tryPrune(
    FolderSyncStorage storage,
    SyncSigningIdentity identity,
  ) async {
    try {
      await _prune(storage, identity);
      _data['retentionPending'] = false;
    } catch (error) {
      _data['retentionPending'] = true;
      _activity('retention_failed', identity.id, error: error);
    }
  }

  Future<void> _prune(
    FolderSyncStorage storage,
    SyncSigningIdentity identity,
  ) async {
    final catalogPath = 'devices/${identity.id}/catalog';
    final catalogs =
        (await storage.list(catalogPath))
            .where(
              (name) =>
                  isOwnedSyncRevisionPath('$catalogPath/$name', identity.id),
            )
            .toList()
          ..sort(
            (a, b) =>
                int.parse(b.split('.').first)
                    .compareTo(int.parse(a.split('.').first)),
          );
    final retainedCatalogs = catalogs.take(16).toSet();
    retainedCatalogs.add('${_data['sequence']}.json');
    final protected = <String, Set<int>>{};
    void protect(SyncRevision revision) {
      if (revision.collection.publisher != identity.id)
        throw const FormatException('Foreign retention reference');
      (protected[revision.collection.directory] ??= {}).add(revision.revision);
    }

    for (final name in retainedCatalogs) {
      final bytes = await storage.read(
        '$catalogPath/$name',
        maxBytes: 256 * 1024,
      );
      if (bytes == null)
        throw const FormatException(
          'Current catalog unavailable for retention',
        );
      final catalog = await verifySyncDocument(bytes, identity.publicKey);
      if (catalog['publisher'] != identity.id ||
          catalog['sequence'] != int.parse(name.split('.').first)) {
        throw const FormatException('Invalid retention catalog');
      }
      final rows = catalog['collections'];
      if (rows is! List || rows.length > folderSyncMaxEntries)
        throw const FormatException('Invalid retention catalog');
      for (final row in rows) {
        if (row is! Map<String, dynamic>)
          throw const FormatException('Invalid retention reference');
        protect(SyncRevision.fromJson(row));
      }
    }
    for (final raw in _publications.values) {
      protect(SyncRevision.fromJson(raw as Map<String, dynamic>));
    }
    // Remove unreferenced catalogs first. A crash cannot leave a retained
    // catalog pointing at a payload removed by this cleanup.
    for (final name in catalogs.where(
      (name) => !retainedCatalogs.contains(name),
    )) {
      await storage.deleteOwnedRevision(
        '$catalogPath/$name',
        owner: identity.id,
      );
    }
    for (final entry in protected.entries) {
      final names = (await storage.list(entry.key))
          .where(
            (name) =>
                isOwnedSyncRevisionPath('${entry.key}/$name', identity.id),
          )
          .toList();
      final revisions =
          names.map((name) => int.parse(name.split('.').first)).toSet().toList()
            ..sort((a, b) => b.compareTo(a));
      final keep = {...entry.value, ...revisions.take(32)};
      for (final name in names) {
        if (!keep.contains(int.parse(name.split('.').first))) {
          await storage.deleteOwnedRevision(
            '${entry.key}/$name',
            owner: identity.id,
          );
        }
      }
    }
  }

  Future<void> _receive(
    Map<String, dynamic> s,
    Map<String, dynamic> offer,
  ) async {
    final revision = SyncRevision.fromJson(offer);
    if (revision.collection.publisher != s['publisher'] ||
        revision.collection.kind != s['kind'] ||
        revision.collection.source != s['source']) {
      throw const FormatException('Sync identity mismatch');
    }
    final applied = s['applied'] as int;
    if (revision.revision < applied ||
        (revision.revision == applied && s['sha256'] != revision.sha256)) {
      throw const FormatException('Sync revision replay');
    }
    if (revision.revision == applied) return;
    final storage = storageFor(location!);
    final descriptorBytes = await storage.read(
      revision.descriptorPath,
      maxBytes: 16384,
    );
    if (descriptorBytes == null) {
      s['state'] = 'incomplete';
      return;
    }
    final descriptor = await verifySyncDocument(
      descriptorBytes,
      base64Decode(_trust[s['publisher']] as String),
    );
    if (canonicalSyncJson(descriptor) != canonicalSyncJson(revision.toJson())) {
      throw const FormatException('Sync descriptor mismatch');
    }
    final bytes = await storage.read(revision.payloadPath);
    if (bytes == null) {
      s['state'] = 'incomplete';
      return;
    }
    revision.verifyPayload(bytes);
    final current = await port.inspect(
      s['kind'] as String,
      s['localId'] as String,
    );
    if (applied > 0 && current == null) {
      // A confirmed local deletion wins over future incoming revisions.
      _forgetBinding(revision.collection.key);
      return;
    }
    final membersBefore = (s['members'] as List).cast<String>().toSet();
    if (current != null &&
        applied > 0 &&
        current.semanticHash != s['localHash'] &&
        current.semanticHash != revision.semanticHash) {
      throw const SyncConflict();
    }
    final result = await port.apply(
      revision: revision,
      bytes: bytes,
      localId: s['localId'] as String,
      name: s['name'] as String,
      parentId: s['parentId'] as String?,
    );
    final additions = result.members.difference(membersBefore);
    s['unseen'] = ({
      ...(s['unseen'] as List).cast<String>(),
      ...additions,
    }.intersection(result.members).toList()..sort());
    s['changed'] =
        s['changed'] == true ||
        (s['kind'] == 'following_topics' &&
            s['localHash'] != result.semanticHash) ||
        canonicalSyncJson(result.members.toList()..sort()) !=
            canonicalSyncJson(membersBefore.toList()..sort());
    s['members'] = result.members.toList()..sort();
    s['localHash'] = result.semanticHash;
    s['sha256'] = revision.sha256;
    s['applied'] = revision.revision;
    s['state'] = 'ready';
    _activity(
      'applied',
      revision.collection.key,
      additions: additions.length,
      removals: membersBefore.difference(result.members).length,
    );
    await _persist();
  }

  void _activity(
    String state,
    String identity, {
    int additions = 0,
    int removals = 0,
    Object? error,
  }) {
    final events = _data['activity'] as List<dynamic>;
    events.add({
      'time': now().toUtc().toIso8601String(),
      'state': state,
      'collection': identity,
      'additions': additions,
      'removals': removals,
      if (error != null) 'error': error.runtimeType.toString(),
    });
    if (events.length > 100) events.removeRange(0, events.length - 100);
  }

  Future<void> dispose() async {
    await _tail;
    unawaited(_changes.close());
  }
}
