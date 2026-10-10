// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import 'bookmark_target.dart';
import 'bookmark_group.dart';

enum BookmarkViewKind { all, group }

class BookmarkView extends Equatable {
  const BookmarkView.all() : kind = BookmarkViewKind.all, groupId = null;

  const BookmarkView.defaultGroup()
    : kind = BookmarkViewKind.group,
      groupId = defaultBookmarkGroupId;

  factory BookmarkView.group(String groupId) {
    return BookmarkView._(
      BookmarkViewKind.group,
      BookmarkTarget.group(groupId).groupId,
    );
  }

  const BookmarkView._(this.kind, this.groupId);

  final BookmarkViewKind kind;
  final String? groupId;

  @override
  List<Object?> get props => [kind, groupId];
}
