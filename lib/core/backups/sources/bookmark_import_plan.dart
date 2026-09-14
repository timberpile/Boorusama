// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../bookmarks/types.dart';

enum BookmarkGroupConflictChoice { merge, replace, cancel }

class BookmarkGroupImport extends Equatable {
  const BookmarkGroupImport({
    required this.id,
    required this.name,
    required this.bookmarkIds,
    required this.conflicts,
    this.choice,
  });

  final String id;
  final String name;
  final Set<BookmarkUniqueId> bookmarkIds;
  final bool conflicts;
  final BookmarkGroupConflictChoice? choice;

  BookmarkGroupImport resolve(BookmarkGroupConflictChoice choice) =>
      BookmarkGroupImport(
        id: id,
        name: name,
        bookmarkIds: bookmarkIds,
        conflicts: conflicts,
        choice: choice,
      );

  @override
  List<Object?> get props => [id, name, bookmarkIds, conflicts, choice];
}

class BookmarkImportPlan extends Equatable {
  const BookmarkImportPlan({
    required this.bookmarks,
    required this.missingBookmarks,
    required this.groups,
  });

  final List<Bookmark> bookmarks;
  final List<Bookmark> missingBookmarks;
  final List<BookmarkGroupImport> groups;

  List<BookmarkGroupImport> get conflicts =>
      groups.where((group) => group.conflicts).toList();

  bool get isResolved => groups.every(
    (group) => !group.conflicts || group.choice != null,
  );

  BookmarkImportPlan resolve(Map<String, BookmarkGroupConflictChoice> choices) {
    return BookmarkImportPlan(
      bookmarks: bookmarks,
      missingBookmarks: missingBookmarks,
      groups: [
        for (final group in groups)
          group.conflicts ? group.resolve(choices[group.id]!) : group,
      ],
    );
  }

  @override
  List<Object?> get props => [bookmarks, missingBookmarks, groups];
}
