import 'package:uuid/uuid.dart';

import '../../bookmarks/types.dart';
import '../../bookmarks/src/services/bookmark_hierarchy_conversion.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../bookmarks/src/types/legacy_group_bookmark.dart';
import '../../groups/folder_tree.dart';
import '../export_import/models/import_action.dart';
import 'bookmark_import_plan.dart';
import '../export_import/import/bookmark_profile_dependency.dart';

/// A validated, allocation-free import. Temporary IDs are internal placeholders
/// only; materialize remaps them to durably reserved IDs before a single commit.
final class BookmarkImportPreparation {
  BookmarkImportPreparation._({
    required this.records,
    required this.newIds,
    required this.groups,
    required this.folders,
    required this.removeIds,
    required this.removeGroupIds,
    required this.alreadyExistedCount,
  });

  final List<Bookmark> records;
  final List<int> newIds;
  final List<BookmarkGroup> groups;
  final List<CollectionFolder> folders;
  final Set<int> removeIds;
  final Set<String> removeGroupIds;
  final int alreadyExistedCount;

  static BookmarkImportPreparation prepare({
    required BookmarkImportPlan plan,
    required List<Bookmark> currentRecords,
    required List<BookmarkGroup> currentGroups,
    required List<CollectionFolder> currentFolders,
    required Bookmark Function(Bookmark, {Bookmark? previous}) normalize,
    bool replace = false,
    Set<int> removeIds = const {},
    String importFolderName = 'Imported Groups',
    String Function()? newId,
  }) {
    var incomingPlan = plan;
    var localGroups = currentGroups;
    if (!incomingPlan.isResolved)
      throw StateError('Import conflicts are unresolved');
    final uuid = newId ?? () => const Uuid().v4().toLowerCase();
    if (currentFolders.isNotEmpty ||
        localGroups.any((g) => g.folderId != null)) {
      localGroups = BookmarkHierarchyConversion.convert(
        groups: localGroups,
        folders: currentFolders,
      ).groups;
    }
    if (incomingPlan.folders.isNotEmpty ||
        incomingPlan.groups.any((g) => g.folderId != null)) {
      final originals = {
        for (final group in incomingPlan.groups) group.id: group,
      };
      final converted = BookmarkHierarchyConversion.convert(
        groups: [
          for (final group in incomingPlan.groups)
            BookmarkGroup(
              id: group.id,
              name: group.name,
              bookmarkIds: group.bookmarkIds,
              addedAt: group.addedAt,
              folderId: group.folderId,
              position: group.position,
            ),
        ],
        folders: incomingPlan.folders,
      );
      incomingPlan = BookmarkImportPlan(
        records: incomingPlan.records,
        alreadyExistedCount: incomingPlan.alreadyExistedCount,
        groups: [
          for (final group in converted.groups)
            if (originals[group.id] case final original?)
              original
                  .copyWith(parentGroupId: group.parentGroupId, home: true)
                  .copyWith(parentGroupId: group.parentGroupId)
            else
              BookmarkGroupImport(
                id: group.id,
                name: group.name,
                bookmarkIds: group.bookmarkIds,
                addedAt: group.addedAt,
                parentGroupId: group.parentGroupId,
                position: group.position,
                conflicts: false,
              ),
        ],
      );
    }
    BookmarkGroupTree([
      for (final group in incomingPlan.groups)
        BookmarkGroup(
          id: group.id,
          name: group.name,
          bookmarkIds: group.bookmarkIds,
          addedAt: group.addedAt,
          parentGroupId: group.parentGroupId,
          position: group.position,
        ),
    ]);
    final byIdentity = {
      for (final r in currentRecords)
        if (bookmarkContentIdentity(r) case final identity?) identity: r,
    };
    final source = <int, Bookmark>{};
    final identities = <Object>{};
    for (final candidate in incomingPlan.records) {
      final identity = bookmarkContentIdentity(candidate);
      if (source.containsKey(candidate.id) ||
          (identity != null && !identities.add(identity))) {
        throw const FormatException(
          'Repeated imported Bookmark identity or ID',
        );
      }
      // Validate every record, including records whose container may be skipped.
      // A file ID never addresses a local slot, even for an opaque record.
      final previous = identity == null ? null : byIdentity[identity];
      if (previous != null)
        validateBookmarkImportCompatibility(previous, candidate);
      source[candidate.id] = normalize(candidate, previous: previous);
    }
    final sourceIds = source.keys.toSet();
    final groupIds = <String>{};
    for (final g in incomingPlan.groups) {
      if (!Uuid.isValidUUID(fromString: g.id) ||
          g.id != g.id.toLowerCase() ||
          !groupIds.add(g.id) ||
          g.name.trim().isEmpty ||
          g.name != g.name.trim() ||
          g.position < 0 ||
          !sourceIds.containsAll(g.bookmarkIds) ||
          g.addedAt.keys.toSet().difference(g.bookmarkIds).isNotEmpty ||
          (g.isDefault && (g.folderId != null || g.parentGroupId != null)) ||
          g.resolvedAction == ImportAction.configureItems) {
        throw const FormatException('Invalid imported Bookmark group');
      }
    }
    final chosen = incomingPlan.groups
        .where((g) => replace || g.resolvedAction != ImportAction.skip)
        .toList();
    final grouped = {for (final g in incomingPlan.groups) ...g.bookmarkIds};
    final selected = {
      for (final g in chosen) ...g.bookmarkIds,
      ...source.keys.toSet().difference(grouped),
    };
    final used = currentRecords.map((r) => r.id).toSet();
    final mapped = <int, int>{};
    final writes = <Bookmark>[];
    final added = <int>[];
    var next = 0;
    var existingCount = 0;
    for (final entry in source.entries) {
      if (!selected.contains(entry.key)) continue;
      final incoming = entry.value;
      final identity = bookmarkContentIdentity(incoming);
      final existing = identity == null ? null : byIdentity[identity];
      if (existing != null) {
        mapped[entry.key] = existing.id;
        existingCount++;
        if (replace) {
          writes.add(bookmarkWithId(incoming, existing.id));
        } else if (bookmarkRecordProfileHint(incoming) case final hint?
            when hint != bookmarkRecordProfileHint(existing)) {
          writes.add(bookmarkRecordWithProfileHint(existing, hint));
        }
      } else {
        while (used.contains(next)) {
          next++;
        }
        used.add(next);
        mapped[entry.key] = next;
        added.add(next);
        writes.add(bookmarkWithId(incoming, next++));
      }
    }
    final resultGroups = <String, BookmarkGroup>{
      if (!replace)
        for (final g in localGroups) g.id: g,
    };
    final targets = <String, String>{};
    final occupied = resultGroups.keys.toSet();
    final copies = chosen
        .where((g) => !g.isDefault && g.resolvedAction == ImportAction.copy)
        .toList();
    String? wrapper;
    if (!replace && copies.isNotEmpty) {
      wrapper = uuid();
      if (!Uuid.isValidUUID(fromString: wrapper) || !occupied.add(wrapper)) {
        throw const FormatException('Invalid import hierarchy wrapper');
      }
      final position = resultGroups.values
          .where((g) => g.parentGroupId == null)
          .fold(0, (n, g) => g.position >= n ? g.position + 1 : n);
      resultGroups[wrapper] = BookmarkGroup(
        id: wrapper,
        name: importFolderName.trim(),
        bookmarkIds: const {},
        position: position,
      );
    }
    for (final group in chosen) {
      final action = replace ? ImportAction.replace : group.resolvedAction!;
      final target = group.isDefault
          ? defaultBookmarkGroupId
          : action == ImportAction.mergeIntoTarget
          ? group.targetId
          : action == ImportAction.copy
          ? group.destinationId ??
                (occupied.contains(group.id) ? uuid() : group.id)
          : group.id;
      if (target == null ||
          !Uuid.isValidUUID(fromString: target) ||
          (action == ImportAction.copy && occupied.contains(target))) {
        throw const FormatException('Invalid import destination');
      }
      targets[group.id] = target;
      occupied.add(target);
    }
    final orphanCandidates = <int>{};
    final oldDates = {
      for (final r in currentRecords) r.id: bookmarkCreatedAt(r),
    };
    for (final g in chosen) {
      final action = replace ? ImportAction.replace : g.resolvedAction!;
      final target = targets[g.id]!;
      if (!Uuid.isValidUUID(fromString: target)) {
        throw const FormatException('Import target is unresolved');
      }
      final existing = resultGroups[target];
      if (action == ImportAction.mergeIntoTarget && existing == null) {
        throw const FormatException('Merge target is unavailable');
      }
      final ids = {for (final id in g.bookmarkIds) mapped[id]!};
      final dates = {
        for (final id in g.bookmarkIds)
          mapped[id]!: g.addedAt[id] ?? bookmarkCreatedAt(source[id]!),
      };
      final merge =
          !replace &&
          (g.isDefault ||
              action == ImportAction.merge ||
              action == ImportAction.mergeIntoTarget);
      if (!merge && existing != null) {
        orphanCandidates.addAll(existing.bookmarkIds.difference(ids));
      }
      final parent = replace
          ? g.parentGroupId
          : action == ImportAction.copy
          ? targets[g.parentGroupId] ?? wrapper
          : (existing != null
                ? existing.parentGroupId
                : targets[g.parentGroupId]);
      resultGroups[target] = BookmarkGroup(
        id: target,
        name: g.isDefault
            ? 'Default'
            : action == ImportAction.update || merge
            ? existing?.name ?? g.name
            : g.name,
        bookmarkIds: {...?(merge ? existing?.bookmarkIds : null), ...ids},
        addedAt: {
          ...dates,
          if (merge && existing != null)
            for (final id in existing.bookmarkIds)
              id:
                  existing.addedAt[id] ??
                  oldDates[id] ??
                  (throw const FormatException(
                    'Local membership has no record',
                  )),
        },
        parentGroupId: g.isDefault ? null : parent,
        position: g.isDefault
            ? existing?.position ?? g.position
            : replace
            ? g.position
            : existing?.position ?? g.position,
      );
    }
    final memberships = {for (final g in resultGroups.values) ...g.bookmarkIds};
    final removals = replace
        ? currentRecords
              .map((r) => r.id)
              .toSet()
              .difference(mapped.values.toSet())
        : orphanCandidates.difference(memberships);
    removals.addAll(removeIds);
    final retained = <int, Bookmark>{
      if (!replace)
        for (final r in currentRecords)
          if (!removals.contains(r.id)) r.id: r,
      for (final r in writes) r.id: r,
    };
    final ungrouped = retained.keys.toSet().difference(memberships);
    final defaultGroup = resultGroups[defaultBookmarkGroupId];
    resultGroups[defaultBookmarkGroupId] = BookmarkGroup(
      id: defaultBookmarkGroupId,
      name: 'Default',
      bookmarkIds: {...?defaultGroup?.bookmarkIds, ...ungrouped},
      addedAt: {
        ...?defaultGroup?.addedAt,
        for (final id in ungrouped) id: bookmarkCreatedAt(retained[id]!),
      },
      position: defaultGroup?.position ?? 0,
    );
    BookmarkGroupTree(resultGroups.values);
    final validIds = retained.keys.toSet();
    if (resultGroups.values.any((g) => !validIds.containsAll(g.bookmarkIds))) {
      throw const FormatException('Import leaves an absent Bookmark reference');
    }
    return BookmarkImportPreparation._(
      records: writes,
      newIds: added,
      groups: resultGroups.values.toList(),
      folders: const [],
      removeIds: removals,
      removeGroupIds: localGroups
          .map((g) => g.id)
          .toSet()
          .difference(resultGroups.keys.toSet()),
      alreadyExistedCount: existingCount,
    );
  }

