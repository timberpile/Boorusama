import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../content/content_map.dart';
import '../../../groups/folder_tree.dart';
import '../../../posts/post/types.dart';
import '../data/hive/bookmark_group_hive_object.dart';
import '../data/hive/bookmark_group_repository_hive.dart';
import '../data/hive/unified_bookmark_repository.dart';
import '../data/stored_bookmark_codec.dart';
import '../types/bookmark.dart';
import '../types/bookmark_repository.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_group_tree.dart';
import 'bookmark_hierarchy_conversion.dart';
import '../types/legacy_group_bookmark.dart';
import '../types/pool_bookmark.dart';

/// Stages a complete organization generation while retaining the old files.
/// The single durable activation frame is the only authority switch. A pending
/// plan is replayed before a writable organization can be returned to callers.
final class BookmarkStorageMigration {
  BookmarkStorageMigration({
    required this.bookmarks,
    required this.legacyGroups,
    required this.legacyOrganization,
    required this.metadata,
    this.afterDurableBoundary,
  });

  final BookmarkHiveRepository bookmarks;
  final Box<BookmarkGroupHiveObject> legacyGroups;
  final Box<dynamic> legacyOrganization;
  final Box<dynamic> metadata;
  final Future<void> Function(String boundary)? afterDurableBoundary;
  static const schemaVersion = 2;
  static const generationSuffix = '_hierarchy_v2';
  static const activeKey = 'activeOrganization';
  static const pendingKey = 'organizationMigration';
  static const _codec = StoredBookmarkCodec();

  Future<void> _sync(Iterable<BoxBase<dynamic>> boxes, String phase) async {
    final directories = <String>{};
    for (final box in boxes) {
      await box.flush();
      final path = box.path;
      if (path == null) throw StateError('Migration requires durable storage');
      await bookmarks.fs.syncFile(path);
      directories.add(p.dirname(path));
    }
    for (final directory in directories) {
      await bookmarks.fs.syncDirectory(directory);
    }
    await afterDurableBoundary?.call(phase);
  }

  static List<Object?> _list(Object? value) {
    if (value is! List) throw const FormatException('Invalid migration list');
    return List<Object?>.from(value);
  }

  static String _hash(Object? value) => sha256
      .convert(
        utf8.encode(jsonEncode(_canonical(value))),
      )
      .toString();

  static Object? _canonical(Object? value) => switch (value) {
    final Map map => {
      for (final key in map.keys.map((key) => key.toString()).toList()..sort())
        key: _canonical(map[key] ?? map[int.tryParse(key)]),
    },
    final List list => list.map(_canonical).toList(),
    final DateTime date => date.toUtc().toIso8601String(),
    _ => value,
  };

  Future<Map<String, Object?>> _source() async => {
    'posts': [
      for (final record in await bookmarks.getAllBookmarksOrThrow(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      ))
        _codec.encode(record),
    ],
    'groups': [
      for (final row in legacyGroups.values)
        {
          'storageKey': row.key,
          'id': row.id,
          'name': row.name,
          'bookmarkIds': row.bookmarkIds,
          'addedAt': row.addedAt?.map((key, value) => MapEntry('$key', value)),
          'folderId': row.folderId,
          'position': row.position,
        },
    ],
    'organization': legacyOrganization.toMap(),
  };

  Map<String, Object?> get _generation => {
    'groups': '${legacyGroups.name}$generationSuffix',
    'organization': '${legacyOrganization.name}$generationSuffix',
  };

  Future<BookmarkGroupRepositoryHive> open() =>
      bookmarks.runStorageMigration(() async {
        final active = metadata.get(activeKey);
        if (active != null) return _openHierarchy(contentMap(active));
        var raw = metadata.get(pendingKey);
        if (raw != null && contentMap(raw)['version'] != schemaVersion) {
          throw const FormatException('Unsupported pending Bookmark migration');
        }
        if (raw == null) {
          final plan = await _prepare(await _source());
          raw = {'version': schemaVersion, 'hash': _hash(plan), 'plan': plan};
          await metadata.put(pendingKey, raw);
          await _sync([metadata], 'plan');
        }
        final (plan, records) = await _validatePending(raw);
        final groups = _list(plan['groups'])
            .map(_decodeHierarchyGroup)
            .toList();
        final names = _generation;
        final groupBox = await Hive.openBox<BookmarkGroupHiveObject>(
          contentString(names['groups']),
        );
        final organization = await Hive.openBox<dynamic>(
          contentString(names['organization']),
        );
        await bookmarks.upsertAll(records);
        await afterDurableBoundary?.call('payloads');
        await groupBox.clear();
        await groupBox.putAll({
          for (final group in groups) group.id: _groupRow(group),
        });
        await organization.clear();
        await organization.putAll({
          'version': schemaVersion,
          'legacyFolderGroupIds': plan['folderIdMapping'],
          'recentManualGroupIds': plan['recentManualGroupIds'],
        });
        await _sync([groupBox, organization], 'organization');

        final staged = BookmarkGroupRepositoryHive(
          groupBox,
          organizationBox: organization,
        );
        await _validateStaged(staged, organization, plan, records);
        if (plan['sourceRevision'] != _hash(await _source())) {
          throw const FormatException('Bookmark migration source changed');
        }
        await bookmarks.durableSync();
        final activation = {
          'version': schemaVersion,
          'generation': names,
          'mapping': plan['mapping'],
          'hierarchyPlanHash': _hash(plan),
        };
        await metadata.put(activeKey, activation);
        await _sync([metadata], 'activation');
        await metadata.delete(pendingKey);
        await _sync([metadata], 'cleanup');
        return staged;
      });

