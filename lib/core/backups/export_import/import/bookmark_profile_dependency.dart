import 'package:uuid/uuid.dart';

import '../../../bookmarks/types.dart';
import '../../../posts/post/types.dart';
import '../../sources/bookmark_backup_data.dart';
import '../../sources/search_backup_profile.dart';
import '../models/import_action.dart';
import 'import_plan.dart';

BackupProfileReference bookmarkProfileReference(Bookmark bookmark) {
  final origin = bookmark.post.origin;
  final site = normalizePostSourceHost(origin.sourceHost);
  return BackupProfileReference(
    id:
        origin.profileIdHint ??
        const Uuid().v5(Namespace.url.value, '${origin.booruType.name}:$site'),
    booruType: origin.booruType.name,
    // The stored identity is already canonical. Adding a scheme can turn a
    // preserved nondefault port into that scheme's default and lose identity.
    url: site,
    name: site,
  );
}

List<Bookmark> selectedProfileBookmarks(
  BookmarkBackupData data,
  ResolvedImportSource resolution,
) {
  if (resolution.action == ImportAction.skip) return const [];
  if (resolution.action == ImportAction.replace) return data.bookmarks;
  final selectedItems = {
    for (final item in resolution.items)
      if (item.action != ImportAction.skip) item.id,
  };
  final grouped = {for (final group in data.groups) ...group.bookmarkIds};
  final selectedIds = {
    for (final group in data.groups)
      if (selectedItems.contains('group:${group.id}')) ...group.bookmarkIds,
    if (selectedItems.contains('ungrouped'))
      for (final bookmark in data.bookmarks)
        if (!grouped.contains(bookmark.id)) bookmark.id,
  };
  return data.bookmarks.where((b) => selectedIds.contains(b.id)).toList();
}

Bookmark bookmarkWithProfileHint(Bookmark bookmark, String profileId) {
  final snapshot = bookmark.snapshot;
  final origin = snapshot.origin;
  final mappedOrigin = PostOriginSnapshot(
    booruTypeId: origin.booruTypeId,
    booruId: origin.booruId,
    sourceHost: origin.sourceHost,
    profileIdHint: profileId,
  );
  return bookmark.copyWith(
    snapshot: StoredPostSnapshot(
      origin: mappedOrigin,
      common: snapshot.common,
      custom: snapshot.custom,
      codecVersion: snapshot.codecVersion,
    ),
    post: bookmark.post.copyWith(origin: PostOrigin.fromSnapshot(mappedOrigin)),
  );
}
