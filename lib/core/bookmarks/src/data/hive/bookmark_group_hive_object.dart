// Package imports:
import 'package:hive_ce/hive.dart';

class BookmarkGroupHiveObject extends HiveObject {
  BookmarkGroupHiveObject({
    required this.id,
    required this.name,
    required List<int> bookmarkIds,
    this.folderId,
    this.position = 0,
    Map<dynamic, dynamic>? addedAt,
  }) : bookmarkIds = List.unmodifiable(bookmarkIds),
       addedAt = addedAt == null ? null : Map.unmodifiable(addedAt);

  final String id;
  final String name;
  final List<int> bookmarkIds;
  final String? folderId;
  final int position;

  // Read defensively: invalid timestamps fall back to the saved creation date.
  final Map<dynamic, dynamic>? addedAt;
}
