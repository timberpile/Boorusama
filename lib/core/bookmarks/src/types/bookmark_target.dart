// Package imports:
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class BookmarkTarget extends Equatable {
  const BookmarkTarget.ungrouped() : groupId = null;

  factory BookmarkTarget.group(String groupId) {
    final normalized = groupId.trim().toLowerCase();
    if (!Uuid.isValidUUID(fromString: normalized)) {
      throw FormatException('Invalid bookmark group ID: $groupId');
    }
    return BookmarkTarget._(normalized);
  }

  const BookmarkTarget._(this.groupId);

  final String? groupId;

  bool get isUngrouped => groupId == null;

  @override
  List<Object?> get props => [groupId];
}
