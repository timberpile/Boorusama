import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:foundation/foundation.dart';
import 'package:foundation/performance.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../../../foundation/data_mutation_coordinator.dart';
import '../../../../../foundation/filesystem.dart';
import '../../../../../foundation/loggers/logger.dart';
import '../../../../boorus/booru/types.dart';
import '../../../../content/content_map.dart';
import '../../../../content/types.dart';
import '../../../../groups/folder_tree.dart';
import '../../../../posts/post/types.dart';
import '../../types/bookmark.dart';
import '../../types/bookmark_group.dart';
import '../../types/bookmark_group_tree.dart';
import '../../types/bookmark_group_repository.dart';
import '../../services/bookmark_storage_migration.dart';
import 'unified_bookmark_group_repository.dart';
import '../../types/unified_bookmark_store.dart';
import '../../types/bookmark_repository.dart';
import '../../types/content_group_bookmark.dart';
import '../../types/legacy_group_bookmark.dart';
import '../bookmark_convert.dart';
import '../bookmark_id_allocator.dart';
import '../stored_bookmark_codec.dart';
import '../stored_group_codec.dart';
import 'bookmark_hive_object.dart';
import 'bookmark_id_store.dart';
import 'bookmark_group_hive_object.dart';

part 'unified_bookmark_organization.dart';

