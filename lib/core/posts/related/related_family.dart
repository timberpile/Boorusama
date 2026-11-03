import 'package:equatable/equatable.dart';

import '../../boorus/booru/types.dart';
import '../post/types.dart';
import '../details/src/types/viewer_entry.dart';

/// Shared by timeline occurrences and saved references. Account binding belongs
/// to the viewer source, and never changes the canonical direct-family anchor.
final class RelatedFamilyReference extends Equatable {
  RelatedFamilyReference({required this.origin, required this.anchorId}) {
    if (anchorId <= 0 ||
        origin.booruType != BooruType.danbooru ||
        origin.sourceHost.isEmpty) {
      throw const FormatException('Invalid Related family');
    }
  }

  factory RelatedFamilyReference.fromPost(Post post) => RelatedFamilyReference(
    origin: post.origin,
    anchorId: switch (post.parentId) {
      final int id when id > 0 => id,
      _ => post.id,
    },
  );

  final PostOrigin origin;
  final int anchorId;
  String get query => 'parent:$anchorId';
  ViewerContentIdentity get identity =>
      ViewerContentIdentity(origin, 'related', anchorId);
  bool contains(Post post) =>
      post.origin.booruType == origin.booruType &&
      post.origin.sourceHost == origin.sourceHost &&
      (post.id == anchorId || post.parentId == anchorId);

  @override
  List<Object?> get props => [identity];
}

final class RelatedViewerEntry extends ViewerEntry {
  const RelatedViewerEntry({
    required this.family,
    required this.occurrenceId,
    required this.source,
  });
  final RelatedFamilyReference family;
  @override
  final Object occurrenceId;
  @override
  final ViewerSourceBinding? source;
  @override
  ViewerContentIdentity get contentIdentity => family.identity;
  @override
  bool get usesContentNavigationHeader => true;
}
