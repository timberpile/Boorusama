// Package imports:
import 'package:collection/collection.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import '../../types/bookmark_group.dart';
import '../../types/bookmark_group_repository.dart';
import 'bookmark_group_hive_object.dart';
import 'bookmark_group_membership_hive_object.dart';

class BookmarkGroupRepositoryHive implements BookmarkGroupRepository {
  BookmarkGroupRepositoryHive({
    required this.groupsBox,
    required this.membershipsBox,
  });

  final Box<BookmarkGroupHiveObject> groupsBox;
  final Box<BookmarkGroupMembershipHiveObject> membershipsBox;

  @override
  Future<List<BookmarkGroup>> getGroups() async {
    return groupsBox.values
        .map(_groupFromHiveObject)
        .sorted((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<BookmarkGroup> createGroup(String name) async {
    final normalizedName = _normalizeName(name);
    _ensureNameIsAvailable(normalizedName);

    final object = BookmarkGroupHiveObject(name: normalizedName);
    final id = await groupsBox.add(object);

    return BookmarkGroup(id: id, name: normalizedName);
  }

  @override
  Future<BookmarkGroup> duplicateGroup(int groupId) async {
    final original = _getGroup(groupId);
    final duplicate = await createGroup(_duplicateName(original.name));
    final bookmarkIds = await getBookmarkIdsForGroup(groupId);

    await Future.wait(
      bookmarkIds.map(
        (bookmarkId) => addBookmarkToGroup(
          bookmarkId: bookmarkId,
          groupId: duplicate.id,
        ),
      ),
    );

    return duplicate;
  }

  @override
  Future<BookmarkGroup> renameGroup(int groupId, String name) async {
    final normalizedName = _normalizeName(name);
    final group = _getGroupObject(groupId);

    if (group.name.toLowerCase() != normalizedName.toLowerCase()) {
      _ensureNameIsAvailable(normalizedName, excludingGroupId: groupId);
    }

    group.name = normalizedName;
    await group.save();

    return BookmarkGroup(id: groupId, name: normalizedName);
  }

  @override
  Future<BookmarkGroupDeletionPreview> previewDeleteGroup(int groupId) async {
    _getGroup(groupId);
    final memberships = membershipsBox.values
        .where((membership) => membership.groupId == groupId)
        .toList();
    final bookmarkIds = memberships.map((membership) => membership.bookmarkId);
    final orphanBookmarkIds = <int>{};

    for (final membership in memberships) {
      final hasAnotherGroup = membershipsBox.values.any(
        (other) =>
            other.bookmarkId == membership.bookmarkId &&
            other.groupId != groupId,
      );
      if (!hasAnotherGroup) orphanBookmarkIds.add(membership.bookmarkId);
    }

    return BookmarkGroupDeletionPreview(
      groupId: groupId,
      bookmarkCount: bookmarkIds.toSet().length,
      orphanBookmarkIds: orphanBookmarkIds,
    );
  }

  @override
  Future<Set<int>> deleteGroup(int groupId) async {
    final preview = await previewDeleteGroup(groupId);
    final membershipKeys = membershipsBox.values
        .where((membership) => membership.groupId == groupId)
        .map((membership) => membership.key)
        .toList();

    await membershipsBox.deleteAll(membershipKeys);
    await groupsBox.delete(groupId);

    return preview.orphanBookmarkIds;
  }

  @override
  Future<Map<int, Set<int>>> getMembershipsByBookmark() async {
    final memberships = <int, Set<int>>{};

    for (final membership in membershipsBox.values) {
      memberships
          .putIfAbsent(membership.bookmarkId, () => <int>{})
          .add(membership.groupId);
    }

    return memberships;
  }

  @override
  Future<Set<int>> getBookmarkIdsForGroup(int groupId) async {
    _getGroup(groupId);

    return membershipsBox.values
        .where((membership) => membership.groupId == groupId)
        .map((membership) => membership.bookmarkId)
        .toSet();
  }

  @override
  Future<void> addBookmarkToGroup({
    required int bookmarkId,
    required int groupId,
  }) async {
    _getGroup(groupId);

    final exists = membershipsBox.values.any(
      (membership) =>
          membership.bookmarkId == bookmarkId && membership.groupId == groupId,
    );
    if (exists) return;

    await membershipsBox.add(
      BookmarkGroupMembershipHiveObject(
        bookmarkId: bookmarkId,
        groupId: groupId,
      ),
    );
  }

  @override
  Future<void> removeBookmarkFromGroup({
    required int bookmarkId,
    required int groupId,
  }) async {
    final membership = membershipsBox.values.firstWhereOrNull(
      (membership) =>
          membership.bookmarkId == bookmarkId && membership.groupId == groupId,
    );
    if (membership == null) return;

    await membershipsBox.delete(membership.key);
  }

  @override
  Future<void> removeBookmarkFromAllGroups(int bookmarkId) async {
    final membershipKeys = membershipsBox.values
        .where((membership) => membership.bookmarkId == bookmarkId)
        .map((membership) => membership.key)
        .toList();

    await membershipsBox.deleteAll(membershipKeys);
  }

  @override
  Future<void> pruneStaleMemberships({required Set<int> bookmarkIds}) async {
    final groupIds = groupsBox.keys.whereType<int>().toSet();
    final staleKeys = membershipsBox.values
        .where(
          (membership) =>
              !bookmarkIds.contains(membership.bookmarkId) ||
              !groupIds.contains(membership.groupId),
        )
        .map((membership) => membership.key)
        .toList();

    await membershipsBox.deleteAll(staleKeys);
  }

  BookmarkGroup _getGroup(int groupId) {
    return _groupFromHiveObject(_getGroupObject(groupId));
  }

  BookmarkGroupHiveObject _getGroupObject(int groupId) {
    final object = groupsBox.get(groupId);
    if (object == null) {
      throw StateError('Bookmark group $groupId does not exist.');
    }
    return object;
  }

  String _duplicateName(String name) {
    var index = 2;
    var candidate = '$name ($index)';

    while (_hasName(candidate)) {
      index++;
      candidate = '$name ($index)';
    }

    return candidate;
  }

  void _ensureNameIsAvailable(
    String name, {
    int? excludingGroupId,
  }) {
    final exists = groupsBox.values.any(
      (group) =>
          group.key != excludingGroupId &&
          group.name.toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      throw StateError('A bookmark group named "$name" already exists.');
    }
  }

  bool _hasName(String name) {
    return groupsBox.values.any(
      (group) => group.name.toLowerCase() == name.toLowerCase(),
    );
  }

  String _normalizeName(String name) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('Bookmark group names cannot be empty.');
    }
    return normalizedName;
  }

  BookmarkGroup _groupFromHiveObject(BookmarkGroupHiveObject object) {
    return BookmarkGroup(
      id: object.key as int,
      name: object.name,
    );
  }
}
