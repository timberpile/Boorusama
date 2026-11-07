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
    if (metadata.version != 4 &&
        metadata.version != 5 &&
        metadata.version != 6 &&
        metadata.version != 7 &&
        metadata.version != 8 &&
        metadata.version != 9 &&
        metadata.version != 10) {
      throw InvalidBackupFormatException(
        'Unsupported bookmark backup version ${metadata.version}',
      );
    }
    final bookmarks = <PostBookmark>[];
    final unifiedRecords = <Bookmark>[];
    if (metadata.version == 10 &&
        metadata.extraFields.containsKey('collectionBookmarks')) {
      throw const InvalidBackupFormatException(
        'v10 requires one Bookmark array',
      );
    }
    final fileBookmarkIds = <int>{};
    final bookmarkIdentities = <Object>{};
    // Group dates must be validated before v9 Post rows can be reconstructed.
    for (final (index, value) in metadata.data.indexed) {
      final idField = metadata.version == 10 ? 'id' : 'localId';
      if (value is! Map || value[idField] is! int) {
        throw InvalidBackupFormatException('data[$index] is invalid');
      }
      final id = value[idField] as int;
      if (id < 0 || id > 9007199254740991 || !fileBookmarkIds.add(id)) {
        throw InvalidBackupFormatException(
          'data[$index].id is invalid or repeated',
        );
      }
      if (metadata.version == 10) {
        try {
          final record = records.decode(value);
          final identity = bookmarkContentIdentity(record);
          if (identity != null && !bookmarkIdentities.add(identity)) {
            throw const FormatException('Repeated Bookmark content identity');
          }
          unifiedRecords.add(record);
        } catch (_) {
          throw InvalidBackupFormatException('data[$index] is invalid');
        }
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
      if (metadata.version == 10 && id == null) {
        throw InvalidBackupFormatException(
          'groups[$index].id is required in v10',
        );
      }
      if (id != null && !suppliedIds.add(id)) {
        throw InvalidBackupFormatException('groups[$index].id is repeated');
      }
      final folderId = metadata.version >= 5 ? value['folderId'] : null;
      final position = metadata.version >= 5
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
      final dates = _groupDates(
        value['addedAt'],
        bookmarkIds.cast<int>().toSet(),
      );
      if (metadata.version >= 9 && dates.length != bookmarkIds.toSet().length) {
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
          position: position,
        ),
      );
    }
    final firstMembership = <int, DateTime>{};
    if (metadata.version >= 9) {
      for (final group in groups) {
        for (final entry in group.addedAt.entries) {
          final previous = firstMembership[entry.key];
          if (previous == null || entry.value.isBefore(previous)) {
            firstMembership[entry.key] = entry.value;
          }
        }
      }
    }
    for (final (index, raw)
        in (metadata.version == 10 ? <dynamic>[] : metadata.data).indexed) {
      final value = raw as Map<String, dynamic>;
      try {
        final membershipDate = firstMembership[value['localId']];
        if (metadata.version >= 9 && membershipDate == null) {
          throw InvalidBackupFormatException(
            'data[$index] has no dated membership',
          );
        }
        final bookmark = _parseVersion4Bookmark(
          value,
          index,
          membershipDate: membershipDate,
        );
        if (!bookmarkIdentities.add(bookmark.identity)) {
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
      final tree = FolderTree(folders);
      tree.validatePlacements([
        for (final (i, g) in groups.indexed)
          FolderPlacement(
            itemId: g.id ?? 'legacy-$i',
            folderId: g.folderId,
            position: g.position,
          ),
      ]);
      final rawPools = metadata.extraFields['collectionBookmarks'];
      if (rawPools != null && (metadata.version < 6 || rawPools is! List)) {
        throw const FormatException('Unsupported collection bookmark data');
      }
      final pools = <CollectionBookmark>[];
      final poolLocalIds = <String>{};
      final poolIdentities = <Object>{};
      for (final row in rawPools as List? ?? []) {
        if (metadata.version < 7 && (row as Map)['kind'] != 'pool') {
          throw const FormatException('Related references require version 7');
        }
        final pool = CollectionBookmark.fromJson(
          {
            ...Map<String, dynamic>.from(row as Map),
            if (metadata.version >= 9)
              'createdAt': _collectionMembershipDate(row).toIso8601String(),
          },
        );
        if (!Uuid.isValidUUID(fromString: pool.localId) ||
            !poolLocalIds.add(pool.localId) ||
            !poolIdentities.add(pool.identity) ||
            pool.groupIds.isEmpty ||
            !suppliedIds.containsAll(pool.groupIds)) {
          throw const FormatException('Invalid collection bookmark references');
        }
        pools.add(pool);
      }
      if (metadata.version == 10) {
        if (unifiedRecords.any((r) => !firstMembership.containsKey(r.id))) {
          throw const FormatException('Record has no dated membership');
        }
        return BookmarkBackupData.unified(
          records: unifiedRecords,
          groups: groups,
          folders: folders,
        );
      }
      return BookmarkBackupData(
        pools: pools,
        bookmarks: bookmarks,
        groups: groups,
        folders: folders,
      );
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
    int index, {
    DateTime? membershipDate,
  }) {
    final localId = value['localId'];
    final createdAt = value['createdAt'];
    final updatedAt = value['updatedAt'];
    final rawSnapshot = value['snapshot'];
    final postId = value['postId'];
    if (localId is! int ||
        (membershipDate == null && createdAt is! String) ||
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
        // Compatibility projection for local models; v9 stores only group dates.
        createdAt: membershipDate ?? DateTime.parse(createdAt as String),
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
    int index, {
    DateTime? membershipDate,
  }) {
    final rawIdentity = value['identity'];
    if (rawIdentity is! Map<String, dynamic> || value['postId'] is! int) {
      throw InvalidBackupFormatException('data[$index].identity is invalid');
    }
    final bookmark = _parseSnapshotBookmark(
      value,
      index,
      membershipDate: membershipDate,
    );
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

DateTime _collectionMembershipDate(Map row) {
  final rawGroups = row['groupIds'];
  final rawDates = row['addedAt'];
  if (rawGroups is! List || rawDates is! Map || rawGroups.isEmpty) {
    throw const FormatException('Missing collection membership dates');
  }
  final groups = rawGroups.cast<String>().map((id) => id.toLowerCase()).toSet();
  if (rawDates.length != groups.length) {
    throw const FormatException('Incomplete collection membership dates');
  }
  final seen = <String>{};
  DateTime? first;
  for (final entry in rawDates.entries) {
    final id = entry.key is String ? (entry.key as String).toLowerCase() : null;
    final date = entry.value is String
        ? DateTime.tryParse(entry.value as String)?.toUtc()
        : null;
    if (id == null || !groups.contains(id) || !seen.add(id) || date == null) {
      throw const FormatException('Invalid collection membership date');
    }
    if (first == null || date.isBefore(first)) first = date;
  }
  return first!;
}