  BookmarkImportWrite materialize(List<int> reserved) {
    if (reserved.length != newIds.length ||
        reserved.toSet().length != reserved.length) {
      throw const FormatException('Invalid import reservation');
    }
    final map = {
      for (var i = 0; i < reserved.length; i++) newIds[i]: reserved[i],
    };
    return BookmarkImportWrite(
      records: [for (final r in records) bookmarkWithId(r, map[r.id] ?? r.id)],
      groups: [
        for (final g in groups)
          g.copyWith(
            bookmarkIds: {for (final id in g.bookmarkIds) map[id] ?? id},
            addedAt: {
              for (final e in g.addedAt.entries) map[e.key] ?? e.key: e.value,
            },
          ),
      ],
      folders: folders,
      removeIds: removeIds,
      removeGroupIds: removeGroupIds,
    );
  }
}

final class BookmarkImportWrite {
  const BookmarkImportWrite({
    required this.records,
    required this.groups,
    required this.folders,
    required this.removeIds,
    required this.removeGroupIds,
  });
  final List<Bookmark> records;
  final List<BookmarkGroup> groups;
  final List<CollectionFolder> folders;
  final Set<int> removeIds;
  final Set<String> removeGroupIds;
}

/// Equal content keys cannot reconcile conflicting engines or typed payload
/// families. Preflight uses the same check before any selected source is changed.
void validateBookmarkImportCompatibility(Bookmark before, Bookmark after) {
  String kind(Bookmark b) => switch (b) {
    PostBookmark() => 'post',
    RelatedBookmark() || LegacyRelatedGroupBookmark() => 'related',
    _ => 'group',
  };
  if (bookmarkEngine(before) != bookmarkEngine(after) ||
      kind(before) != kind(after)) {
    throw const FormatException('Incompatible Bookmark interpretation');
  }
  if (before is ContentGroupBookmark && after is ContentGroupBookmark) {
    final oldTypes = [
      before.summary.sourceData?.typeKey,
      before.snapshot.details?.sourceData?.typeKey,
    ];
    final newTypes = [
      after.summary.sourceData?.typeKey,
      after.snapshot.details?.sourceData?.typeKey,
    ];
    for (var i = 0; i < oldTypes.length; i++) {
      if (oldTypes[i] != null &&
          newTypes[i] != null &&
          oldTypes[i] != newTypes[i]) {
        throw const FormatException('Incompatible Group payload family');
      }
    }
  }
}
