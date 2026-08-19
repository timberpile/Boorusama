// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import 'bookmark.dart';
import 'bookmark_group.dart';

class BookmarkGroupBrowserItem extends Equatable {
  const BookmarkGroupBrowserItem({
    required this.groupId,
    required this.group,
    required this.preview,
  });

  final int? groupId;
  final BookmarkGroup? group;
  final Bookmark? preview;

  bool get isAll => groupId == null;

  @override
  List<Object?> get props => [groupId, group, preview];
}
