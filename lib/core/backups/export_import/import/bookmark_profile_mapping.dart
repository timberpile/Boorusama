import 'package:collection/collection.dart';

import '../../../bookmarks/src/data/stored_bookmark_codec.dart';
import '../../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../../bookmarks/types.dart';
import '../../sources/bookmark_unified_import.dart';
import '../../sources/bookmark_backup_data.dart';
import '../../sources/bookmark_import_record_matches.dart';
import 'bookmark_profile_dependency.dart';
import 'profile_dependency_planner.dart';

/// Preview and apply must make the same optional profile-hint decision.
Map<int, Bookmark> mapBookmarkImportProfiles({
  required Iterable<Bookmark> incoming,
  required Iterable<Bookmark> local,
  required Map<ProfileReferenceKey, String> mappings,
  Set<ProfileReferenceKey> explicitMappings = const {},
  bool replace = false,
  Iterable<BookmarkGroupBackup>? incomingGroups,
  Iterable<BookmarkGroup>? localGroups,
  StoredBookmarkCodec codec = const StoredBookmarkCodec(),
}) {
  final existing = {
    for (final record in local)
      if (bookmarkContentIdentity(record) case final identity?)
        identity: record,
  };
  final groups = incomingGroups?.toList();
  final opaqueMatches =
      replace &&
          groups != null &&
          localGroups != null &&
          groups.every((group) => group.id != null)
      ? matchUnaddressableBookmarkRecords(
          incoming: incoming,
          local: local,
          incomingGroups: [
            for (final group in groups)
              BookmarkGroup(
                id: group.id!,
                name: group.name,
                bookmarkIds: group.bookmarkIds.toSet(),
                addedAt: group.addedAt,
              ),
          ],
          localGroups: localGroups,
          codec: codec,
        )
      : const <int, Bookmark>{};
  Map<String, Object?> transferable(Bookmark record) {
    final wire = codec.encodeForTransfer(record)..remove('id');
    if (wire['kind'] == 'post') {
      ((wire['snapshot'] as Map)['origin'] as Map).remove('profileIdHint');
    } else if (wire['legacy'] case final Map legacy) {
      ((legacy['metadata'] as Map)['origin'] as Map).remove('profileIdHint');
    } else {
      wire.remove('sourceProfileHint');
    }
    return wire;
  }

  final mapped = <int, Bookmark>{};
  for (final record in incoming) {
    final key = ProfileReferenceKey.fromReference(
      bookmarkRecordProfileReference(record),
    );
    final hint = mappings[key];
    final previous =
        existing[bookmarkContentIdentity(record)] ?? opaqueMatches[record.id];
    if (previous != null) validateBookmarkImportCompatibility(previous, record);
    if (previous != null &&
        const DeepCollectionEquality().equals(
          transferable(previous),
          transferable(record),
        )) {
      // Missing optional hints do not request enrichment by an automatic
      // reader. Keep local-only fields even when a real hint is remapped.
      final retained = bookmarkWithId(previous, record.id);
      final desiredHint =
          bookmarkRecordProfileHint(record) != null ||
              explicitMappings.contains(key)
          ? hint ?? bookmarkRecordProfileHint(record)
          : null;
      mapped[record.id] = desiredHint == null
          ? retained
          : bookmarkRecordWithProfileHint(retained, desiredHint);
    } else if (hint != null) {
      mapped[record.id] = bookmarkRecordWithProfileHint(record, hint);
    }
  }
  return mapped;
}
