import 'package:uuid/uuid.dart';

import '../../../bookmarks/types.dart';
import '../../../bookmarks/src/types/legacy_group_bookmark.dart';
import '../../../posts/post/types.dart';
import '../../../boorus/booru/types.dart';
import '../../sources/bookmark_backup_data.dart';
import '../../sources/search_backup_profile.dart';
import '../models/import_action.dart';
import 'import_plan.dart';

BackupProfileReference bookmarkProfileReference(PostBookmark bookmark) =>
    bookmarkOriginProfileReference(bookmark.post.origin);

BackupProfileReference poolBookmarkProfileReference(CollectionBookmark pool) =>
    bookmarkOriginProfileReference(pool.origin);

BackupProfileReference bookmarkOriginProfileReference(PostOrigin origin) {
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

List<PostBookmark> selectedProfileBookmarks(
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

PostBookmark bookmarkWithProfileHint(PostBookmark bookmark, String profileId) {
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
    post: bookmark.post.copyWith(
      origin: PostOrigin.fromSource(
        booruType: bookmark.post.origin.booruType,
        booruId: bookmark.post.origin.booruId,
        source: bookmark.post.origin.sourceHost,
        profileIdHint: profileId,
      ),
    ),
  );
}

List<CollectionBookmark> selectedProfilePools(
  BookmarkBackupData data,
  ResolvedImportSource resolution,
) {
  if (resolution.action == ImportAction.skip) return const [];
  if (resolution.action == ImportAction.replace) return data.pools;
  final groups = {
    for (final item in resolution.items)
      if (item.action != ImportAction.skip && item.id.startsWith('group:'))
        item.id.substring(6),
  };
  return data.pools.where((p) => p.groupIds.any(groups.contains)).toList();
}

CollectionBookmark poolBookmarkWithProfileHint(
  CollectionBookmark pool,
  String profileId,
) => pool.copyWith(
  origin: PostOrigin.fromSource(
    booruType: pool.origin.booruType,
    booruId: pool.origin.booruId,
    source: pool.origin.sourceHost,
    profileIdHint: profileId,
  ),
);

/// Source hints participate in the existing import dependency gate only. They
/// never authorize a request or supply missing historical locator evidence.
BackupProfileReference bookmarkRecordProfileReference(Bookmark record) {
  final (engine, site, hint) = switch (record) {
    PostBookmark() => (
      BooruType.fromLegacyId(record.snapshot.origin.booruTypeId),
      record.snapshot.origin.sourceHost,
      record.snapshot.origin.profileIdHint,
    ),
    ContentGroupBookmark() => (
      record.reference.engine,
      record.reference.siteNamespace,
      record.sourceProfileHint,
    ),
    LegacyGroupBookmark() => (
      record.metadata.origin.booruType,
      record.metadata.origin.sourceHost,
      record.sourceProfileHint,
    ),
    _ => throw const FormatException('Unsupported Bookmark record'),
  };
  return BackupProfileReference(
    id: hint ?? const Uuid().v5(Namespace.url.value, '${engine.name}:$site'),
    booruType: engine.name,
    url: site,
    name: site,
  );
}

String? bookmarkRecordProfileHint(Bookmark record) => switch (record) {
  PostBookmark() => record.snapshot.origin.profileIdHint,
  ContentGroupBookmark() => record.sourceProfileHint,
  LegacyGroupBookmark() => record.sourceProfileHint,
  _ => null,
};

Bookmark bookmarkRecordWithProfileHint(Bookmark record, String profileId) =>
    switch (record) {
      PostBookmark() => bookmarkWithProfileHint(record, profileId),
      ContentGroupBookmark() => record.copyWith(
        sourceProfileHint: () => profileId,
      ),
      LegacyGroupBookmark() => record.copyWith(
        metadata: poolBookmarkWithProfileHint(record.metadata, profileId),
      ),
      _ => throw const FormatException('Unsupported Bookmark record'),
    };

List<Bookmark> selectedProfileRecords(
  BookmarkBackupData data,
  ResolvedImportSource resolution,
) {
  if (resolution.action == ImportAction.skip) return const [];
  if (resolution.action == ImportAction.replace) return data.records;
  final selected = {
    for (final item in resolution.items)
      if (item.action != ImportAction.skip) item.id,
  };
  final grouped = {for (final group in data.groups) ...group.bookmarkIds};
  final ids = {
    for (final group in data.groups)
      if (selected.contains('group:${group.id}')) ...group.bookmarkIds,
    if (selected.contains('ungrouped'))
      for (final r in data.records)
        if (!grouped.contains(r.id)) r.id,
  };
  return data.records.where((r) => ids.contains(r.id)).toList();
}
