// Package imports:
import 'package:uuid/uuid.dart';

// Project imports:
import '../../boorus/booru/types.dart';
import '../../bookmarks/types.dart';
import '../../groups/folder_tree.dart';
import '../../posts/post/types.dart';
import '../types/types.dart';
import '../utils/json_handler.dart';
import 'bookmark_backup_data.dart';

class BookmarkBackupCodec extends JsonHandler<BookmarkBackupData> {
  BookmarkBackupCodec({this.postDataCodec});

  final BooruPostDataCodec? Function(BooruType type)? postDataCodec;

  @override
  BookmarkBackupData parse(ExportDataPayload metadata) {
    if (metadata.version != 4 && metadata.version != 5) {
      throw InvalidBackupFormatException(
        'Unsupported bookmark backup version ${metadata.version}',
      );
    }
    final bookmarks = <Bookmark>[];
    final fileBookmarkIds = <int>{};
    final bookmarkIdentities = <Object>{};
    for (final (index, value) in metadata.data.indexed) {
      if (value is! Map<String, dynamic>) {
        throw InvalidBackupFormatException('data[$index] must be an object');
      }
      try {
        final bookmark = _parseVersion4Bookmark(value, index);
        if (!fileBookmarkIds.add(bookmark.id)) {
          throw InvalidBackupFormatException(
            'data[$index].id is repeated',
          );
        }
        final identity = bookmark.identity;
        if (!bookmarkIdentities.add(identity)) {
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

    final rawGroups = metadata.extraFields['groups'] ?? <dynamic>[];
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
      if (bookmarkIds.any((id) => !fileBookmarkIds.contains(id))) {
        throw InvalidBackupFormatException(
          'groups[$index].bookmarkIds references an absent bookmark',
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
      final folderId = metadata.version == 5 ? value['folderId'] : null;
      final position = metadata.version == 5
          ? value['position'] ?? index
          : index;
      if ((folderId != null &&
              (folderId is! String ||
                  !Uuid.isValidUUID(fromString: folderId))) ||
          position is! int ||
          position < 0) {
        throw InvalidBackupFormatException(
          'groups[$index] placement is invalid',
        );
      }
      final role = value['systemRole'];
      if (role != null && (role != 'default' || id != defaultBookmarkGroupId)) {
        throw InvalidBackupFormatException(
          'groups[$index].systemRole is invalid',
        );
      }
      if (id == defaultBookmarkGroupId && folderId != null) {
        throw const InvalidBackupFormatException('Default must be at Home');
      }
      groups.add(
        BookmarkGroupBackup(
          id: id,
          name: name.trim(),
          bookmarkIds: bookmarkIds.cast<int>().toSet().toList(),
          folderId: (folderId as String?)?.toLowerCase(),
          position: position,
        ),
      );
    }
    try {
      final rawFolders = metadata.version == 5
          ? metadata.extraFields['folders']
          : null;
      if (rawFolders != null && rawFolders is! List) {
        throw const FormatException('Invalid folders');
      }
      final folders = [
        for (final row in rawFolders as List? ?? [])
          (() {
            final f = CollectionFolder.fromJson(row as Map);
            return CollectionFolder(
              id: f.id.toLowerCase(),
              name: f.name.trim(),
              parentId: f.parentId?.toLowerCase(),
              position: f.position,
            );
          })(),
      ];
      if (folders.any(
        (f) =>
            !Uuid.isValidUUID(fromString: f.id) ||
            (f.parentId != null && !Uuid.isValidUUID(fromString: f.parentId!)),
      )) {
        throw const FormatException('Invalid folder UUID');
      }
      final tree = FolderTree(folders);
      tree.validatePlacements([
        for (final (i, g) in groups.indexed)
          FolderPlacement(
            itemId: g.id ?? 'legacy-$i',
            folderId: g.folderId,
            position: g.position,
          ),
      ]);
      return BookmarkBackupData(
        bookmarks: bookmarks,
        groups: groups,
        folders: folders,
      );
    } catch (_) {
      throw const InvalidBackupFormatException(
        'Invalid bookmark folder hierarchy',
      );
    }
  }

  @override
  List<dynamic> encode(BookmarkBackupData data) =>
      data.bookmarks.map(_encodeBookmark).toList();

  Map<String, Object?> _encodeBookmark(Bookmark bookmark) {
    final identity = BookmarkIdentity.tryFromPost(bookmark.post);
    if (bookmark.postId == null ||
        bookmark.postId != bookmark.post.id ||
        identity == null) {
      throw const InvalidBackupFormatException(
        'Bookmark has no stable upstream identity',
      );
    }
    return {
      'localId': bookmark.localId,
      'createdAt': bookmark.createdAt.toIso8601String(),
      'updatedAt': bookmark.updatedAt.toIso8601String(),
      'snapshot': bookmark.snapshot.toJson(),
      'postId': bookmark.postId,
      'identity': identity.toJson(),
    };
  }

  Bookmark _parseSnapshotBookmark(Map<String, dynamic> value, int index) {
    final localId = value['localId'];
    final createdAt = value['createdAt'];
    final updatedAt = value['updatedAt'];
    final rawSnapshot = value['snapshot'];
    final postId = value['postId'];
    if (localId is! int ||
        createdAt is! String ||
        updatedAt is! String ||
        rawSnapshot is! Map<String, dynamic> ||
        postId is! int) {
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
        postId: postId,
      ),
      StoredPostDecodeFailure() => throw InvalidBackupFormatException(
        'data[$index].snapshot is invalid',
      ),
    };
  }

  Bookmark _parseVersion4Bookmark(Map<String, dynamic> value, int index) {
    final rawIdentity = value['identity'];
    if (rawIdentity is! Map<String, dynamic> || value['postId'] is! int) {
      throw InvalidBackupFormatException('data[$index].identity is invalid');
    }
    final bookmark = _parseSnapshotBookmark(value, index);
    final identity = BookmarkIdentity.fromJson(rawIdentity);
    if (rawIdentity['site'] != identity.site ||
        bookmark.postId != bookmark.post.id ||
        identity != BookmarkIdentity.tryFromPost(bookmark.post)) {
      throw InvalidBackupFormatException(
        'data[$index].identity does not match its snapshot',
      );
    }
    return bookmark;
  }
}
