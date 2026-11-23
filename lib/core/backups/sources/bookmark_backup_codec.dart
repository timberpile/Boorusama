// Package imports:
import 'package:uuid/uuid.dart';

// Project imports:
import '../../boorus/booru/types.dart';
import '../../bookmarks/types.dart';
import '../../bookmarks/src/data/stored_bookmark_codec.dart';
import '../../bookmarks/src/data/stored_group_codec.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../content/types.dart';
import '../../groups/folder_tree.dart';
import '../../posts/post/types.dart';
import '../types/types.dart';
import '../utils/json_handler.dart';
import 'bookmark_backup_data.dart';
import 'bookmark_backup_schema.dart';

class BookmarkBackupCodec extends JsonHandler<BookmarkBackupData> {
  BookmarkBackupCodec({
    this.postDataCodec,
    this.groupMetadata = const GroupMetadataCodec(),
    this.groupMetadataResolver,
  });

  final GroupMetadataCodec groupMetadata;
  final GroupMetadataCodec Function()? groupMetadataResolver;
  StoredBookmarkCodec get records => StoredBookmarkCodec(
    postDataCodec: postDataCodec,
    groups: StoredGroupCodec(
      metadata: groupMetadata,
      metadataResolver: groupMetadataResolver,
    ),
  );

  final BooruPostDataCodec? Function(BooruType type)? postDataCodec;

