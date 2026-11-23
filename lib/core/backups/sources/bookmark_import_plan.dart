// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../export_import/models/import_action.dart';
import '../../bookmarks/types.dart';
import 'bookmark_backup_data.dart';
import '../../groups/folder_tree.dart';

enum BookmarkGroupConflictChoice { merge, replace, cancel }

class BookmarkGroupImport extends Equatable {
  const BookmarkGroupImport({
    required this.id,
    required this.name,
    required this.bookmarkIds,
    required this.conflicts,
    this.choice,
    this.action,
    this.targetId,
    this.destinationId,
    this.folderId,
    this.parentGroupId,
    this.position = 0,
    this.addedAt = const {},
  });

  final String id;
  final String name;
  final Set<int> bookmarkIds;
  final Map<int, DateTime> addedAt;
  final bool conflicts;
  final BookmarkGroupConflictChoice? choice;
  final ImportAction? action;
  final String? targetId;
  final String? destinationId;
  final String? folderId;
  final String? parentGroupId;
  final int position;

  bool get isDefault => id == defaultBookmarkGroupId;

  ImportAction? get resolvedAction =>
      (isDefault
          ? (action == ImportAction.skip
                ? ImportAction.skip
                : ImportAction.merge)
          : null) ??
      action ??
      switch (choice) {
        BookmarkGroupConflictChoice.merge => ImportAction.merge,
        BookmarkGroupConflictChoice.replace => ImportAction.update,
        BookmarkGroupConflictChoice.cancel => ImportAction.skip,
        null when !conflicts => ImportAction.copy,
        null => null,
      };

  BookmarkGroupImport resolve(BookmarkGroupConflictChoice choice) =>
      BookmarkGroupImport(
        id: id,
        name: name,
        bookmarkIds: bookmarkIds,
        addedAt: addedAt,
        conflicts: conflicts,
        choice: choice,
        action: action,
        targetId: targetId,
        destinationId: destinationId,
        folderId: folderId,
        parentGroupId: parentGroupId,
        position: position,
      );

  BookmarkGroupImport resolveAction(
    ImportAction action, {
    String? targetId,
    String? destinationId,
  }) => BookmarkGroupImport(
    id: id,
    name: name,
    bookmarkIds: bookmarkIds,
    addedAt: addedAt,
    conflicts: conflicts,
    choice: choice,
    action: action,
    targetId: targetId,
    destinationId: destinationId,
    folderId: folderId,
    parentGroupId: parentGroupId,
    position: position,
  );

  BookmarkGroupImport copyWith({
    String? name,
    Set<int>? bookmarkIds,
    Map<int, DateTime>? addedAt,
    bool? conflicts,
    BookmarkGroupConflictChoice? choice,
    ImportAction? action,
    String? targetId,
    String? destinationId,
    String? folderId,
    String? parentGroupId,
    bool home = false,
    int? position,
  }) => BookmarkGroupImport(
    id: id,
    name: name ?? this.name,
    bookmarkIds: bookmarkIds ?? this.bookmarkIds,
    addedAt: addedAt ?? this.addedAt,
    conflicts: conflicts ?? this.conflicts,
    choice: choice ?? this.choice,
    action: action ?? this.action,
    targetId: targetId ?? this.targetId,
    destinationId: destinationId ?? this.destinationId,
    folderId: home ? null : folderId ?? this.folderId,
    parentGroupId: home ? null : parentGroupId ?? this.parentGroupId,
    position: position ?? this.position,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    bookmarkIds,
    addedAt,
    conflicts,
    choice,
    action,
    targetId,
    destinationId,
    folderId,
    parentGroupId,
    position,
  ];
}

class BookmarkImportPlan extends Equatable {
  BookmarkImportPlan({
    required List<Bookmark> records,
    required this.groups,
    this.folders = const [],
    this.alreadyExistedCount = 0,
  }) : records = List.unmodifiable(records);

  final List<Bookmark> records;
  final List<BookmarkGroupImport> groups;
  final List<CollectionFolder> folders;
  final int alreadyExistedCount;
  List<PostBookmark> get bookmarks =>
      records.whereType<PostBookmark>().toList();
  List<CollectionBookmark> get pools => BookmarkBackupData.unified(
    records: records,
    folders: folders,
    groups: [
      for (final g in groups)
        BookmarkGroupBackup(
          id: g.id,
          name: g.name,
          bookmarkIds: g.bookmarkIds.toList(),
          addedAt: g.addedAt,
          folderId: g.folderId,
          position: g.position,
        ),
    ],
  ).pools;

  List<BookmarkGroupImport> get conflicts =>
      groups.where((group) => group.conflicts).toList();

  bool get isResolved => groups.every(
    (group) => group.resolvedAction != null,
  );

  BookmarkImportPlan resolve(Map<String, BookmarkGroupConflictChoice> choices) {
    return BookmarkImportPlan(
      records: records,
      alreadyExistedCount: alreadyExistedCount,
      folders: folders,
      groups: [
        for (final group in groups)
          group.conflicts ? group.resolve(choices[group.id]!) : group,
      ],
    );
  }

  BookmarkImportPlan resolveActions(
    Map<String, BookmarkGroupImport> resolvedGroups,
  ) => BookmarkImportPlan(
    records: records,
    alreadyExistedCount: alreadyExistedCount,
    folders: folders,
    groups: [
      for (final group in groups) resolvedGroups[group.id] ?? group,
    ],
  );

  @override
  List<Object?> get props => [
    records,
    alreadyExistedCount,
    groups,
    folders,
  ];
}
