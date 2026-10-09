// Package imports:
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

// Project imports:
import '../../types/bookmark_group.dart';
import '../../../../groups/folder_tree.dart';
import '../../types/bookmark_group_repository.dart';
import 'bookmark_group_hive_object.dart';

class BookmarkGroupRepositoryHive
    implements BookmarkGroupRepository, BookmarkFolderRepository {
  BookmarkGroupRepositoryHive(
    this._box, {
    Uuid uuid = const Uuid(),
    Box<dynamic>? organizationBox,
  }) : _uuid = uuid,
       _organizationBox = organizationBox;

  final Box<BookmarkGroupHiveObject> _box;
  final Uuid _uuid;
  final Box<dynamic>? _organizationBox;

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
      name: _normalizeName(name),
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
    return _write(
      duplicate.copyWith(
        bookmarkIds: source.bookmarkIds,
        folderId: source.folderId,
      ),
    );
  }

  @override
  Future<BookmarkGroup> renameGroup(String id, String name) {
    final group = _requireGroup(id);
    return _write(group.copyWith(name: _normalizeName(name)));
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
    return BookmarkGroupDeletionPreview(
      group: group,
      orphanBookmarkIds: group.bookmarkIds.difference(otherBookmarkIds),
    );
  }

  @override
  Future<BookmarkGroupDeletionPreview> deleteGroup(String id) async {
    final preview = await previewDeleteGroup(id);
    await _box.delete(preview.group.id);
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