  @override
  BookmarkBackupData parse(ExportDataPayload metadata) {
    final nested = metadata.version == kBookmarksBackupVersion;
    if (metadata.version != 4 && metadata.version != 5 && !nested) {
      throw InvalidBackupFormatException(
        'Unsupported bookmark backup version ${metadata.version}',
      );
    }
    final fields = metadata.extraFields;
    if ((nested &&
            (fields['organizationSchema'] != 'nestedGroups' ||
                fields.containsKey('folders'))) ||
        (!nested && fields.containsKey('organizationSchema')) ||
        fields.containsKey('collectionBookmarks')) {
      throw const InvalidBackupFormatException(
        'Unsupported or ambiguous Bookmark organization schema',
      );
    }
    final rawGroups = nested
        ? fields['groups']
        : fields['groups'] ?? <dynamic>[];
    if (rawGroups is! List<dynamic>) {
      throw const InvalidBackupFormatException('groups must be a list');
    }

    final fileBookmarkIds = <int>{};
    final bookmarkIdentities = <Object>{};
    final decodedRecords = <Bookmark>[];
    for (final (index, value) in metadata.data.indexed) {
      final idField = nested ? 'id' : 'localId';
      if (value is! Map<String, dynamic> || value[idField] is! int) {
        throw InvalidBackupFormatException('data[$index] is invalid');
      }
      final id = value[idField] as int;
      if (id < 0 || id > 9007199254740991 || !fileBookmarkIds.add(id)) {
        throw InvalidBackupFormatException(
          'data[$index].id is invalid or repeated',
        );
      }
      try {
        final record = nested
            ? records.decode(value)
            : _parseVersion4Bookmark(value, index);
        final identity = bookmarkContentIdentity(record);
        if (identity != null && !bookmarkIdentities.add(identity)) {
          throw InvalidBackupFormatException(
            'data[$index] repeats a bookmark identity',
          );
        }
        decodedRecords.add(record);
      } on InvalidBackupFormatException {
        rethrow;
      } catch (_) {
        throw InvalidBackupFormatException('data[$index] is invalid');
      }
    }

    final groups = <BookmarkGroupBackup>[];
    final suppliedIds = <String>{};
    for (final (index, value) in rawGroups.indexed) {
      if (value is! Map<String, dynamic>) {
        throw InvalidBackupFormatException('groups[$index] must be an object');
      }
      if (nested
          ? (value.containsKey('folderId') ||
                !value.containsKey('parentGroupId') ||
                value['position'] is! int ||
                value['addedAt'] is! Map)
          : value.containsKey('parentGroupId')) {
        throw InvalidBackupFormatException(
          'groups[$index] has invalid organization fields',
        );
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
      if (nested && bookmarkIds.toSet().length != bookmarkIds.length) {
        throw InvalidBackupFormatException(
          'groups[$index] repeats a membership',
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
      if (nested && id == null) {
        throw InvalidBackupFormatException(
          'groups[$index].id is required',
        );
      }
      if (id != null && !suppliedIds.add(id)) {
        throw InvalidBackupFormatException('groups[$index].id is repeated');
      }
      final folderId = metadata.version >= 5 ? value['folderId'] : null;
      final parentId = nested ? value['parentGroupId'] : null;
      final position = metadata.version >= 5
          ? value['position'] ?? index
          : index;
      if ((folderId != null &&
              (folderId is! String ||
                  !Uuid.isValidUUID(fromString: folderId))) ||
          (parentId != null &&
              (parentId is! String ||
                  !Uuid.isValidUUID(fromString: parentId))) ||
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
      if (id == defaultBookmarkGroupId &&
          (folderId != null || parentId != null)) {
        throw const InvalidBackupFormatException('Default must be at Home');
      }
      final dates = _groupDates(
        value['addedAt'],
        bookmarkIds.cast<int>().toSet(),
      );
      if (nested && dates.length != bookmarkIds.toSet().length) {
        throw InvalidBackupFormatException(
          'groups[$index] is missing membership dates',
        );
      }
      groups.add(
        BookmarkGroupBackup(
          id: id,
          name: name.trim(),
          bookmarkIds: bookmarkIds.cast<int>().toSet().toList(),
          addedAt: dates,
          folderId: (folderId as String?)?.toLowerCase(),
          parentGroupId: (parentId as String?)?.toLowerCase(),
          position: position,
        ),
      );
    }
    if (nested) {
      final assigned = {for (final group in groups) ...group.bookmarkIds};
      if (assigned.length != fileBookmarkIds.length) {
        throw const InvalidBackupFormatException(
          'Record has no dated membership',
        );
      }
    }
    try {
      final rawFolders = metadata.version >= 5
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
      if (!nested) {
        FolderTree(folders).validatePlacements([
          for (final (i, g) in groups.indexed)
            FolderPlacement(
              itemId: g.id ?? 'legacy-$i',
              folderId: g.folderId,
              position: g.position,
            ),
        ]);
      }
      return BookmarkBackupData.unified(
        records: decodedRecords,
        groups: groups,
        folders: folders,
      ).asHierarchy();
    } catch (_) {
      throw const InvalidBackupFormatException(
        'Invalid bookmark organization or collection references',
      );
    }
  }

  @override
  List<dynamic> encode(BookmarkBackupData data) =>
      _encode(data, transfer: true);

  /// Private on-device recovery retains local fields excluded from transfers.
  List<dynamic> encodeLocalRecovery(BookmarkBackupData data) =>
      _encode(data, transfer: false);

  List<dynamic> _encode(BookmarkBackupData data, {required bool transfer}) {
    final ids = <int>{};
    final identities = <Object>{};
    return [
      for (final record in data.records)
        (() {
          final identity = bookmarkContentIdentity(record);
          if (!ids.add(record.id) ||
              (identity != null && !identities.add(identity))) {
            throw const InvalidBackupFormatException(
              'Repeated Bookmark ID or content identity',
            );
          }
          return transfer
              ? records.encodeForTransfer(record)
              : records.encode(record);
        })(),
    ];
  }

  PostBookmark _parseSnapshotBookmark(
    Map<String, dynamic> value,
    int index,
  ) {
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
      StoredPostDecodeSuccess(:final post) => PostBookmark.fromSnapshot(
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

  PostBookmark _parseVersion4Bookmark(
    Map<String, dynamic> value,
    int index,
  ) {
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

Map<int, DateTime> _groupDates(Object? raw, Set<int> members) {
  if (raw == null) return const {};
  if (raw is! Map)
    throw const InvalidBackupFormatException('Invalid membership dates');
  final result = <int, DateTime>{};
  for (final entry in raw.entries) {
    final id = entry.key is String ? int.tryParse(entry.key as String) : null;
    final date = entry.value is String
        ? DateTime.tryParse(entry.value as String)
        : null;
    if (id == null ||
        !members.contains(id) ||
        result.containsKey(id) ||
        date == null) {
      throw const InvalidBackupFormatException('Invalid membership date');
    }
    result[id] = date.toUtc();
  }
  return result;
}
