// Package imports:
import 'package:hive_ce/hive.dart';

class BookmarkGroupHiveObject extends HiveObject {
  BookmarkGroupHiveObject({
    required this.id,
    required this.name,
    required List<int> bookmarkIds,
    this.folderId,
    this.parentGroupId,
    this.position = 0,
    Map<dynamic, dynamic>? addedAt,
  }) : bookmarkIds = List.unmodifiable(bookmarkIds),
       addedAt = addedAt == null ? null : Map.unmodifiable(addedAt);

  final String id;
  final String name;
  final List<int> bookmarkIds;
  // Field 3 stays readable for legacy/v2 generation recovery.
  final String? folderId;
  final String? parentGroupId;
  final int position;

  // Read defensively: invalid timestamps fall back to the saved creation date.
  final Map<dynamic, dynamic>? addedAt;
}
