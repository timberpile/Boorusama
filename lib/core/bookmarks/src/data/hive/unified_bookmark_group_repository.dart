import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import '../../../../groups/folder_tree.dart';
import '../../types/bookmark.dart';
import '../../types/bookmark_record_fields.dart';
import '../../types/bookmark_group.dart';
import '../../types/bookmark_group_tree.dart';
import '../../types/bookmark_group_repository.dart';
import '../../types/legacy_group_bookmark.dart';
import '../../types/pool_bookmark.dart';
import '../../types/pool_bookmark_repository.dart';
import '../bookmark_collection_projection.dart';
import 'bookmark_group_repository_hive.dart';
import 'unified_bookmark_repository.dart';

/// The active organization exposes only common integer memberships. Existing
/// Pool/Related screens receive derived compatibility views, never a writable
/// second array. All mutations and recovery use the owning payload journal.
final class UnifiedBookmarkGroupRepository
    implements
        BookmarkGroupRepository,
        BookmarkFolderRepository,
        BookmarkRecentGroupRepository,
        BookmarkHierarchyAliasRepository,
        PoolBookmarkRepository,
        UnifiedBookmarkOrganization {
  UnifiedBookmarkGroupRepository({
    required this.bookmarks,
    required BookmarkGroupRepositoryHive reader,
    Uuid uuid = const Uuid(),
    DateTime Function()? now,
  }) : _reader = reader,
       _uuid = uuid,
       _now = now ?? DateTime.now;

  @override
  final BookmarkHiveRepository bookmarks;
  final BookmarkGroupRepositoryHive _reader;
  final Uuid _uuid;
  final DateTime Function() _now;

  Future<T> _run<T>(Future<T> Function() operation) =>
      bookmarks.runOrganizationOperation(operation);

  String _id(String id) {
    final normalized = id.trim().toLowerCase();
    if (!Uuid.isValidUUID(fromString: normalized)) {
      throw const FormatException('Invalid Bookmark Group UUID');
    }
    return normalized;
  }

  String _name(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) throw const FormatException('Empty Group name');
    return normalized;
  }

  Future<BookmarkGroup> _require(String id) async =>
      await _reader.getGroup(_id(id)) ??
      (throw StateError('Bookmark Group unavailable'));

  @override
  Future<List<BookmarkGroup>> getGroups() => _run(_reader.getGroups);
  @override
  Future<BookmarkGroup?> getGroup(String id) =>
      _run(() => _reader.getGroup(_id(id)));
  @override
  Future<BookmarkGroup> createGroup(String name, {String? id}) =>
      _run(() async {
        final localId = id == null ? _uuid.v4().toLowerCase() : _id(id);
        if (await _reader.getGroup(localId) != null)
          throw StateError('Group already exists');
        final groups = await _reader.getGroups();
        final group = BookmarkGroup(
          id: localId,
          name: localId == defaultBookmarkGroupId ? 'Default' : _name(name),
          bookmarkIds: const {},
          position: groups.fold(
            0,
            (next, group) => group.position >= next ? group.position + 1 : next,
          ),
        );
        await bookmarks.commitOrganization(groups: [group]);
        return group;
      });
  @override
  Future<BookmarkGroup> duplicateGroup(String id, {String? name}) =>
      _run(() async {
        final source = await _require(id);
        final groups = await _reader.getGroups();
        final copies = BookmarkGroupTree(groups).duplicateSubtrees(
          {source.id: _name(name ?? source.name)},
          createId: () => _uuid.v4().toLowerCase(),
        );
        await bookmarks.commitOrganization(groups: copies.groups);
        return copies.roots.single;
      });
  @override
  Future<BookmarkGroup> renameGroup(String id, String name) => _run(() async {
    final group = await _require(id);
    if (group.isDefault) throw StateError('Default cannot be renamed');
    final updated = group.copyWith(name: _name(name));
    await bookmarks.commitOrganization(groups: [updated]);
    return updated;
  });
  @override
  Future<BookmarkGroup> replaceMemberships(
    String id,
    Set<int> bookmarkIds, {
    Map<int, DateTime>? addedAt,
  }) => _run(() async {
    final group = await _require(id);
    final updated = group.copyWith(
      bookmarkIds: bookmarkIds,
      addedAt:
          addedAt ??
          {
            ...group.addedAt,
            for (final member in bookmarkIds.difference(group.bookmarkIds))
              member: _now(),
          },
    );
    await bookmarks.commitOrganization(groups: [updated]);
    return updated;
  });
  @override
  Future<BookmarkGroup> addBookmarks(String id, Set<int> bookmarkIds) =>
      _run(() async {
        final group = await _require(id);
        return replaceMemberships(group.id, {
          ...group.bookmarkIds,
          ...bookmarkIds,
        });
      });
  @override
  Future<BookmarkGroup> removeBookmarks(String id, Set<int> bookmarkIds) =>
      _run(() async {
        final group = await _require(id);
        return replaceMemberships(
          group.id,
          group.bookmarkIds.difference(bookmarkIds),
        );
      });
  @override
  Future<void> removeBookmarkFromAllGroups(int bookmarkId) => _run(() async {
    await bookmarks.commitOrganization(
      groups: [
        for (final group in await _reader.getGroups())
          if (group.bookmarkIds.contains(bookmarkId))
            group.copyWith(
              bookmarkIds: group.bookmarkIds.difference({bookmarkId}),
            ),
      ],
    );
  });
  @override
  Future<BookmarkGroupDeletionPreview> previewDeleteGroup(String id) => _run(
    () async {
      final group = await _require(id);
      final groups = await _reader.getGroups();
      final tree = BookmarkGroupTree(groups);
      final subtree = tree.subtreeIds(id);
      final otherIds = {
        for (final other in groups)
          if (!subtree.contains(other.id)) ...other.bookmarkIds,
      };
      return BookmarkGroupDeletionPreview(
        group: group,
        orphanBookmarkIds: {
          for (final member in subtree) ...tree.groupsById[member]!.bookmarkIds,
        }.difference(otherIds),
        descendantGroups: [
          for (final member in subtree)
            if (member != id) tree.groupsById[member]!,
        ],
      );
    },
  );
  @override
  Future<BookmarkGroupDeletionPreview> deleteGroup(String id) => _run(() async {
    final preview = await previewDeleteGroup(id);
    if (preview.group.isDefault) throw StateError('Default cannot be deleted');
    await bookmarks.commitOrganization(
      removeGroupIds: {
        preview.group.id,
        for (final child in preview.descendantGroups) child.id,
      },
      removeIds: preview.orphanBookmarkIds,
    );
    return preview;
  });
  @override
  Future<bool> repair({required Set<int> validBookmarkIds}) => _run(() async {
    final changed = <BookmarkGroup>[];
    for (final group in await _reader.getGroups()) {
      final ids = group.bookmarkIds.intersection(validBookmarkIds);
      if (ids.length != group.bookmarkIds.length)
        changed.add(group.copyWith(bookmarkIds: ids));
    }
    if (changed.isNotEmpty) await bookmarks.commitOrganization(groups: changed);
    return changed.isNotEmpty;
  });
  @override
  Future<List<CollectionFolder>> readFolders() => _run(_reader.readFolders);
  @override
  Future<void> writeOrganization(
    List<CollectionFolder> folders,
    List<BookmarkGroup> groups,
  ) => _run(
    () => bookmarks.commitOrganization(groups: groups, folders: folders),
  );
  @override
  Future<Map<String, String>> readLegacyFolderGroupIds() =>
      _run(_reader.readLegacyFolderGroupIds);
  @override
  Future<List<String>> readRecentGroupIds() => _run(_reader.readRecentGroupIds);
  @override
  Future<void> recordManualGroupInteraction(String groupId) =>
      _run(() => _reader.recordManualGroupInteraction(_id(groupId)));

  Future<List<CollectionBookmark>> _projections(List<Bookmark> records) async {
    final groups = await _reader.getGroups();
    return [
      for (final record in records)
        if (bookmarkCollectionProjection(
              record,
              memberships: {
                for (final group in groups)
                  if (group.bookmarkIds.contains(record.id))
                    group.id: group.addedAt[record.id]!,
              },
            )
            case final projection?)
          projection,
    ];
  }

  @override
  Future<List<CollectionBookmark>> readPoolBookmarks() =>
      _run(() async => _projections(await bookmarks.readGroupBookmarks()));

  static Map<String, Object?> _metadata(CollectionBookmark value) {
    final wire = value.toJson();
    for (final key in ['localId', 'groupIds', 'addedAt', 'createdAt']) {
      wire.remove(key);
    }
    return wire;
  }

  @override
  Future<void> writePoolBookmarks(
    List<CollectionBookmark> values,
  ) => _run(() async {
    final groups = await _reader.getGroups();
    final byGroup = {for (final group in groups) group.id: group};
    final existingRecords = await bookmarks.readGroupBookmarks();
    final existingViews = await _projections(existingRecords);
    final recordsById = {
      for (final record in existingRecords) record.id: record,
    };
    final viewsById = {
      for (final view in existingViews) view.bookmarkId!: view,
    };
    final known = <Object, Bookmark>{
      for (final record in existingRecords)
        if (bookmarkContentIdentity(record) case final identity?)
          identity: record,
    };
    final seen = <Object>{};
    final seenContent = <Object>{};
    final prepared = <(CollectionBookmark, Bookmark?, Bookmark)>[];
    for (final value in values) {
      if (value.groupIds.isEmpty ||
          !byGroup.keys.toSet().containsAll(value.groupIds)) {
        throw const FormatException(
          'Invalid Pool/Related compatibility memberships',
        );
      }
      final evidence = LegacyGroupBookmark.fromMetadata(id: 0, metadata: value);
      final content = bookmarkContentIdentity(evidence);
      if (content != null && !seenContent.add(content)) {
        throw const FormatException('Conflicting Group interpretations');
      }
      if (content == null &&
          !seen.add(
            value.bookmarkId == null
                ? ('file', value.localId)
                : ('stored', value.bookmarkId),
          )) {
        throw const FormatException('Duplicate unresolved Group record');
      }
      var current = content == null ? null : known[content];
      if (value.bookmarkId case final localId?) {
        final owned = recordsById[localId];
        if (owned == null ||
            viewsById[localId]?.identity != value.identity ||
            (current != null && current.id != localId)) {
          throw StateError('Stored Group changed before the action completed');
        }
        current = owned;
      }
      if (current != null &&
          bookmarkEngine(current) != value.origin.booruType) {
        throw const FormatException('Incompatible Group engines');
      }
      final previousView = current == null ? null : viewsById[current.id];
      final keep =
          previousView != null &&
          (value.loadedDetails == null ||
              value.loadedDetails == previousView.loadedDetails) &&
          const DeepCollectionEquality().equals(
            _metadata(previousView),
            _metadata(value),
          ) &&
          (value.sourceSite == null ||
              value.sourceSite == previousView.sourceSite);
      final candidate = keep
          ? current!
          : collectionRecordForSave(
              value,
              id: current?.id ?? 0,
              previous: current,
            );
      prepared.add((
        value,
        current,
        keep ? candidate : bookmarks.normalizeRecord(candidate),
      ));
    }
    final ids = await bookmarks.reserveIds(
      prepared.where((entry) => entry.$2 == null).length,
    );
    var next = 0;
    final desired = <int, Bookmark>{};
    final writes = <Bookmark>[];
    final touched = <int>{};
    final changedGroupIds = <String>{};
    final dates = <int, Map<String, DateTime>>{};
    for (final (view, current, candidate) in prepared) {
      final id = current?.id ?? ids[next++];
      final record = current == null
          ? bookmarkWithId(candidate, id)
          : candidate;
      desired[id] = record;
      if (current == null || !identical(candidate, current)) writes.add(record);
      dates[id] = view.addedAt;
      final previous = current == null ? null : viewsById[current.id];
      if (previous == null ||
          !const MapEquality<String, DateTime>().equals(
            previous.addedAt,
            view.addedAt,
          )) {
        touched.add(id);
        changedGroupIds.addAll({...?previous?.groupIds, ...view.groupIds});
      }
    }
    final oldIds = viewsById.keys.toSet();
    final removed = oldIds.difference(desired.keys.toSet());
    touched.addAll(removed);
    for (final id in removed) {
      changedGroupIds.addAll(viewsById[id]!.groupIds);
    }
    final changed = <BookmarkGroup>[];
    for (final group in groups.where(
      (group) => changedGroupIds.contains(group.id),
    )) {
      final ids = group.bookmarkIds.difference(touched);
      final addedAt = Map<int, DateTime>.of(group.addedAt)
        ..removeWhere((id, _) => touched.contains(id));
      for (final id in touched) {
        if (dates[id]?[group.id] case final date?) {
          ids.add(id);
          addedAt[id] = date;
        }
      }
      if (!const SetEquality<int>().equals(ids, group.bookmarkIds) ||
          !const MapEquality<int, DateTime>().equals(addedAt, group.addedAt)) {
        changed.add(group.copyWith(bookmarkIds: ids, addedAt: addedAt));
      }
    }
    await bookmarks.commitOrganization(
      records: writes,
      removeIds: removed,
      groups: changed,
    );
  });
}
