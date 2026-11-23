import '../../search/following_topics/src/types/following_mirror_state.dart';
import '../sources/following_topic_backup_data.dart';
import '../sources/search_backup_profile.dart';
import 'bookmark_scope.dart';
import 'protocol.dart';

/// Catalog labels are bounded summaries; the complete query/name remains in
/// the authenticated definition package. Never split a UTF-16 surrogate pair.
String syncFollowingLabel(String value) {
  final buffer = StringBuffer();
  var length = 0;
  for (final rune in value.runes) {
    final size = rune > 0xffff ? 2 : 1;
    if (length + size > 160) break;
    buffer.writeCharCode(rune);
    length += size;
  }
  return buffer.toString();
}

final class SyncFollowingDefinitions {
  SyncFollowingDefinitions({
    required this.snapshot,
    required String publisher,
    required Set<String> roots,
    required List<BackupProfileReference> profiles,
  }) {
    final local = {
      for (final topic in snapshot.topics)
        if (!snapshot.mirrors.isReceived(topic.id)) topic.id,
      for (final folder in snapshot.organization.folders)
        if (!snapshot.mirrors.isReceived(folder.id)) folder.id,
    };
    nodes = {
      for (final folder in snapshot.organization.folders)
        if (local.contains(folder.id))
          folder.id: SyncBookmarkNode(
            source: folder.id,
            parent: folder.parentId,
            position: folder.position,
          ),
      for (final p in snapshot.organization.placements)
        if (local.contains(p.itemId))
          p.itemId: SyncBookmarkNode(
            source: p.itemId,
            parent: p.folderId,
            position: p.position,
          ),
    };
    scope = BookmarkSyncScope(
      publisher: publisher,
      nodes: nodes.values,
      directRoots: roots.intersection(local),
    );
    final references = {for (final profile in profiles) profile.id: profile};
    definitions = {
      for (final folder in snapshot.organization.folders)
        if (scope.covered.contains(folder.id))
          folder.id: FollowingTopicBackupData(
            records: const [],
            folders: [
              FollowingTopicFolderBackupRecord(
                id: folder.id,
                name: folder.name,
                position: 0,
                searchIds: const [],
                feedEnabled: folder.feedEnabled,
                feedMaxPosts: folder.feedMaxPosts,
              ),
            ],
          ),
      for (final topic in snapshot.topics)
        if (scope.covered.contains(topic.id))
          topic.id: FollowingTopicBackupData(
            homeSearchIds: [topic.id],
            records: [
              FollowingTopicBackupRecord(
                id: topic.id,
                name: topic.name,
                query: topic.query,
                queryStructure: topic.queryStructure,
                position: 0,
                profile:
                    followingTopicBackupProfile(topic, references.values) ??
                    (throw const SyncConflict()),
              ),
            ],
          ),
    };
    labels = {
      for (final folder in snapshot.organization.folders)
        if (scope.covered.contains(folder.id))
          folder.id: syncFollowingLabel(folder.name),
      for (final topic in snapshot.topics)
        if (scope.covered.contains(topic.id))
          topic.id: syncFollowingLabel(topic.displayName),
    };
  }
  final FollowingMirrorSnapshot snapshot;
  late final Map<String, SyncBookmarkNode> nodes;
  late final BookmarkSyncScope scope;
  late final Map<String, FollowingTopicBackupData> definitions;
  late final Map<String, String> labels;
}