  Future<(Map<String, Object?>, List<Bookmark>)> _validatePending(
    Object? raw,
  ) async {
    final envelope = contentMap(raw);
    final plan = contentMap(envelope['plan']);
    final source = await _source();
    if (envelope['version'] != schemaVersion ||
        envelope['hash'] != _hash(plan) ||
        plan['sourceRevision'] != _hash(source)) {
      throw const FormatException('Bookmark migration source or plan changed');
    }
    final mapping = contentMap(plan['mapping']);
    if (mapping.values.any((id) => id is! int)) {
      throw const FormatException('Invalid migration ID mapping');
    }
    // Reconstruct the final generation from the unchanged released source
    // and the existing reservation, without allocating again on recovery.
    final expected = await _prepare(
      source,
      reservedMapping: mapping.map(
        (key, value) => MapEntry(key, value! as int),
      ),
    );
    if (_hash(plan) != _hash(expected)) {
      throw const FormatException('Migration plan differs from its source');
    }
    return (plan, _list(plan['records']).map(_codec.decode).toList());
  }

  Future<void> _validateStaged(
    BookmarkGroupRepositoryHive reader,
    Box<dynamic> organization,
    Map<String, Object?> plan,
    List<Bookmark> records,
  ) async {
    final groups = await reader.getGroups();
    final plannedGroups = _list(plan['groups'])
        .map(_decodeHierarchyGroup)
        .toList();
    if (_hash(
              (groups..sort(_groupOrder)).map(_encodeHierarchyGroup).toList(),
            ) !=
            _hash(
              (plannedGroups..sort(_groupOrder))
                  .map(_encodeHierarchyGroup)
                  .toList(),
            ) ||
        _hash(await reader.readLegacyFolderGroupIds()) !=
            _hash(plan['folderIdMapping']) ||
        _hash(organization.get('recentManualGroupIds')) !=
            _hash(plan['recentManualGroupIds'])) {
      throw const FormatException(
        'Staged Bookmark organization differs from plan',
      );
    }
    for (final record in records) {
      final stored = await bookmarks.read(record.id);
      if (stored == null ||
          _hash(_codec.encode(stored)) != _hash(_codec.encode(record))) {
        throw const FormatException('Staged Group snapshot differs from plan');
      }
    }
  }

