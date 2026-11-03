// Package imports:
import 'package:equatable/equatable.dart';

/// Reserved system identity. Ordinary groups may also be named Default.
const defaultBookmarkGroupId = '00000000-0000-0000-0000-000000000000';

enum BookmarkGroupSystemRole { defaultGroup }

class BookmarkGroup extends Equatable {
  BookmarkGroup({
    required this.id,
    required this.name,
    required Set<int> bookmarkIds,
    Map<int, DateTime> addedAt = const {},
    this.folderId,
    this.position = 0,
  }) : bookmarkIds = Set.unmodifiable(bookmarkIds),
       addedAt = Map.unmodifiable({
         for (final entry in addedAt.entries)
           if (bookmarkIds.contains(entry.key)) entry.key: entry.value.toUtc(),
       });

  BookmarkGroupSystemRole? get systemRole => id == defaultBookmarkGroupId
      ? BookmarkGroupSystemRole.defaultGroup
      : null;
  bool get isDefault => systemRole == BookmarkGroupSystemRole.defaultGroup;

  final String id;
  final String name;
  final String? folderId;
  final int position;
  final Set<int> bookmarkIds;
  final Map<int, DateTime> addedAt;

  BookmarkGroup copyWith({
    String? name,
    Set<int>? bookmarkIds,
    Map<int, DateTime>? addedAt,
    String? folderId,
    bool home = false,
    int? position,
  }) {
    return BookmarkGroup(
      id: id,
      name: name ?? this.name,
      bookmarkIds: bookmarkIds ?? this.bookmarkIds,
      addedAt: addedAt ?? this.addedAt,
      folderId: home ? null : folderId ?? this.folderId,
      position: position ?? this.position,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    bookmarkIds,
    addedAt,
    folderId,
    position,
  ];
}

class BookmarkGroupDeletionPreview extends Equatable {
  BookmarkGroupDeletionPreview({
    required this.group,
    required Set<int> orphanBookmarkIds,
    this.poolIds = const {},
    this.orphanPoolIds = const {},
  }) : orphanBookmarkIds = Set.unmodifiable(orphanBookmarkIds);

  final BookmarkGroup group;
  final Set<int> orphanBookmarkIds;
  final Set<String> poolIds;
  final Set<String> orphanPoolIds;

  int get bookmarkCount => group.bookmarkIds.length + poolIds.length;

  @override
  List<Object?> get props => [group, orphanBookmarkIds, poolIds, orphanPoolIds];
}
