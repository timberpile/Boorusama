// Package imports:
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

// Project imports:
import '../../types/bookmark_group.dart';
import '../../types/pool_bookmark.dart';
import '../../types/pool_bookmark_repository.dart';
import '../../../../groups/folder_tree.dart';
import '../../types/bookmark_group_repository.dart';
import 'bookmark_group_hive_object.dart';

class BookmarkGroupRepositoryHive
    implements
        BookmarkGroupRepository,
        BookmarkFolderRepository,
        BookmarkRecentGroupRepository,
        PoolBookmarkRepository {
  BookmarkGroupRepositoryHive(
    this._box, {
    Uuid uuid = const Uuid(),
    Box<dynamic>? organizationBox,
  }) : _uuid = uuid,
       _organizationBox = organizationBox;

  final Box<BookmarkGroupHiveObject> _box;
  final Uuid _uuid;
  final Box<dynamic>? _organizationBox;
  Object? _cachedPoolRows;
  List<PoolBookmark> _cachedPools = const [];

  @override
  Future<List<PoolBookmark>> readPoolBookmarks() async {
    final raw = _organizationBox?.get('poolBookmarks') ?? const [];
    if (identical(raw, _cachedPoolRows)) return _cachedPools;
    final parsed = List<PoolBookmark>.unmodifiable([
      for (final row in raw as List)
        PoolBookmark.fromJson(Map<String, dynamic>.from(row as Map)),
    ]);
    _cachedPoolRows = raw;
    return _cachedPools = parsed;
  }

  @override
  Future<void> writePoolBookmarks(List<PoolBookmark> bookmarks) async {
    final storage = _organizationBox;
    if (storage == null) {
      if (bookmarks.isEmpty) return;
      throw StateError('Pool bookmark storage unavailable');
    }
    final identities = <Object>{};
    final localIds = <String>{};
    final groups = (await getGroups()).map((g) => g.id).toSet();
    for (final bookmark in bookmarks) {
      if (!Uuid.isValidUUID(fromString: bookmark.localId) ||
          !identities.add(bookmark.identity) ||
          !localIds.add(bookmark.localId) ||
          bookmark.groupIds.isEmpty ||
          !groups.containsAll(bookmark.groupIds)) {
        throw const FormatException('Invalid Pool bookmark memberships');
      }
    }
    await storage.put(
      'poolBookmarks',
      bookmarks.map((b) => b.toJson()).toList(),
    );
  }

  @override
  Future<List<String>> readRecentGroupIds() async {
    final raw = _organizationBox?.get('recentManualGroupIds');
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .where(_box.containsKey)
        .toSet()
        .take(3)
        .toList();
  }

  @override
  Future<void> recordManualGroupInteraction(String groupId) async {
    final id = _normalizeId(groupId);
    if (!_box.containsKey(id)) return;
    final previous = await readRecentGroupIds();
    await _organizationBox?.put('recentManualGroupIds', [
      id,
      ...previous.where((value) => value != id).take(2),
    ]);
  }

  Future<void> close() async {
    await _box.close();
    await _organizationBox?.close();
  }

  @override
  Future<List<BookmarkGroup>> getGroups() async {
    final groups = _box.values.map(_toGroup).toList()
      ..sort((a, b) {
        return a.position != b.position
            ? a.position.compareTo(b.position)
            : a.id.compareTo(b.id);
      });
    return groups;
  }

  @override
  Future<BookmarkGroup?> getGroup(String id) async {
    final normalizedId = _normalizeId(id);
    return switch (_box.get(normalizedId)) {
      final object? => _toGroup(object),
      null => null,
    };
  }

  @override
  Future<BookmarkGroup> createGroup(String name, {String? id}) async {
    final normalizedId = id == null
        ? _uuid.v4().toLowerCase()
        : _normalizeId(id);
    if (_box.containsKey(normalizedId)) {
      throw StateError('Bookmark group $normalizedId already exists.');
    }

    final object = BookmarkGroupHiveObject(
      id: normalizedId,
      name: normalizedId == defaultBookmarkGroupId
          ? 'Default'
          : _normalizeName(name),
      bookmarkIds: [],
      position: _box.values.fold(
        0,
        (int n, g) => g.position >= n ? g.position + 1 : n,
      ),
    );
    await _box.put(normalizedId, object);
    return _toGroup(object);
  }

  @override
  Future<BookmarkGroup> duplicateGroup(String id, {String? name}) async {
    final source = _requireGroup(id);
    final duplicate = await createGroup(name ?? source.name);
    final pools = await readPoolBookmarks();
    try {
      final result = await _write(
        duplicate.copyWith(
          bookmarkIds: source.bookmarkIds,
          folderId: source.folderId,
        ),
      );
      await writePoolBookmarks([
        for (final pool in pools)
          if (pool.groupIds.contains(source.id))
            pool.withGroups({...pool.groupIds, duplicate.id})
          else
            pool,
      ]);
      return result;
    } catch (_) {
      await _box.delete(duplicate.id);
      rethrow;
    }
  }

  @override
  Future<BookmarkGroup> renameGroup(String id, String name) async {
    final group = _requireGroup(id);
    if (group.isDefault) throw StateError('Default cannot be renamed.');
    return await _write(group.copyWith(name: _normalizeName(name)));
  }

  @override
  Future<BookmarkGroup> replaceMemberships(
    String id,
    Set<int> bookmarkIds,
  ) {
    return _write(_requireGroup(id).copyWith(bookmarkIds: bookmarkIds));
  }

  @override
  Future<BookmarkGroup> addBookmarks(String id, Set<int> bookmarkIds) {
    final group = _requireGroup(id);
    return _write(
      group.copyWith(bookmarkIds: {...group.bookmarkIds, ...bookmarkIds}),
    );
  }

  @override
  Future<BookmarkGroup> removeBookmarks(String id, Set<int> bookmarkIds) {
    final group = _requireGroup(id);
    return _write(
      group.copyWith(bookmarkIds: group.bookmarkIds.difference(bookmarkIds)),
    );
  }

  @override
  Future<void> removeBookmarkFromAllGroups(int bookmarkId) async {
    final groups = await getGroups();
    for (final group in groups.where(
      (group) => group.bookmarkIds.contains(bookmarkId),
    )) {
      await removeBookmarks(group.id, {bookmarkId});
    }
  }

  @override
  Future<BookmarkGroupDeletionPreview> previewDeleteGroup(String id) async {
    final group = _requireGroup(id);
    final otherBookmarkIds = (await getGroups())
        .where((other) => other.id != group.id)
        .expand((other) => other.bookmarkIds)
        .toSet();
    final pools = await readPoolBookmarks();
    return BookmarkGroupDeletionPreview(
      group: group,
      poolIds: {
        for (final pool in pools)
          if (pool.groupIds.contains(group.id)) pool.localId,
      },
      orphanPoolIds: {
        for (final pool in pools)
          if (pool.groupIds.length == 1 && pool.groupIds.contains(group.id))
            pool.localId,
      },
      orphanBookmarkIds: group.bookmarkIds.difference(otherBookmarkIds),
    );
  }

  @override
  Future<BookmarkGroupDeletionPreview> deleteGroup(String id) async {
    final preview = await previewDeleteGroup(id);
    if (preview.group.isDefault) throw StateError('Default cannot be deleted.');
    final pools = await readPoolBookmarks();
    final nextPools = [
      for (final pool in pools)
        if (pool.groupIds.difference({preview.group.id}) case final groups
            when groups.isNotEmpty)
          pool.withGroups(groups),
    ];
    await writePoolBookmarks(nextPools);
    try {
      await _box.delete(preview.group.id);
    } catch (_) {
      await writePoolBookmarks(pools);
      rethrow;
    }
    return preview;
  }

  @override
  Future<bool> repair({required Set<int> validBookmarkIds}) async {
    var changed = false;
    for (final group in await getGroups()) {
      final repaired = group.bookmarkIds.intersection(validBookmarkIds);
      final object = _box.get(group.id)!;
      if (repaired.length != object.bookmarkIds.length ||
          repaired.length != group.bookmarkIds.length) {
        await replaceMemberships(group.id, repaired);
        changed = true;
      }
    }
    return changed;
  }

  Future<BookmarkGroup> _write(BookmarkGroup group) async {
    if (group.isDefault &&
        (group.folderId != null || group.name != 'Default')) {
      throw StateError('Default must remain at Home with its system name.');
    }
    final object = BookmarkGroupHiveObject(
      id: group.id,
      name: group.name,
      bookmarkIds: group.bookmarkIds.toList()..sort(),
      folderId: group.folderId,
      position: group.position,
    );
    await _box.put(group.id, object);
    return _toGroup(object);
  }

  BookmarkGroup _requireGroup(String id) {
    final normalizedId = _normalizeId(id);
    final object = _box.get(normalizedId);
    if (object == null) {
      throw StateError('Bookmark group $normalizedId does not exist.');
    }
    return _toGroup(object);
  }

  BookmarkGroup _toGroup(BookmarkGroupHiveObject object) {
    return BookmarkGroup(
      id: _normalizeId(object.id),
      name: _normalizeName(object.name),
      bookmarkIds: object.bookmarkIds.toSet(),
      folderId: object.folderId,
      position: object.position,
    );
  }

  Future<void> initializeFolders() async {
    final storage = _organizationBox;
    if (storage == null || storage.get('version') == 1) return;
    final groups = (await getGroups())
      ..sort((a, b) {
        final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return name != 0 ? name : a.id.compareTo(b.id);
      });
    await writeOrganization(const [], [
      for (final (position, g) in groups.indexed)
        g.copyWith(home: true, position: position),
    ]);
    await storage.put('version', 1);
  }

  @override
  Future<List<CollectionFolder>> readFolders() async {
    final raw = _organizationBox?.get('folders', defaultValue: <dynamic>[]);
    final folders = [
      for (final row in raw as List? ?? [])
        CollectionFolder.fromJson(row as Map),
    ];
    FolderTree(folders);
    return folders;
  }

  @override
  Future<void> writeOrganization(
    List<CollectionFolder> folders,
    List<BookmarkGroup> groups,
  ) async {
    final storage = _organizationBox;
    if (storage == null) throw StateError('Folder storage unavailable');
    FolderTree(folders).validatePlacements(
      groups.map(
        (g) => FolderPlacement(
          itemId: g.id,
          folderId: g.folderId,
          position: g.position,
        ),
      ),
    );
    final previousFolders = await readFolders();
    final previousGroups = await getGroups();
    try {
      await storage.put('folders', folders.map((f) => f.toJson()).toList());
      for (final group in groups) {
        await _write(group);
      }
    } catch (_) {
      await storage.put(
        'folders',
        previousFolders.map((f) => f.toJson()).toList(),
      );
      for (final group in previousGroups) {
        await _write(group);
      }
      rethrow;
    }
  }

  String _normalizeId(String id) {
    final normalized = id.trim().toLowerCase();
    if (!Uuid.isValidUUID(fromString: normalized)) {
      throw FormatException('Invalid bookmark group ID: $id');
    }
    return normalized;
  }

  String _normalizeName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Bookmark group names cannot be empty.');
    }
    return normalized;
  }
}