  Future<Map<String, Object?>> _prepare(
    Map<String, Object?> source, {
    Map<String, int>? reservedMapping,
  }) async {
    final sourceRevision = _hash(source);
    final version = legacyOrganization.get('version');
    if (version != null && version != 1) {
      throw const FormatException('Unsupported legacy organization schema');
    }
    final posts = _list(source['posts'])
        .map(_codec.decode)
        .cast<PostBookmark>()
        .toList();
    final byId = {for (final record in posts) record.id: record};
    final groups = _list(source['groups']).map(_decodeGroup).toList();
    final folders = (legacyOrganization.get('folders') as List? ?? const [])
        .map((raw) => CollectionFolder.fromJson(contentMap(raw)))
        .toList();
    final byGroup = {for (final group in groups) group.id: group};
    if (byGroup.length != groups.length) {
      throw const FormatException('Duplicate legacy Bookmark Group');
    }
    byGroup.putIfAbsent(
      defaultBookmarkGroupId,
      () => BookmarkGroup(
        id: defaultBookmarkGroupId,
        name: 'Default',
        bookmarkIds: const {},
        position: groups.fold(
          0,
          (next, group) => group.position >= next ? group.position + 1 : next,
        ),
      ),
    );
    final rawPools =
        legacyOrganization.get('poolBookmarks') as List? ?? const [];
    final pools = rawPools
        .map((raw) => CollectionBookmark.fromJson(contentMap(raw)))
        .toList();
    final localIds = <String>{};
    final identities = <Object>{};
    final contentIdentities = <Object>{};
    for (final pool in pools) {
      if (!Uuid.isValidUUID(fromString: pool.localId) ||
          !localIds.add(pool.localId) ||
          !identities.add(pool.identity) ||
          pool.groupIds.any((id) => !Uuid.isValidUUID(fromString: id))) {
        throw const FormatException('Invalid legacy Collection identity');
      }
      final identity = LegacyGroupBookmark.fromMetadata(
        id: 0,
        metadata: pool,
      ).identity;
      if (identity != null && !contentIdentities.add(identity)) {
        throw const FormatException('Conflicting legacy Group interpretations');
      }
    }
    // Validate every old membership before reserving or staging any Group.
    for (final group in byGroup.values.toList()) {
      if (!byId.keys.toSet().containsAll(group.bookmarkIds)) {
        throw const FormatException('Legacy Group references an absent Post');
      }
      byGroup[group.id] = group.copyWith(
        addedAt: {
          for (final id in group.bookmarkIds)
            id: group.addedAt[id] ?? byId[id]!.createdAt,
        },
      );
    }
    final assigned = {for (final group in byGroup.values) ...group.bookmarkIds};
    final defaultGroup = byGroup[defaultBookmarkGroupId]!;
    final ungrouped = byId.keys.toSet().difference(assigned);
    byGroup[defaultBookmarkGroupId] = defaultGroup.copyWith(
      bookmarkIds: {...defaultGroup.bookmarkIds, ...ungrouped},
      addedAt: {
        ...defaultGroup.addedAt,
        for (final id in ungrouped) id: byId[id]!.createdAt,
      },
    );
    _validate(byGroup.values.toList(), folders, byId.keys.toSet());
    if (reservedMapping != null &&
        (!const SetEquality<String>().equals(
              localIds,
              reservedMapping.keys.toSet(),
            ) ||
            reservedMapping.values.toSet().length != pools.length)) {
      throw const FormatException(
        'Migration mapping differs from legacy Collections',
      );
    }
    final ids = reservedMapping == null
        ? await bookmarks.reserveIds(pools.length)
        : [for (final pool in pools) reservedMapping[pool.localId]!];
    if (reservedMapping == null) {
      await afterDurableBoundary?.call('reservation');
    }
    final records = <Bookmark>[];
    final mapping = <String, int>{};
    for (final (index, pool) in pools.indexed) {
      final id = ids[index];
      mapping[pool.localId] = id;
      records.add(LegacyGroupBookmark.fromMetadata(id: id, metadata: pool));
      final memberships = pool.groupIds.intersection(byGroup.keys.toSet());
      if (memberships.isEmpty) memberships.add(defaultBookmarkGroupId);
      for (final groupId in memberships) {
        final group = byGroup[groupId]!;
        byGroup[groupId] = group.copyWith(
          bookmarkIds: {...group.bookmarkIds, id},
          addedAt: {
            ...group.addedAt,
            id: pool.addedAt[groupId] ?? pool.createdAt,
          },
        );
      }
    }
    final hierarchy = BookmarkHierarchyConversion.convert(
      groups: byGroup.values.toList(),
      folders: folders,
    );
    return {
      'sourceRevision': sourceRevision,
      'records': records.map(_codec.encode).toList(),
      'groups': hierarchy.groups.map(_encodeHierarchyGroup).toList(),
      'folderIdMapping': hierarchy.folderIdMapping,
      'mapping': mapping,
      'generation': _generation,
      'recentManualGroupIds':
          legacyOrganization.get('recentManualGroupIds') ?? const [],
    };
  }

  static Map<String, Object?> _encodeHierarchyGroup(BookmarkGroup group) => {
    ..._encodeGroup(group)..remove('folderId'),
    'parentGroupId': group.parentGroupId,
  };

  static BookmarkGroup _decodeHierarchyGroup(Object? value) {
    final map = contentMap(value);
    if (map.containsKey('folderId') ||
        (map['parentGroupId'] != null && map['parentGroupId'] is! String)) {
      throw const FormatException('Invalid hierarchy Group');
    }
    final legacy = _decodeGroup({...map, 'folderId': null});
    return legacy.copyWith(parentGroupId: map['parentGroupId'] as String?);
  }

