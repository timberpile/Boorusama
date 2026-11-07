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

  Future<BookmarkGroupRepositoryHive> open() =>
      bookmarks.coordinator.runExclusive(() async {
        // Replay the payload journal first, including a previous interrupted
        // migration payload batch, before validating its organization plan.
        await bookmarks.reserveIds(0);
        final active = metadata.get(activeKey);
        if (active != null) {
          return _openActive(contentMap(active));
        }
        var raw = metadata.get(pendingKey);
        if (raw == null) {
          final source = await _source();
          final plan = await _prepare(source);
          raw = {'version': 1, 'hash': _hash(plan), 'plan': plan};
          await metadata.put(pendingKey, raw);
          await _sync([metadata], 'plan');
        }
        final envelope = contentMap(raw);
        final plan = contentMap(envelope['plan']);
        final source = await _source();
        if (envelope['version'] != 1 ||
            envelope['hash'] != _hash(plan) ||
            plan['sourceRevision'] != _hash(source)) {
          throw const FormatException('Bookmark migration source changed');
        }
        final records = _list(plan['records']).map(_codec.decode).toList();
        final targetGroups = _list(plan['groups']).map(_decodeGroup).toList();
        final folders = _list(plan['folders'])
            .map((raw) => CollectionFolder.fromJson(contentMap(raw)))
            .toList();
        final mapping = contentMap(plan['mapping']);
        if (mapping.values.any((id) => id is! int)) {
          throw const FormatException('Invalid migration ID mapping');
        }
        // Reconstruct the intended generation from unchanged source evidence
        // and the already reserved mapping. This validates every snapshot,
        // membership and date without allocating new IDs during recovery.
        final expectedPlan = await _prepare(
          source,
          reservedMapping: {
            for (final entry in mapping.entries) entry.key: entry.value! as int,
          },
        );
        if (_hash(plan) != _hash(expectedPlan)) {
          throw const FormatException('Migration plan differs from its source');
        }
        if (mapping.length != records.length ||
            mapping.values.toSet().length != records.length ||
            records.any((record) => !mapping.values.contains(record.id))) {
          throw const FormatException('Invalid Bookmark migration mapping');
        }
        _validate(targetGroups, folders, {
          ..._list(plan['postIds']).cast<int>(),
          for (final record in records) record.id,
        });
        final names = contentMap(plan['generation']);
        if (names['groups'] != '${legacyGroups.name}_unified_v2' ||
            names['organization'] != '${legacyOrganization.name}_unified_v2' ||
            records.any((record) => record is! LegacyGroupBookmark) ||
            mapping.keys.any((id) => !Uuid.isValidUUID(fromString: id))) {
          throw const FormatException('Invalid Bookmark migration generation');
        }
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
          for (final group in targetGroups) group.id: _groupRow(group),
        });
        await organization.putAll({
          'version': 1,
          'folders': folders.map((folder) => folder.toJson()).toList(),
          'recentManualGroupIds': plan['recentManualGroupIds'],
        });
        await _sync([groupBox, organization], 'organization');
        final staged = BookmarkGroupRepositoryHive(
          groupBox,
          organizationBox: organization,
        );
        final stagedGroups = await staged.getGroups();
        if (_hash(stagedGroups.map(_encodeGroup).toList()) !=
            _hash(
              (targetGroups..sort(_groupOrder)).map(_encodeGroup).toList(),
            )) {
          throw const FormatException('Staged Bookmark organization differs');
        }
        for (final record in records) {
          if (_hash(_codec.encode((await bookmarks.read(record.id))!)) !=
              _hash(_codec.encode(record))) {
            throw const FormatException('Staged Group snapshot differs');
          }
        }
        if (plan['sourceRevision'] != _hash(await _source())) {
          throw const FormatException('Bookmark migration source changed');
        }
        await bookmarks.durableSync();
        final activation = {
          'version': 2,
          'generation': names,
          'mapping': mapping,
          'sourceRevision': plan['sourceRevision'],
        };
        await metadata.put(activeKey, activation);
        await _sync([metadata], 'activation');
        await metadata.delete(pendingKey);
        await _sync([metadata], 'cleanup');
        return _openActive(activation);
      });

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
    return {
      'sourceRevision': sourceRevision,
      'postIds': byId.keys.toList()..sort(),
      'records': records.map(_codec.encode).toList(),
      'groups': byGroup.values.map(_encodeGroup).toList(),
      'folders': folders.map((folder) => folder.toJson()).toList(),
      'mapping': mapping,
      'generation': {
        'groups': '${legacyGroups.name}_unified_v2',
        'organization': '${legacyOrganization.name}_unified_v2',
      },
      'recentManualGroupIds':
          legacyOrganization.get('recentManualGroupIds') ?? const [],
    };
  }

  Future<BookmarkGroupRepositoryHive> _openActive(
    Map<String, Object?> active,
  ) async {
    if (active['version'] != 2) {
      throw const FormatException('Unsupported Bookmark organization schema');
    }
    final names = contentMap(active['generation']);
    final expectedGroups = '${legacyGroups.name}_unified_v2';
    final expectedOrganization = '${legacyOrganization.name}_unified_v2';
    if (names['groups'] != expectedGroups ||
        names['organization'] != expectedOrganization ||
        !await Hive.boxExists(expectedGroups) ||
        !await Hive.boxExists(expectedOrganization)) {
      throw const FormatException('Active Bookmark generation is missing');
    }
    final repository = BookmarkGroupRepositoryHive(
      await Hive.openBox<BookmarkGroupHiveObject>(expectedGroups),
      organizationBox: await Hive.openBox<dynamic>(expectedOrganization),
    );
    _validate(
      await repository.getGroups(),
      await repository.readFolders(),
      (await bookmarks.readAll()).map((record) => record.id).toSet(),
    );
    if (metadata.containsKey(pendingKey)) {
      await metadata.delete(pendingKey);
      await _sync([metadata], 'cleanup');
    }
    return repository;
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
        position: group.position,
      );
}
