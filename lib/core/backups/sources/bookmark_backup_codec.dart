// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:uuid/uuid.dart';

// Project imports:
import '../../boorus/booru/types.dart';
import '../../bookmarks/types.dart';
import '../../posts/post/types.dart';
import '../types/types.dart';
import '../utils/json_handler.dart';
import 'bookmark_backup_data.dart';

class BookmarkBackupCodec extends JsonHandler<BookmarkBackupData> {
  BookmarkBackupCodec({
    required this.bookmarkParser,
    this.postDataCodec,
  });

  final Bookmark Function(Map<String, dynamic>) bookmarkParser;
  final BooruPostDataCodec? Function(BooruType type)? postDataCodec;

  @override
  BookmarkBackupData parse(ExportDataPayload metadata) {
    final bookmarks = <Bookmark>[];
    final bookmarkIds = <int>{};
    final bookmarkIdentities = <BookmarkUniqueId>{};
    for (final (index, value) in metadata.data.indexed) {
      if (value is! Map<String, dynamic>) {
        throw InvalidBackupFormatException('data[$index] must be an object');
      }
      try {
        final bookmark = switch (metadata.version) {
          1 => _parseVersion1Bookmark(value, index),
          2 => _parseVersion2Bookmark(value, index),
          _ => throw InvalidBackupFormatException(
            'Unsupported bookmark backup version ${metadata.version}',
          ),
        };
        if (!bookmarkIds.add(bookmark.id)) {
          throw InvalidBackupFormatException(
            'data[$index].id is repeated',
          );
        }
        if (!bookmarkIdentities.add(bookmark.uniqueId)) {
          throw InvalidBackupFormatException(
            'data[$index] repeats a bookmark identity',
          );
        }
        bookmarks.add(bookmark);
      } on InvalidBackupFormatException {
        rethrow;
      } catch (_) {
        throw InvalidBackupFormatException('data[$index] is invalid');
      }
    }

    if (!metadata.extraFields.containsKey('groups')) {
      return BookmarkBackupData(bookmarks: bookmarks, groups: const []);
    }
    final rawGroups = metadata.extraFields['groups'];
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
  List<dynamic> encode(BookmarkBackupData data) => data.bookmarks
      .map(
        (bookmark) => {
          'localId': bookmark.localId,
          'createdAt': bookmark.createdAt.toIso8601String(),
          'updatedAt': bookmark.updatedAt.toIso8601String(),
          'snapshot': bookmark.snapshot.toJson(),
        },
      )
      .toList();

  Bookmark _parseVersion1Bookmark(Map<String, dynamic> value, int index) {
    _validateVersion1Bookmark(value, index);
    return bookmarkParser(value);
  }

  Bookmark _parseVersion2Bookmark(Map<String, dynamic> value, int index) {
    final localId = value['localId'];
    final createdAt = value['createdAt'];
    final updatedAt = value['updatedAt'];
    final rawSnapshot = value['snapshot'];
    if (localId is! int ||
        createdAt is! String ||
        updatedAt is! String ||
        rawSnapshot is! Map<String, dynamic>) {
      throw InvalidBackupFormatException('data[$index] is invalid');
    }

    final snapshot = StoredPostSnapshot.fromJson(rawSnapshot);
    final type = BooruType.fromLegacyId(snapshot.origin.booruTypeId);
    final decoded = const StoredPostCodec().decode(
      snapshot,
      dataCodec: postDataCodec?.call(type),
    );
    return switch (decoded) {
      StoredPostDecodeSuccess(:final post) => Bookmark.fromSnapshot(
        id: localId,
        createdAt: DateTime.parse(createdAt),
        updatedAt: DateTime.parse(updatedAt),
        snapshot: snapshot,
        post: post,
        postId: post.id,
      ),
      StoredPostDecodeFailure() => throw InvalidBackupFormatException(
        'data[$index].snapshot is invalid',
      ),
    };
  }
}

void _validateVersion1Bookmark(Map<String, dynamic> value, int index) {
  final requiredInts = ['id', 'booruId'];
  final requiredStrings = [
    'createdAt',
    'updatedAt',
    'thumbnailUrl',
    'sampleUrl',
    'originalUrl',
    'sourceUrl',
    'md5',
  ];
  for (final field in requiredInts) {
    if (value[field] is! int) {
      throw InvalidBackupFormatException('data[$index].$field is invalid');
    }
  }
  for (final field in requiredStrings) {
    if (value[field] is! String) {
      throw InvalidBackupFormatException('data[$index].$field is invalid');
    }
  }
  for (final field in ['width', 'height']) {
    if (value[field] is! num) {
      throw InvalidBackupFormatException('data[$index].$field is invalid');
    }
  }
  final tags = switch (value['tags']) {
    final List<dynamic> tags => tags,
    final String encoded => switch (jsonDecode(encoded)) {
      final List<dynamic> tags => tags,
      _ => throw InvalidBackupFormatException(
        'data[$index].tags is invalid',
      ),
    },
    _ => throw InvalidBackupFormatException('data[$index].tags is invalid'),
  };
  if (tags.any((tag) => tag is! String)) {
    throw InvalidBackupFormatException('data[$index].tags is invalid');
  }
  if (value['realSourceUrl'] case final realSourceUrl?
      when realSourceUrl is! String) {
    throw InvalidBackupFormatException(
      'data[$index].realSourceUrl is invalid',
    );
  }
  if (value['format'] case final format? when format is! String) {
    throw InvalidBackupFormatException('data[$index].format is invalid');
  }
  if (value['postId'] case final postId? when postId is! int) {
    throw InvalidBackupFormatException('data[$index].postId is invalid');
  }
  if (value['metadata'] case final metadata?) {
    if (metadata is! Map<String, dynamic> ||
        metadata.values.any(
          (entry) => entry is! String && entry is! num && entry is! bool,
        )) {
      throw InvalidBackupFormatException('data[$index].metadata is invalid');
    }
  }
}
