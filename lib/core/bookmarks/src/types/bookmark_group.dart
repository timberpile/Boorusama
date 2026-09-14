// Package imports:
import 'package:equatable/equatable.dart';

class BookmarkGroup extends Equatable {
  BookmarkGroup({
    required this.id,
    required this.name,
    required Set<int> bookmarkIds,
  }) : bookmarkIds = Set.unmodifiable(bookmarkIds);

  final String id;
  final String name;
  final Set<int> bookmarkIds;

  BookmarkGroup copyWith({
    String? name,
    Set<int>? bookmarkIds,
  }) {
    return BookmarkGroup(
      id: id,
      name: name ?? this.name,
      bookmarkIds: bookmarkIds ?? this.bookmarkIds,
    );
  }

  @override
  List<Object?> get props => [id, name, bookmarkIds];
}

class BookmarkGroupDeletionPreview extends Equatable {
  BookmarkGroupDeletionPreview({
    required this.group,
    required Set<int> orphanBookmarkIds,
  }) : orphanBookmarkIds = Set.unmodifiable(orphanBookmarkIds);

  final BookmarkGroup group;
  final Set<int> orphanBookmarkIds;

  int get bookmarkCount => group.bookmarkIds.length;

  @override
  List<Object?> get props => [group, orphanBookmarkIds];
}
