// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../export_import/models/import_action.dart';
import '../../bookmarks/types.dart';
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
    this.position = 0,
  });

  final String id;
  final String name;
  final Set<BookmarkUniqueId> bookmarkIds;
  final bool conflicts;
  final BookmarkGroupConflictChoice? choice;
  final ImportAction? action;
  final String? targetId;
  final String? destinationId;
  final String? folderId;
  final int position;

  ImportAction? get resolvedAction =>
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
        conflicts: conflicts,
        choice: choice,
        action: action,
        targetId: targetId,
        destinationId: destinationId,
        folderId: folderId,
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
    conflicts: conflicts,
    choice: choice,
    action: action,
    targetId: targetId,
    destinationId: destinationId,
    folderId: folderId,
    position: position,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    bookmarkIds,
    conflicts,
    choice,
    action,
    targetId,
    destinationId,
    folderId,
    position,
  ];
}

class BookmarkImportPlan extends Equatable {
  const BookmarkImportPlan({
    required this.bookmarks,
    required this.missingBookmarks,
    required this.groups,
    this.folders = const [],
  });

  final List<Bookmark> bookmarks;
  final List<Bookmark> missingBookmarks;
  final List<BookmarkGroupImport> groups;
  final List<CollectionFolder> folders;

  List<BookmarkGroupImport> get conflicts =>
      groups.where((group) => group.conflicts).toList();

  bool get isResolved => groups.every(
    (group) => group.resolvedAction != null,
  );

  BookmarkImportPlan resolve(Map<String, BookmarkGroupConflictChoice> choices) {
    return BookmarkImportPlan(
      bookmarks: bookmarks,
      missingBookmarks: missingBookmarks,
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
    bookmarks: bookmarks,
    missingBookmarks: missingBookmarks,
    folders: folders,
    groups: [
      for (final group in groups) resolvedGroups[group.id] ?? group,
    ],
  );

  @override
  List<Object?> get props => [bookmarks, missingBookmarks, groups, folders];
}
