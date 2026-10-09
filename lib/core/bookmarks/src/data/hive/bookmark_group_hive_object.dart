// Package imports:
import 'package:hive_ce/hive.dart';

class BookmarkGroupHiveObject extends HiveObject {
  BookmarkGroupHiveObject({
    required this.id,
    required this.name,
    required this.bookmarkIds,
    this.folderId,
    this.position = 0,
  });

  String id;
  String name;
  List<int> bookmarkIds;
  String? folderId;
  int position;
}
