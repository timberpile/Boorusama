import 'package:equatable/equatable.dart';

import '../../../../bookmarks/src/types/pool_bookmark_capability.dart';
import '../../../../configs/config/types.dart';
import '../../../post/types.dart';

/// Content identity never includes credentials or a navigation position.
final class ViewerContentIdentity extends Equatable {
  const ViewerContentIdentity(this.origin, this.kind, this.upstreamId);

  final PostOrigin origin;
  final String kind;
  final int upstreamId;

  @override
  List<Object?> get props => [
    origin.booruType,
    origin.sourceHost,
    kind,
    upstreamId,
  ];
}

/// Transient authorization binding. It must never be serialized for restoration.
final class ViewerSourceBinding {
  const ViewerSourceBinding(this.config);

  final BooruConfig config;

  BooruConfig? resolve(Iterable<BooruConfig> profiles) => profiles
      .where(
        (candidate) =>
            candidate.id == config.id &&
            candidate.auth == config.auth &&
            candidate.filter == config.filter &&
            BooruConfigSearchFilter.fromConfig(candidate) ==
                BooruConfigSearchFilter.fromConfig(config),
      )
      .firstOrNull;
}

/// An engine may add another immutable entry without changing the Post model.
abstract class ViewerEntry {
  const ViewerEntry();

  ViewerContentIdentity get contentIdentity;
  ViewerSourceBinding? get source;
  Object get occurrenceId;
  bool get usesContentNavigationHeader => false;
}

final class PostViewerEntry extends ViewerEntry {
  const PostViewerEntry({
    required this.post,
    required this.occurrenceId,
    this.source,
  });

  final Post post;
  @override
  final Object occurrenceId;
  @override
  final ViewerSourceBinding? source;
  @override
  ViewerContentIdentity get contentIdentity =>
      ViewerContentIdentity(post.origin, 'post', post.id);
}

final class PoolViewerEntry extends ViewerEntry {
  const PoolViewerEntry({
    required this.origin,
    required this.pool,
    required this.occurrenceId,
    required this.source,
  });

  final PostOrigin origin;
  @override
  bool get usesContentNavigationHeader => true;
  final RemoteBookmarkPool pool;
  @override
  final Object occurrenceId;
  @override
  final ViewerSourceBinding? source;
  @override
  ViewerContentIdentity get contentIdentity =>
      ViewerContentIdentity(origin, 'pool', pool.id);
}

/// A route owns a snapshot of established occurrences. Append-only updates
/// cannot substitute the current page when source membership changes.
final class ViewerEntrySequence {
  ViewerEntrySequence(Iterable<ViewerEntry> initial) {
    append(initial);
  }

  final entries = <ViewerEntry>[];
  final posts = <Post>[];
  final _postIndices = <int?>[];
  final _occurrences = <Object>{};

  int? postIndex(int page) =>
      page >= 0 && page < _postIndices.length ? _postIndices[page] : null;

  Post? postAt(int page) => switch (postIndex(page)) {
    final index? => posts[index],
    _ => null,
  };

  void append(Iterable<ViewerEntry> incoming) {
    for (final entry in incoming) {
      if (!_occurrences.add(entry.occurrenceId)) continue;
      _postIndices.add(entry is PostViewerEntry ? posts.length : null);
      entries.add(entry);
      if (entry is PostViewerEntry) posts.add(entry.post);
    }
  }
}
