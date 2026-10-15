// Package imports:
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'bookmark_group.dart';

class BookmarkTarget extends Equatable {
  const BookmarkTarget.defaultGroup() : groupId = defaultBookmarkGroupId;

  factory BookmarkTarget.group(String groupId) {
    final normalized = groupId.trim().toLowerCase();
    if (!Uuid.isValidUUID(fromString: normalized)) {
      throw FormatException('Invalid bookmark group ID: $groupId');
    }
    return BookmarkTarget._(normalized);
  }

  factory BookmarkTarget.fromGroupId(String? groupId) {
    if (groupId == null || !Uuid.isValidUUID(fromString: groupId)) {
      return const BookmarkTarget.defaultGroup();
    }
    return BookmarkTarget.group(groupId);
  }

  const BookmarkTarget._(this.groupId);

  final String groupId;

  @override
  List<Object?> get props => [groupId];
}
