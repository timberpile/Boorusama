// Package imports:
import 'package:equatable/equatable.dart';

class BookmarkGroup extends Equatable {
  const BookmarkGroup({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  BookmarkGroup copyWith({
    int? id,
    String? name,
  }) {
    return BookmarkGroup(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  List<Object?> get props => [id, name];
}

class BookmarkGroupDeletionPreview extends Equatable {
  const BookmarkGroupDeletionPreview({
    required this.groupId,
    required this.bookmarkCount,
    required this.orphanBookmarkIds,
  });

  final int groupId;
  final int bookmarkCount;
  final Set<int> orphanBookmarkIds;

  @override
  List<Object?> get props => [groupId, bookmarkCount, orphanBookmarkIds];
}
