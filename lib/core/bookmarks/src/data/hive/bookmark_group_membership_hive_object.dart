// Package imports:
import 'package:hive_ce/hive.dart';

class BookmarkGroupMembershipHiveObject extends HiveObject {
  BookmarkGroupMembershipHiveObject({
    required this.groupId,
    required this.bookmarkId,
  });

  int groupId;
  int bookmarkId;
}
