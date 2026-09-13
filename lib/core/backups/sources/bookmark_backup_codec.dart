// Package imports:
import 'package:uuid/uuid.dart';

// Project imports:
import '../../bookmarks/types.dart';
import '../types/types.dart';
import '../utils/json_handler.dart';
import 'bookmark_backup_data.dart';

class BookmarkBackupCodec extends JsonHandler<BookmarkBackupData> {
  BookmarkBackupCodec({required this.bookmarkParser});

  final Bookmark Function(Map<String, dynamic>) bookmarkParser;

  @override
  BookmarkBackupData parse(ExportDataPayload metadata) {
    final bookmarks = <Bookmark>[];
    for (final (index, value) in metadata.data.indexed) {
      if (value is! Map<String, dynamic>) {
        throw InvalidBackupFormatException('data[$index] must be an object');
      }
      try {
        bookmarks.add(bookmarkParser(value));
      } catch (_) {
        throw InvalidBackupFormatException('data[$index] is invalid');
      }
    }

    final rawGroups = metadata.extraFields['groups'];
    if (rawGroups == null) {
      return BookmarkBackupData(bookmarks: bookmarks, groups: const []);
    }
    if (rawGroups is! List<dynamic>) {
      throw const InvalidBackupFormatException('groups must be a list');
    }

    final groups = <BookmarkGroupBackup>[];
    final suppliedIds = <String>{};
    for (final (index, value) in rawGroups.indexed) {
      if (value is! Map<String, dynamic>) {
        throw InvalidBackupFormatException('groups[$index] must be an object');
      }
      final name = value['name'];
      final bookmarkIds = value['bookmarkIds'];
      final rawId = value['id'];
      if (name is! String || name.trim().isEmpty) {
        throw InvalidBackupFormatException('groups[$index].name is invalid');
      }
      if (bookmarkIds is! List<dynamic> ||
          bookmarkIds.any((id) => id is! int)) {
        throw InvalidBackupFormatException(
          'groups[$index].bookmarkIds is invalid',
        );
      }
      final id = switch (rawId) {
        null => null,
        final String value when Uuid.isValidUUID(fromString: value) =>
          value.toLowerCase(),
        _ => throw InvalidBackupFormatException('groups[$index].id is invalid'),
      };
      if (id != null && !suppliedIds.add(id)) {
        throw InvalidBackupFormatException('groups[$index].id is repeated');
      }
      groups.add(
        BookmarkGroupBackup(
          id: id,
          name: name.trim(),
          bookmarkIds: bookmarkIds.cast<int>().toSet().toList(),
        ),
      );
    }
    return BookmarkBackupData(bookmarks: bookmarks, groups: groups);
  }

  @override
  List<dynamic> encode(BookmarkBackupData data) =>
      data.bookmarks.map((bookmark) => bookmark.toJson()).toList();
}
