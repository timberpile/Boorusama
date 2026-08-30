// Dart imports:
import 'dart:convert';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Project imports:
import '../../bookmarks/types.dart';
import '../types/backup_data_source.dart';
import '../types/types.dart';
import '../utils/json_handler.dart';

class BookmarkExportScope implements BackupExportScope {
  const BookmarkExportScope.all() : groupIds = null, includeUngrouped = false;

  BookmarkExportScope.selected({
    required Iterable<int> groupIds,
    this.includeUngrouped = false,
  }) : groupIds = Set.unmodifiable(groupIds);

  final Set<int>? groupIds;
  final bool includeUngrouped;

  bool get isAll => groupIds == null;
}

class BookmarkGroupBackup {
  const BookmarkGroupBackup({
    required this.name,
    required this.bookmarkIds,
  });

  final String name;
  final List<int> bookmarkIds;

  static BookmarkGroupBackup? tryFromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final bookmarkIds = json['bookmarkIds'];
    if (name is! String || name.trim().isEmpty || bookmarkIds is! List) {
      return null;
    }

    return BookmarkGroupBackup(
      name: name,
      bookmarkIds: bookmarkIds
          .whereType<num>()
          .map((id) => id.toInt())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'bookmarkIds': bookmarkIds,
  };
}

class BookmarkBackupData {
  const BookmarkBackupData({
    required this.bookmarks,
    required this.groups,
  });

  final List<Bookmark> bookmarks;
  final List<BookmarkGroupBackup> groups;

  Map<String, dynamic> get extraFields => {
    'groups': groups.map((group) => group.toJson()).toList(),
  };
}

BackupOperationResult buildBookmarkExportResult(BookmarkBackupData data) =>
    BackupOperationResult(totalCount: data.bookmarks.length);

BookmarkBackupData buildBookmarkBackupData({
  required List<Bookmark> bookmarks,
  required List<BookmarkGroup> groups,
  required Map<int, Set<int>> membershipsByBookmark,
  required BookmarkExportScope scope,
}) {
  final exportedBookmarks = scope.isAll
      ? bookmarks
      : bookmarks.where((bookmark) {
          final memberships =
              membershipsByBookmark[bookmark.id] ?? const <int>{};

          return (scope.includeUngrouped && memberships.isEmpty) ||
              memberships.any(scope.groupIds!.contains);
        }).toList();
  final exportedBookmarkIds = exportedBookmarks
      .map((bookmark) => bookmark.id)
      .toSet();

  final exportedGroups = groups
      .where((group) => scope.isAll || scope.groupIds!.contains(group.id))
      .map(
        (group) => BookmarkGroupBackup(
          name: group.name,
          bookmarkIds: membershipsByBookmark.entries
              .where(
                (entry) =>
                    entry.value.contains(group.id) &&
                    exportedBookmarkIds.contains(entry.key),
              )
              .map((entry) => entry.key)
              .toList(),
        ),
      )
      .toList();

  return BookmarkBackupData(
    bookmarks: exportedBookmarks,
    groups: exportedGroups,
  );
}

class BookmarkBackupHandler extends JsonHandler<BookmarkBackupData> {
  BookmarkBackupHandler({required this.parser});

  final Bookmark Function(Map<String, dynamic>) parser;

  @override
  BookmarkBackupData parse(ExportDataPayload metadata) {
    final groups = switch (metadata.extraFields['groups']) {
      final List<dynamic> rawGroups =>
        rawGroups
            .whereType<Map<String, dynamic>>()
            .map(BookmarkGroupBackup.tryFromJson)
            .whereType<BookmarkGroupBackup>()
            .toList(),
      _ => const <BookmarkGroupBackup>[],
    };

    final bookmarks = <Bookmark>[];
    for (final (index, rawBookmark) in metadata.data.indexed) {
      if (rawBookmark is! Map<String, dynamic>) {
        throw _invalidBookmarkFormat(
          'Bookmark at index $index is not a JSON object '
          '(got ${rawBookmark.runtimeType}).',
        );
      }

      try {
        bookmarks.add(parser(rawBookmark));
      } catch (error) {
        final details =
            StringBuffer(
                'Bookmark at index $index could not be parsed: $error. ',
              )
              ..write('Fields: ${rawBookmark.keys.join(', ')}. ')
              ..write('Payload: ${jsonEncode(rawBookmark)}');
        throw _invalidBookmarkFormat(details.toString());
      }
    }

    return BookmarkBackupData(bookmarks: bookmarks, groups: groups);
  }

  @override
  List<dynamic> encode(BookmarkBackupData data) =>
      data.bookmarks.map((bookmark) => bookmark.toJson()).toList();
}

InvalidBackupFormatException _invalidBookmarkFormat(String details) {
  if (kDebugMode) {
    debugPrint('[Bookmark import] $details');
    return InvalidBackupFormatException(details);
  }

  return const InvalidBackupFormatException();
}
