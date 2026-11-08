import 'package:equatable/equatable.dart';

import '../../../../configs/config/types.dart';
import '../../../../content/types.dart';
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
  const ViewerSourceBinding(this.config, {this.bookmarkId})
    : publicOrigin = null;

  /// Pins the public actor. Adding a saved profile cannot upgrade an already
  /// open public viewer to that account; policy changes still get fresh keys.
  ViewerSourceBinding.publicRead(PostOrigin origin, {this.bookmarkId})
    : config = BooruConfig.empty,
      publicOrigin = origin;

  final BooruConfig config;
  final PostOrigin? publicOrigin;

  /// Local saved-record identity; never an upstream Post or member identity.
  final int? bookmarkId;

  BooruConfig? resolve(Iterable<BooruConfig> profiles) {
    if (publicOrigin != null) return null;
    return profiles
        .where(
          (candidate) =>
              candidate.id == config.id &&
              candidate.localMediaGeneration == config.localMediaGeneration &&
              candidate.auth == config.auth &&
              candidate.filter == config.filter &&
              BooruConfigSearchFilter.fromConfig(candidate) ==
                  BooruConfigSearchFilter.fromConfig(config),
        )
        .firstOrNull;
  }
}

/// An engine may add another immutable entry without changing the Post model.
abstract class ViewerEntry {
  const ViewerEntry();

  ContentReference? get contentReference => null;
  ContentIdentity? get contentIdentity => contentReference?.identity;
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
  ContentReference? get contentReference =>
      source == null || source!.config == BooruConfig.empty
      ? null
      : const ContentReferenceCodec().fromPost(
          post,
          site: Uri.tryParse(source!.config.url),
        );
}

final class GroupViewerEntry extends ViewerEntry {
  const GroupViewerEntry({
    required this.summary,
    required this.occurrenceId,
    required this.source,
    this.initialMemberKey,
  });

  final ContentGroupSummary summary;
  final String? initialMemberKey;
  @override
  final Object occurrenceId;
  @override
  final ViewerSourceBinding? source;
  @override
  ContentReference get contentReference => summary.reference;
  @override
  bool get usesContentNavigationHeader => true;
}

/// A retained old-wire Group may have no proven installation locator. Keep its
/// outer occurrence navigable without manufacturing an address or source actor.
final class UnavailableGroupViewerEntry extends ViewerEntry {
  const UnavailableGroupViewerEntry({
    required this.occurrenceId,
    this.related = false,
  });
  final bool related;
  @override
  final Object occurrenceId;
  @override
  ViewerSourceBinding? get source => null;
  @override
  bool get usesContentNavigationHeader => true;
}

/// A source-bound configuration proves its complete Group URL; a normalized host alone does not prove HTTP
/// scheme, port or installation path for a new Group reference.
ContentReference? referenceForBoundGroup({
  required PostOrigin origin,
  required String sourceKey,
  required ViewerSourceBinding? source,
}) {
  final config = source?.config;
  if (config == null ||
      config == BooruConfig.empty ||
      config.auth.booruType != origin.booruType ||
      normalizePostSourceHost(config.url) != origin.sourceHost)
    return null;
  try {
    return const ContentReferenceCodec().parse(
      engine: origin.booruType,
      site: Uri.parse(config.url),
      kind: ContentKind.group,
      sourceKey: sourceKey,
    );
  } on FormatException {
    return null;
  }
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
