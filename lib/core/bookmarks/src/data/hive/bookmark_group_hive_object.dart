// Package imports:
import 'package:hive_ce/hive.dart';

class BookmarkGroupHiveObject extends HiveObject {
  BookmarkGroupHiveObject({
    required this.name,
  });

  String name;
}