/// One payload/kind/ID authority. The old Post box is retained unchanged; Group
/// payloads are private and no numeric range is used to determine record kind.
class BookmarkHiveRepository extends BookmarkRepository<Post>
    implements UnifiedBookmarkStore {
  BookmarkHiveRepository(
    this._posts, {
    required Box<dynamic> groupPayloadBox,
    required Box<dynamic> metadataBox,
    required this.coordinator,
    this.postDataCodec,
    this.legacyGroupBoxName = 'bookmark_groups',
    this.legacyOrganizationBoxName = 'bookmark_folders',
    GroupMetadataCodec groupMetadataCodec = const GroupMetadataCodec(),
    this.logger,
    this.fs = const IoFileSystem(),
    Future<void> Function(Iterable<BoxBase<dynamic>> boxes)? syncBoxes,
  }) : _groups = groupPayloadBox,
       _metadata = metadataBox,
       _syncOverride = syncBoxes,
       _codec = StoredBookmarkCodec(
         postDataCodec: postDataCodec,
         groups: StoredGroupCodec(metadata: groupMetadataCodec),
       );

  final String legacyGroupBoxName;
  final String legacyOrganizationBoxName;
  BookmarkGroupRepository? _organizationRepository;
  final Box<BookmarkHiveObject> _posts;
  final Box<dynamic> _groups;
  final Box<dynamic> _metadata;
  final DataMutationCoordinator coordinator;
  final AppFileSystem fs;
  final Logger? logger;
  final BooruPostDataCodec? Function(BooruType type)? postDataCodec;
  final StoredBookmarkCodec _codec;
  final Future<void> Function(Iterable<BoxBase<dynamic>> boxes)? _syncOverride;
  var _initialized = false;
  // Hive replaces raw maps on writes. Weak keys reuse immutable Group decoding
  // without retaining another library cache or keeping deleted payloads alive.
  final _decodedGroups = Expando<Bookmark>();
  (Box<BookmarkGroupHiveObject>, Box<dynamic>)? _organizationHandles;
  static const _journal = 'pendingMutation';
  static const _schema = 'repositorySchema';
  static const _revision = 'recordRevision';
  static const _floor = 'allocationFloor';
  static final _migrationZone = Object();
  late final _ids = HiveBookmarkIdStore(
    _metadata,
    fs: fs,
    sync: () => _sync([_metadata]),
  );
  late final _allocator = BookmarkIdAllocator(
    store: _ids,
    coordinator: coordinator,
    highestExistingId: () async => _highestPayloadId(),
  );

  Future<T> _ready<T>(Future<T> Function() action) =>
      coordinator.runExclusive(() async {
        if (_metadata.containsKey('organizationMigration') &&
            (_metadata.get('activeOrganization') == null ||
                contentMap(_metadata.get('organizationMigration'))['version'] ==
                    3) &&
            !identical(Zone.current[_migrationZone], this)) {
          throw StateError(
            'Bookmark organization migration requires recovery before library access',
          );
        }
        if (_metadata.get('activeOrganization') != null) {
          await _organizationBoxes();
        }
        if (!_initialized) {
          await _initialize();
          await _recover();
          _audit();
          _initialized = true;
        } else {
          await _recover();
        }
        return action();
      });

  /// The migration service is the only reader/writer of an unactivated staged
  /// generation. Ordinary facade callers remain blocked until recovery ends.
  Future<T> runStorageMigration<T>(Future<T> Function() operation) =>
      coordinator.runExclusive(
        () => runZoned(
          operation,
          zoneValues: {_migrationZone: this},
        ),
      );

  /// This gate completes migration/recovery before production publishes either
  /// repository. Original legacy boxes remain available for recovery.
  Future<BookmarkGroupRepository> openOrganization() =>
      coordinator.runExclusive(() async {
        final cached = _organizationRepository;
        if (cached != null) return cached;
        final reader = await BookmarkStorageMigration(
          bookmarks: this,
          legacyGroups: await Hive.openBox<BookmarkGroupHiveObject>(
            legacyGroupBoxName,
          ),
          legacyOrganization: await Hive.openBox<dynamic>(
            legacyOrganizationBoxName,
          ),
          metadata: _metadata,
        ).open();
        return _organizationRepository = UnifiedBookmarkGroupRepository(
          bookmarks: this,
          reader: reader,
        );
      });

  Future<void> _sync(Iterable<BoxBase<dynamic>> boxes) async {
    if (_syncOverride case final sync?) return sync(boxes);
    final directories = <String>{};
    for (final box in boxes) {
      await box.flush();
      final path = box.path;
      if (path == null) {
        throw StateError('Bookmark storage has no durable path');
      }
      await fs.syncFile(path);
      directories.add(p.dirname(path));
    }
    for (final directory in directories) {
      await fs.syncDirectory(directory);
    }
  }

  int _localId(Object? value) {
    if (value is! int || value < 0 || value > maxBookmarkId) {
      throw const FormatException('Invalid local Bookmark ID');
    }
    return value;
  }

  int _highestPayloadId() {
    var highest = -1;
    for (final key in [..._posts.keys, ..._groups.keys]) {
      final id = _localId(key);
      if (id > highest) highest = id;
    }
    return highest;
  }

  Future<void> _initialize() async {
    final schema = _metadata.get(_schema);
    if (schema != null) {
      if (schema != 1) {
        throw const FormatException('Unsupported Bookmark repository schema');
      }
      final bound = await _ids.readNextId();
      final floor = _metadata.get(_floor);
      if (bound == null ||
          bound < 0 ||
          bound > maxBookmarkId + 1 ||
          floor is! int ||
          floor < 0 ||
          floor > bound ||
          _metadata.get(_revision) is! int ||
          (_metadata.get(_revision) as int) < 0) {
        throw const FormatException('Invalid Bookmark repository metadata');
      }
      return;
    }
    if (_metadata.containsKey(_journal)) {
      throw const FormatException(
        'Mutation journal has no repository generation',
      );
    }
    final records = performanceRecorder.measureSync(
      PerfOperation.bookmarkDecodeAll,
      () {
        final records = <int, Bookmark>{};
        for (final key in _posts.keys) {
          final id = _localId(key);
          records[id] = _readPost(id);
        }
        for (final key in _groups.keys) {
          final id = _localId(key);
          if (records.containsKey(id)) {
            throw const FormatException('Conflicting Bookmark payload IDs');
          }
          final record = _codec.decode(_groups.get(id));
          if (record is PostBookmark || record.id != id) {
            throw const FormatException('Invalid Group payload slot');
          }
          records[id] = record;
        }
        return records;
      },
    );
    final entries = <String, dynamic>{};
    for (final record in records.values) {
      final header = _header(record);
      entries[_recordKey(record.id)] = header;
      final identity = _identity(header);
      if (identity != null) {
        final key = _contentKey(identity);
        if (entries.containsKey(key)) {
          throw const FormatException('Duplicate saved content identity');
        }
        entries[key] = _contentEntry(record.id, header);
      }
    }
    final floor = _highestPayloadId() + 1;
    final oldBound = await _ids.readNextId();
    if (oldBound != null && (oldBound < 0 || oldBound > maxBookmarkId + 1)) {
      throw const FormatException('Invalid Bookmark reservation bound');
    }
    // All source data is validated before any derived-index mutation.
    await _metadata.deleteAll(
      _metadata.keys
          .whereType<String>()
          .where(
            (key) => key.startsWith('record:') || key.startsWith('content:'),
          )
          .toList(),
    );
    await _ids.writeNextId(
      oldBound != null && oldBound > floor ? oldBound : floor,
    );
    await _metadata.putAll({...entries, _revision: 0, _floor: floor});
    await _sync([_metadata]);
    // The activation marker follows a separate durable index boundary.
    await _metadata.put(_schema, 1);
    await _sync([_metadata]);
  }

  static String _recordKey(int id) => 'record:$id';
  static String _contentKey(ContentIdentity identity) =>
      'content:${sha256.convert(utf8.encode(jsonEncode([identity.siteNamespace, identity.kind.name, identity.sourceKey])))}';
  static Map<String, Object?> _identityWire(ContentIdentity identity) => {
    'siteNamespace': identity.siteNamespace,
    'kind': identity.kind.name,
    'sourceKey': identity.sourceKey,
  };
  static ContentIdentity? _identity(Map<String, Object?> header) {
    if (header['identity'] == null) return null;
    final value = contentMap(header['identity']);
    final kind = ContentKind.values
        .where((kind) => kind.name == value['kind'])
        .firstOrNull;
    final site = contentString(value['siteNamespace']);
    final key = contentString(value['sourceKey']);
    if (kind == null ||
        site.isEmpty ||
        key.isEmpty ||
        normalizePostSourceHost(site) != site) {
      throw const FormatException('Invalid content index identity');
    }
    return (siteNamespace: site, kind: kind, sourceKey: key);
  }

  Map<String, Object?> _header(Bookmark record) {
    final identity = _codec.identityOf(record);
    return {
      'kind': switch (record) {
        PostBookmark() => 'post',
        RelatedBookmark() || LegacyRelatedGroupBookmark() => 'related',
        ContentGroupBookmark() || LegacyGroupBookmark() => 'group',
        _ => throw const FormatException('Unsupported Bookmark record'),
      },
      'engine': _codec.engineOf(record).id,
      if (identity != null) 'identity': _identityWire(identity),
      if (identity == null) 'unresolved': _sourceEvidence(record),
      if (record is ContentGroupBookmark) ...{
        'summaryType': ?record.summary.sourceData?.typeKey,
        'detailsType': ?record.snapshot.details?.sourceData?.typeKey,
      },
    };
  }

  // Opaque records do not enter semantic deduplication. Their known source
  // facts still bind the existing ID, so unknown engine IDs cannot collapse
  // into engine 0 and authorize retargeting a retained record during an update.
  static Map<String, Object?> _sourceEvidence(Bookmark record) =>
      switch (record) {
        PostBookmark() => {
          'kind': 'post',
          'engine': record.snapshot.origin.booruTypeId,
          'site': normalizePostSourceHost(record.snapshot.origin.sourceHost),
          'sourceId': record.snapshot.common['id'],
        },
        LegacyGroupBookmark() => {
          'kind': record.metadata.isRelated ? 'related' : 'pool',
          'engine': record.metadata.sourceTypeId,
          'site': record.metadata.origin.sourceHost,
          'sourceId': record.metadata.referenceId,
        },
        ContentGroupBookmark() => {
          'kind': 'group',
          'engine': record.reference.engine.id,
          'site': record.reference.siteNamespace,
          'sourceKey': record.reference.sourceKey,
        },
        _ => throw const FormatException('Unsupported Bookmark record'),
      };

  Map<String, Object?>? _storedHeader(int id) {
    final raw = _metadata.get(_recordKey(id));
    if (raw == null) return null;
    final header = contentMap(raw);
    if (header['kind'] == 'deleted') return header;
    if (!const {'post', 'group', 'related'}.contains(header['kind']) ||
        header['engine'] is! int ||
        BooruType.fromLegacyId(header['engine']! as int).id !=
            header['engine']) {
      throw const FormatException('Invalid Bookmark kind index');
    }
    _identity(header);
    return header;
  }

  static bool _same(Object? a, Object? b) =>
      const DeepCollectionEquality().equals(a, b);
  static Map<String, Object?> _contentEntry(
    int id,
    Map<String, Object?> header,
  ) => {'id': id, 'engine': header['engine'], 'identity': header['identity']};

  Map<String, Object?>? _content(ContentIdentity identity) {
    final raw = _metadata.get(_contentKey(identity));
    if (raw == null) return null;
    final entry = contentMap(raw);
    if (!_same(entry['identity'], _identityWire(identity))) {
      throw const FormatException('Content index hash collision');
    }
    _localId(entry['id']);
    return entry;
  }

  void _compatible(
    Map<String, Object?> before,
    Map<String, Object?> after,
    Bookmark candidate,
  ) {
    if (before['kind'] != after['kind'] ||
        before['engine'] != after['engine'] ||
        (_identity(before) != null && _identity(before) != _identity(after))) {
      throw const FormatException('Incompatible Bookmark interpretation');
    }
    if (before['unresolved'] != null &&
        !_same(before['unresolved'], _sourceEvidence(candidate))) {
      throw const FormatException('Retained source evidence changed');
    }
    for (final field in ['summaryType', 'detailsType']) {
      if (before[field] != null &&
          after[field] != null &&
          before[field] != after[field]) {
        throw const FormatException('Incompatible Group payload family');
      }
    }
  }

  PostBookmark _readPost(int id) {
    final row = _posts.get(id);
    if (row == null) {
      throw const FormatException('Post kind index has no payload');
    }
    return tryMapBookmarkHiveObjectToBookmark(
      row,
      (_) => const DefaultImageUrlResolver(),
      postDataCodec,
      logger,
    ).fold(
      (error) => throw BookmarkRepositoryReadException(error),
      (record) => record,
    );
  }

  Bookmark? _read(int id) {
    final header = _storedHeader(id);
    if (header == null || header['kind'] == 'deleted') return null;
    final Bookmark record;
    if (header['kind'] == 'post') {
      record = _readPost(id);
    } else {
      final raw = _groups.get(id);
      if (raw is! Map) throw const FormatException('Invalid Group payload');
      record = _decodedGroups[raw] ??= _codec.decode(raw);
    }
    if (record.id != id || !_same(_header(record), header)) {
      throw const FormatException(
        'Bookmark payload disagrees with its kind index',
      );
    }
    return record;
  }

  void _audit() {
    final bound =
        contentMap(_metadata.get(HiveBookmarkIdStore.reservationKey))['nextId']!
            as int;
    for (final id in _posts.keys) {
      if (_storedHeader(_localId(id))?['kind'] != 'post' ||
          _groups.containsKey(id)) {
        throw const FormatException('Unindexed Post payload');
      }
    }
    for (final id in _groups.keys) {
      if (!const {
        'group',
        'related',
      }.contains(_storedHeader(_localId(id))?['kind'])) {
        throw const FormatException('Unindexed Group payload');
      }
    }
    for (final key in _metadata.keys.whereType<String>()) {
      if (key.startsWith('record:')) {
        final id = _localId(int.tryParse(key.substring(7)));
        if (id >= bound) {
          throw const FormatException(
            'Kind index exceeds its reservation bound',
          );
        }
        final header = _storedHeader(id)!;
        final kind = header['kind'];
        if (kind == 'deleted') continue;
        if (kind == 'post'
            ? !_posts.containsKey(id)
            : !_groups.containsKey(id)) {
          throw const FormatException('Bookmark kind index has no payload');
        }
        if (_identity(header) case final identity?) {
          if (!_same(_content(identity), _contentEntry(id, header))) {
            throw const FormatException('Missing Bookmark content index');
          }
        }
      } else if (key.startsWith('content:')) {
        final entry = contentMap(_metadata.get(key));
        final id = _localId(entry['id']);
        final header = _storedHeader(id);
        if (header == null ||
            header['kind'] == 'deleted' ||
            _identity(header) == null ||
            key != _contentKey(_identity(header)!) ||
            !_same(entry, _contentEntry(id, header))) {
          throw const FormatException('Orphaned content index');
        }
      }
    }
  }

  @override
  bool get supportsUnifiedRecords => true;

  @override
  Future<T> runReadWriteScope<T>(Future<T> Function() operation) =>
      _ready(operation);

  @override
  Future<int> readRevision() =>
      _ready(() async => _metadata.get(_revision) as int);

  @override
  Future<Bookmark?> lookupContent(
    ContentIdentity identity, {
    required BooruType engine,
  }) => _ready(() async {
    final entry = _content(identity);
    if (entry == null) return null;
    if (entry['engine'] != engine.id) {
      throw const FormatException('Incompatible content engines');
    }
    return _read(_localId(entry['id']));
  });

  @override
  Future<void> commitOrganization({
    Iterable<Bookmark> records = const [],
    Set<int> removeIds = const {},
    List<BookmarkGroup> groups = const [],
    Set<String> removeGroupIds = const {},
    List<CollectionFolder>? folders,
  }) => _ready(
    () => _mutate(
      records.toList(),
      removeIds.map(_localId).toSet(),
      organizationGroups: groups,
      removedOrganizationGroups: removeGroupIds,
      organizationFolders: folders,
    ),
  );

  @override
  Future<List<int>> reserveIds(int count) =>
      _ready(() => _allocator.reserve(count));
  @override
  Future<List<Bookmark>> readAll() => _ready(() async {
    final ids =
        _metadata.keys
            .whereType<String>()
            .where((key) => key.startsWith('record:'))
            .map((key) => _localId(int.tryParse(key.substring(7))))
            .toList()
          ..sort();
    return performanceRecorder.measureSync(
      PerfOperation.bookmarkDecodeAll,
      () => List<Bookmark>.unmodifiable([
        for (final id in ids) ?_read(id),
      ]),
    );
  });
  @override
  Future<Bookmark?> read(int id) => _ready(() async => _read(_localId(id)));

  /// Legacy Pool/Related presentation reads only Group payloads. The loaded
  /// library remains the common index; no Post snapshots are decoded here.
  Future<List<Bookmark>> readGroupBookmarks() => _ready(
    () async => [
      for (final key in _groups.keys) ?_read(_localId(key)),
    ],
  );

  /// Validate preparation with registered payload codecs before allocating an
  /// ID. This performs no storage write, source lookup or network request.
  @override
  Bookmark normalizeRecord(Bookmark record, {Bookmark? previous}) {
    final normalized = _codec.decode(_codec.encode(record));
    if (previous != null)
      _compatible(_header(previous), _header(normalized), normalized);
    return normalized;
  }

  @override
  Future<void> upsert(Bookmark record) => upsertAll([record]);
  @override
  Future<void> upsertAll(Iterable<Bookmark> records) =>
      _ready(() => _mutate(records.toList(), const {}));
  @override
  Future<void> delete(int id) =>
      _ready(() => _mutate(const [], {_localId(id)}));
  @override
  Future<void> durableSync() => _ready(() async {
    final organization = _metadata.get('activeOrganization') == null
        ? null
        : await _organizationBoxes();
    await _sync([
      _posts,
      _groups,
      _metadata,
      if (organization != null) ...[organization.$1, organization.$2],
    ]);
  });

  Future<void> _mutate(
    List<Bookmark> records,
    Set<int> removeIds, {
    List<BookmarkGroup> organizationGroups = const [],
    Set<String> removedOrganizationGroups = const {},
    List<CollectionFolder>? organizationFolders,
  }) async {
    final deletes = <Map<String, Object?>>[];
    final previous = <String, Object?>{};
    for (final id in removeIds) {
      final header = _storedHeader(id);
      if (header == null || header['kind'] == 'deleted') continue;
      _read(id);
      previous['$id'] = header;
      deletes.add({'id': id, 'kind': header['kind']});
    }
    final deleting = deletes.map((entry) => entry['id']! as int).toSet();
    final upserts = <Map<String, Object?>>[];
    final normalized = <Bookmark>[];
    final headers = <String, Object?>{};
    final identities = <ContentIdentity, int>{};
    final bound = (await _ids.readNextId())!;
    final floor = _metadata.get(_floor) as int;
    for (final original in records) {
      final id = _localId(original.id);
      if (headers.containsKey('$id') || removeIds.contains(id)) {
        throw const FormatException('Duplicate Bookmark mutation ID');
      }
      final wire = _codec.encode(original);
      final record = _codec.decode(wire);
      final header = _header(record);
      final before = _storedHeader(id);
      if (before == null) {
        if (id < floor || id >= bound) {
          throw const FormatException('Bookmark ID was not reserved');
        }
      } else {
        if (before['kind'] == 'deleted') {
          throw const FormatException('Deleted Bookmark IDs cannot be reused');
        }
        _read(id);
        _compatible(before, header, record);
      }
      final identity = _identity(header);
      if (identity != null) {
        final owner = _content(identity);
        if ((identities[identity] != null && identities[identity] != id) ||
            (owner != null &&
                owner['id'] != id &&
                !deleting.contains(owner['id']))) {
          throw const FormatException(
            'Content identity already has another Bookmark',
          );
        }
        if (owner != null && owner['engine'] != header['engine']) {
          throw const FormatException('Incompatible content engines');
        }
        identities[identity] = id;
      }
      previous['$id'] = before;
      headers['$id'] = header;
      upserts.add(wire);
      normalized.add(record);
    }
    final organization = await _prepareOrganization(
      groups: organizationGroups,
      removeGroups: removedOrganizationGroups,
      folders: organizationFolders,
      recordIds: records.map((record) => record.id).toSet(),
      removedRecordIds: deleting,
    );
    if (upserts.isEmpty && deletes.isEmpty && organization == null) return;
    final revision = _metadata.get(_revision) as int;
    final plan = <String, Object?>{
      'upserts': upserts,
      'deletes': deletes,
      'previous': previous,
      'headers': headers,
      'expectedRevision': revision,
      'targetRevision': revision + 1,
      'organization': ?organization,
    };
    final journal = {
      'version': organization == null ? 1 : 2,
      'hash': _hash(plan),
      'plan': plan,
    };
    await _metadata.put(_journal, journal);
    await _sync([_metadata]);
    await _apply(plan);
    publishBookmarkWrite(
      BookmarkCommittedChange(
        records: normalized,
        removedIds: deleting,
        revision: revision + 1,
      ),
    );
  }

  static String _hash(Object value) =>
      sha256.convert(utf8.encode(jsonEncode(value))).toString();
  Future<void> _recover() async {
    try {
      final raw = _metadata.get(_journal);
      if (raw == null) return;
      final journal = contentMap(raw);
      final plan = contentMap(journal['plan']);
      if (!const {1, 2}.contains(journal['version']) ||
          (journal['version'] == 2) != plan.containsKey('organization') ||
          journal['hash'] != _hash(plan)) {
        throw const FormatException('Invalid Bookmark mutation journal');
      }
      await _apply(plan);
      // Local journal maps are also an untrusted structural boundary.
      // ignore: avoid_catching_errors
    } on TypeError {
      throw const FormatException('Invalid Bookmark journal field');
      // ignore: avoid_catching_errors
    } on ArgumentError {
      throw const FormatException('Invalid Bookmark journal field');
    }
  }

  Future<void> _apply(Map<String, Object?> plan) async {
    final expected = plan['expectedRevision'];
    final target = plan['targetRevision'];
    final current = _metadata.get(_revision);
    if (expected is! int ||
        target != expected + 1 ||
        (current != expected && current != target)) {
      throw const FormatException('Stale Bookmark mutation journal');
    }
    final previous = contentMap(plan['previous']);
    final headers = contentMap(plan['headers']);
    final records = (plan['upserts']! as List)
        .map((value) => _codec.decode(value))
        .toList();
    final deletes = (plan['deletes']! as List).map(contentMap).toList();
    final bound = await _ids.readNextId();
    final floor = _metadata.get(_floor);
    if (bound == null ||
        bound < 0 ||
        bound > maxBookmarkId + 1 ||
        floor is! int ||
        floor < 0 ||
        floor > bound) {
      throw const FormatException('Invalid journal reservation bound');
    }
    final deleting = deletes.map((entry) => _localId(entry['id'])).toSet();
    final desiredIdentities = <ContentIdentity, int>{};
    final seen = <int>{};
    final postWrites = <int, BookmarkHiveObject>{};
    final groupWrites = <int, dynamic>{};
    final postDeletes = <int>[];
    final groupDeletes = <int>[];
    final indexWrites = <String, dynamic>{};
    final oldContentKeys = <String>{};
    void check(int id, Map<String, Object?> desired) {
      final old = previous['$id'];
      final actual = _storedHeader(id);
      if (!previous.containsKey('$id') ||
          (!_same(actual, old) && !_same(actual, desired))) {
        throw const FormatException('Mutation index changed after preparation');
      }
      if (old != null) {
        if (_identity(contentMap(old)) case final identity?) {
          oldContentKeys.add(_contentKey(identity));
        }
      }
      indexWrites[_recordKey(id)] = desired;
    }

    for (final record in records) {
      final id = _localId(record.id);
      if (!seen.add(id)) throw const FormatException('Duplicate journal ID');
      final header = _header(record);
      if (!_same(headers['$id'], header)) {
        throw const FormatException('Journal payload/header mismatch');
      }
      check(id, header);
      final old = previous['$id'];
      if (old == null) {
        if (id < floor || id >= bound) {
          throw const FormatException('Journal ID was not reserved');
        }
      } else {
        final before = contentMap(old);
        if (before['kind'] == 'deleted') {
          throw const FormatException('Journal reused a deleted ID');
        }
        _compatible(before, header, record);
      }
      if (_identity(header) case final identity?) {
        final owner = _content(identity);
        if ((desiredIdentities[identity] != null &&
                desiredIdentities[identity] != id) ||
            (owner != null &&
                owner['id'] != id &&
                !deleting.contains(owner['id'])) ||
            (owner != null && owner['engine'] != header['engine'])) {
          throw const FormatException('Conflicting journal content identity');
        }
        desiredIdentities[identity] = id;
      }
      if (record is PostBookmark) {
        postWrites[id] = favoriteToHiveObject(
          record,
          requireStableIdentity: false,
        );
      } else {
        groupWrites[id] = _codec.encode(record);
      }
      if (_identity(header) case final identity?) {
        indexWrites[_contentKey(identity)] = _contentEntry(id, header);
      }
    }
    for (final item in deletes) {
      final id = _localId(item['id']);
      if (!seen.add(id) ||
          !const {'post', 'group', 'related'}.contains(item['kind'])) {
        throw const FormatException('Invalid journal deletion');
      }
      check(id, const {'kind': 'deleted'});
      final before = previous['$id'];
      if (before == null || contentMap(before)['kind'] != item['kind']) {
        throw const FormatException(
          'Journal deletion kind disagrees with its index',
        );
      }
      if (item['kind'] == 'post') {
        postDeletes.add(id);
      } else {
        groupDeletes.add(id);
      }
    }
    if (previous.length != seen.length || headers.length != records.length) {
      throw const FormatException('Incomplete mutation journal');
    }
    // Everything is decoded and bound to its intended index before any write.
    final organization = plan.containsKey('organization')
        ? contentMap(plan['organization'])
        : null;
    if (organization != null) {
      await _validateOrganization(
        organization,
        records.map((record) => record.id).toSet(),
        deletes.map((entry) => _localId(entry['id'])).toSet(),
      );
    }
    if (postWrites.isNotEmpty) await _posts.putAll(postWrites);
    if (groupWrites.isNotEmpty) await _groups.putAll(groupWrites);
    if (postDeletes.isNotEmpty) await _posts.deleteAll(postDeletes);
    if (groupDeletes.isNotEmpty) await _groups.deleteAll(groupDeletes);
    final organizationBoxes = organization == null
        ? <BoxBase<dynamic>>[]
        : await _applyOrganization(organization);
    await _sync([
      if (postWrites.isNotEmpty || postDeletes.isNotEmpty) _posts,
      if (groupWrites.isNotEmpty || groupDeletes.isNotEmpty) _groups,
      ...organizationBoxes,
    ]);
    await _metadata.deleteAll(oldContentKeys);
    await _metadata.putAll({...indexWrites, _revision: target});
    await _sync([_metadata]);
    await _metadata.delete(_journal);
    await _sync([_metadata]);
  }

  Future<List<PostBookmark>> _createPosts(List<PostBookmark> inputs) => _ready(
    () async {
      // File IDs never select local payload slots. Known compatible identities are
      // reused; unaddressable legacy snapshots have no speculative dedup key.
      final output = <PostBookmark?>[];
      final missing = <PostBookmark>[];
      final pending = <ContentIdentity, int>{};
      final positions = <int>[];
      for (final input in inputs) {
        final normalized =
            _codec.decode(_codec.encode(input.copyWith(id: 0))) as PostBookmark;
        final identity = _codec.identityOf(normalized);
        final owner = identity == null ? null : _content(identity);
        if (owner != null) {
          final old = _read(owner['id']! as int);
          if (old is! PostBookmark ||
              _codec.engineOf(old) != _codec.engineOf(normalized)) {
            throw const FormatException('Incompatible imported Post identity');
          }
          output.add(old);
          positions.add(-1);
        } else {
          final index = identity == null ? null : pending[identity];
          if (index != null &&
              _codec.engineOf(missing[index]) != _codec.engineOf(normalized)) {
            throw const FormatException('Incompatible Posts in one batch');
          }
          positions.add(index ?? missing.length);
          output.add(null);
          if (index == null) {
            if (identity != null) pending[identity] = missing.length;
            missing.add(normalized);
          }
        }
      }
      final ids = await _allocator.reserve(missing.length);
      final created = [
        for (final (index, record) in missing.indexed)
          record.copyWith(id: ids[index]),
      ];
      await _mutate(created, const {});
      return [
        for (final (index, record) in output.indexed)
          record ?? created[positions[index]],
      ];
    },
  );

  @override
  Future<PostBookmark> addBookmark(
    int booruId,
    Post post, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator<Post> Function(int? booruId) postLinkGenerator,
  }) async => (await addBookmarks(
    booruId,
    [post],
    imageUrlResolver: imageUrlResolver,
    postLinkGenerator: postLinkGenerator,
  )).single;

  @override
  Future<List<PostBookmark>> addBookmarks(
    int booruId,
    Iterable<Post> posts, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator<Post> Function(int? booruId) postLinkGenerator,
  }) {
    final input = posts.toList();
    for (final post in input) {
      BookmarkIdentity.fromPost(post);
    }
    final now = DateTime.now();
    return _createPosts([
      for (final post in input)
        PostBookmark.fromSnapshot(
          id: 0,
          createdAt: now,
          updatedAt: now,
          snapshot: const StoredPostCodec().encode(
            post,
            dataCodec: postDataCodec?.call(post.origin.booruType),
          ),
          post: post,
          postId: post.id,
          sourceUrl: postLinkGenerator(booruId).getLink(post),
        ),
    ]);
  }

  @override
  Future<List<PostBookmark>> addBookmarkWithBookmarks(
    List<PostBookmark> bookmarks,
  ) => _createPosts(bookmarks);
  @override
  Future<void> updateBookmark(PostBookmark bookmark) => upsert(bookmark);
  @override
  Future<void> removeBookmark(PostBookmark bookmark) => delete(bookmark.id);
  @override
  Future<void> removeBookmarks(Iterable<PostBookmark> bookmarks) => _ready(
    () => _mutate(
      const [],
      bookmarks.map((record) => _localId(record.id)).toSet(),
    ),
  );
  @override
  BookmarksOrError getAllBookmarks({
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  }) => TaskEither.tryCatch(
    () => _ready(
      () async => performanceRecorder.measureSync(
        PerfOperation.bookmarkDecodeAll,
        () => List<PostBookmark>.unmodifiable([
          for (final id in _posts.keys.map(_localId))
            if (_read(id) case final PostBookmark record) record,
        ]),
      ),
    ),
    (_, _) => _posts.isOpen
        ? BookmarkGetError.nullField
        : BookmarkGetError.databaseClosed,
  );

  Future<void> close() async {
    await _posts.close();
    await _groups.close();
    await _metadata.close();
  }
}