  Future<BookmarkGroupRepositoryHive> _openHierarchy(
    Map<String, Object?> active,
  ) async {
    if (active['version'] != schemaVersion ||
        active['hierarchyPlanHash'] is! String) {
      throw const FormatException('Unsupported Bookmark organization schema');
    }
    final names = contentMap(active['generation']);
    final groupName = '${legacyGroups.name}$generationSuffix';
    final organizationName = '${legacyOrganization.name}$generationSuffix';
    if (names['groups'] != groupName ||
        names['organization'] != organizationName ||
        !await Hive.boxExists(groupName) ||
        !await Hive.boxExists(organizationName)) {
      throw const FormatException('Active hierarchy generation is missing');
    }
    final groupBox = await Hive.openBox<BookmarkGroupHiveObject>(groupName);
    final organization = await Hive.openBox<dynamic>(organizationName);
    if (organization.get('version') != schemaVersion ||
        organization.get('legacyFolderGroupIds') is! Map ||
        organization.containsKey('folders') ||
        groupBox.values.any((row) => row.folderId != null)) {
      throw const FormatException('Mixed active hierarchy generation');
    }
    // Recover any partial mutation before observing the active membership rows.
    await bookmarks.reserveIds(0);
    final reader = BookmarkGroupRepositoryHive(
      groupBox,
      organizationBox: organization,
    );
    final groups = await reader.getGroups();
    BookmarkGroupTree(groups);
    final ids = (await bookmarks.readAll()).map((record) => record.id).toSet();
    if (groups.any(
      (group) =>
          !ids.containsAll(group.bookmarkIds) ||
          !const SetEquality<int>().equals(
            group.bookmarkIds,
            group.addedAt.keys.toSet(),
          ) ||
          (group.isDefault && group.name != 'Default'),
    )) {
      throw const FormatException('Invalid hierarchy membership authority');
    }
    if (metadata.containsKey(pendingKey)) {
      final (plan, records) = await _validatePending(metadata.get(pendingKey));
      if (active['hierarchyPlanHash'] != _hash(plan)) {
        throw const FormatException(
          'Activated hierarchy differs from pending plan',
        );
      }
      await _validateStaged(reader, organization, plan, records);
      await metadata.delete(pendingKey);
      await _sync([metadata], 'cleanup');
    }
    return reader;
  }

  static int _groupOrder(BookmarkGroup a, BookmarkGroup b) =>
      a.position != b.position
      ? a.position.compareTo(b.position)
      : a.id.compareTo(b.id);

  static void _validate(
    List<BookmarkGroup> groups,
    List<CollectionFolder> folders,
    Set<int> ids,
  ) {
    FolderTree(folders).validatePlacements(
      groups.map(
        (group) => FolderPlacement(
          itemId: group.id,
          folderId: group.folderId,
          position: group.position,
        ),
      ),
    );
    if (groups.map((group) => group.id).toSet().length != groups.length ||
        groups.any(
          (group) =>
              !ids.containsAll(group.bookmarkIds) ||
              !const SetEquality<int>().equals(
                group.bookmarkIds,
                group.addedAt.keys.toSet(),
              ) ||
              (group.isDefault &&
                  (group.name != 'Default' || group.folderId != null)),
        )) {
      throw const FormatException('Invalid unified Bookmark organization');
    }
  }

  static Map<String, Object?> _encodeGroup(BookmarkGroup group) => {
    'id': group.id,
    'name': group.name,
    'bookmarkIds': group.bookmarkIds.toList()..sort(),
    'addedAt': {
      for (final entry in group.addedAt.entries)
        '${entry.key}': entry.value.toUtc().toIso8601String(),
    },
    'folderId': group.folderId,
    'position': group.position,
  };

  static BookmarkGroup _decodeGroup(Object? value) {
    final map = contentMap(value);
    final id = contentString(map['id']);
    final name = contentString(map['name']);
    if (map.containsKey('storageKey') && map['storageKey'] != id) {
      throw const FormatException('Legacy Group key disagrees with its UUID');
    }
    final ids = _list(map['bookmarkIds']).cast<int>().toSet();
    if (!Uuid.isValidUUID(fromString: id) ||
        name.isEmpty ||
        name != name.trim()) {
      throw const FormatException('Invalid legacy Bookmark Group');
    }
    final dates = map['addedAt'] == null
        ? <String, Object?>{}
        : contentMap(map['addedAt']);
    final parsed = <int, DateTime>{};
    for (final entry in dates.entries) {
      final key = int.tryParse(entry.key);
      final date = entry.value is DateTime
          ? entry.value! as DateTime
          : DateTime.parse(contentString(entry.value));
      if (key == null || !ids.contains(key)) {
        throw const FormatException('Invalid membership date reference');
      }
      parsed[key] = date.toUtc();
    }
    return BookmarkGroup(
      id: id,
      name: name,
      bookmarkIds: ids,
      addedAt: parsed,
      folderId: map['folderId'] as String?,
      position: map['position']! as int,
    );
  }

  static BookmarkGroupHiveObject _groupRow(BookmarkGroup group) =>
      BookmarkGroupHiveObject(
        id: group.id,
        name: group.name,
        bookmarkIds: group.bookmarkIds.toList()..sort(),
        addedAt: {
          for (final entry in group.addedAt.entries)
            entry.key: entry.value.toUtc().toIso8601String(),
        },
        folderId: group.folderId,
        parentGroupId: group.parentGroupId,
        position: group.position,
      );
}
