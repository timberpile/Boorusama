// Package imports:
import 'package:hive_ce/hive.dart';

class BookmarkGroupHiveObject extends HiveObject {
  BookmarkGroupHiveObject({
    required this.id,
    required this.name,
    required this.bookmarkIds,
  });

  String id;
  String name;
  List<int> bookmarkIds;
}
