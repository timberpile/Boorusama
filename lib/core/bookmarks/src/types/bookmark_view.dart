// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import 'bookmark_target.dart';

enum BookmarkViewKind { all, ungrouped, group }

class BookmarkView extends Equatable {
  const BookmarkView.all() : kind = BookmarkViewKind.all, groupId = null;

  const BookmarkView.ungrouped()
    : kind = BookmarkViewKind.ungrouped,
      groupId = null;

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
