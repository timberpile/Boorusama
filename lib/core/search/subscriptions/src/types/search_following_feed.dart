import 'package:equatable/equatable.dart';

import '../../../../boorus/booru/types.dart';
import '../../../../posts/post/types.dart';
import '../../../../posts/rating/types.dart';
import '../../../../posts/sources/types.dart';

const followingFeedRetention = 500;
const followingFeedSourceLimit = 1000;

class SearchFollowingFeed extends Equatable {
  SearchFollowingFeed({
    required this.id,
    required this.profileId,
    required this.name,
    this.position = 0,
    List<String> sourceIds = const [],
    List<CachedFeedPost> posts = const [],
  }) : sourceIds = List.unmodifiable(sourceIds),
       posts = List.unmodifiable(posts.take(followingFeedRetention));
  factory SearchFollowingFeed.fromJson(Map json) {
    final profileId = switch (json['profileId']) {
      final int value => value,
      _ => throw const FormatException('Invalid feed profile'),
    };
    return SearchFollowingFeed(
      id: switch (json['id']) {
        final String value when value.isNotEmpty => value,
        _ => throw const FormatException('Invalid feed id'),
      },
      profileId: profileId,
      name: switch (json['name']) {
        final String value when value.trim().isNotEmpty => value.trim(),
        _ => throw const FormatException('Invalid feed name'),
      },
      position: switch (json['position']) {
        final int value => value,
        _ => 0,
      },
      sourceIds: switch (json['sourceIds']) {
        final List values => values.whereType<String>().toList(),
        _ => const [],
      },
      posts: switch (json['posts']) {
        final List values => [
          for (final Map value in values.whereType<Map>())
            CachedFeedPost.fromJson(value, profileId: profileId),
        ],
        _ => const [],
      },
    );
  }
  final String id;
  final int profileId;
  final String name;
  final int position;
  final List<String> sourceIds;
  final List<CachedFeedPost> posts;
  SearchFollowingFeed copyWith({
    String? name,
    int? position,
    List<String>? sourceIds,
    List<CachedFeedPost>? posts,
  }) => SearchFollowingFeed(
    id: id,
    profileId: profileId,
    name: name ?? this.name,
    position: position ?? this.position,
    sourceIds: sourceIds ?? this.sourceIds,
    posts: posts ?? this.posts,
  );
  Map<String, Object?> toJson({bool includeCache = true}) => {
    'id': id,
    'profileId': profileId,
    'name': name,
    'position': position,
    'sourceIds': sourceIds,
    if (includeCache) 'posts': posts.map((p) => p.toJson()).toList(),
  };
  SearchFollowingFeed merge(List<CachedFeedPost> incoming) {
    final byId = {for (final post in posts) post.id: post};
    for (final post in incoming.take(50)) {
      byId[post.id] = post;
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final date = (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
        return date == 0 ? b.id.compareTo(a.id) : date;
      });
    return copyWith(posts: merged.take(followingFeedRetention).toList());
  }

  @override
  List<Object?> get props => [id, profileId, name, position, sourceIds, posts];
}

class CachedFeedPost extends Equatable {
  const CachedFeedPost._({required this.snapshot, required this.post});

  factory CachedFeedPost.fromPost(
    Post source, {
    PostOrigin? origin,
    PostToUnifiedConverter? converter,
    BooruPostDataCodec? dataCodec,
  }) {
    final post = switch (source) {
      final UnifiedPost post => post,
      _ when origin != null && converter != null => converter(source, origin),
      _ => UnifiedPost(
        origin:
            origin ??
            PostOrigin.fromSource(
              booruType: BooruType.unknown,
              booruId: 0,
              source: '',
            ),
        core: PostCoreData.fromPost(source),
        booruData: const LegacyPostData(
          typeKey: 'legacy_feed',
          custom: {},
        ),
      ),
    };
    final snapshot = const StoredPostCodec().encode(
      post,
      dataCodec: dataCodec,
    );
    return CachedFeedPost._(snapshot: snapshot, post: post);
  }

  factory CachedFeedPost.fromSnapshot(
    StoredPostSnapshot snapshot, {
    BooruPostDataCodec? dataCodec,
  }) {
    final result = const StoredPostCodec().decode(
      snapshot,
      dataCodec: dataCodec,
    );
    return switch (result) {
      StoredPostDecodeSuccess(:final post) => CachedFeedPost._(
        snapshot: snapshot,
        post: post,
      ),
      StoredPostDecodeFailure(:final reason, :final error) =>
        throw FormatException(
          'Invalid cached post snapshot: $reason',
          error,
        ),
    };
  }

  factory CachedFeedPost.fromJson(
    Map json, {
    int? profileId,
    BooruPostDataCodec? dataCodec,
  }) {
    if (json case {
      'snapshotSchemaVersion': 1,
      'postSnapshot': final Map rawSnapshot,
    }) {
      return CachedFeedPost.fromSnapshot(
        StoredPostSnapshot.fromJson(Map<String, dynamic>.from(rawSnapshot)),
        dataCodec: dataCodec,
      );
    }

    final createdAt = switch (json['createdAt']) {
      final String value => DateTime.parse(value).toUtc(),
      _ => throw const FormatException('Invalid cached post timestamp'),
    };
    final mediaVariants = switch (json['mediaVariants']) {
      final Map values => {
        for (final entry in values.entries)
          if (entry case MapEntry(
            key: final String key,
            value: final String value,
          ))
            key: value,
      },
      _ => const <String, String>{},
    };
    final post = UnifiedPost(
      origin: PostOrigin.fromSource(
        booruType: BooruType.unknown,
        booruId: profileId ?? 0,
        source: '',
        profileIdHint: profileId,
      ),
      core: PostCoreData(
        id: switch (json['id']) {
          final int value => value,
          _ => throw const FormatException('Invalid cached post id'),
        },
        createdAt: createdAt,
        thumbnailImageUrl: switch (json['thumbnail']) {
          final String value => value,
          _ => '',
        },
        sampleImageUrl: switch (json['sample']) {
          final String value => value,
          _ => '',
        },
        originalImageUrl: switch (json['original']) {
          final String value => value,
          _ => '',
        },
        videoUrl: '',
        videoThumbnailUrl: '',
        mediaVariants: mediaVariants,
        width: switch (json['width']) {
          final num value => value.toDouble(),
          _ => 0,
        },
        height: switch (json['height']) {
          final num value => value.toDouble(),
          _ => 0,
        },
        format: switch (json['format']) {
          final String value => value,
          _ => '',
        },
        md5: '',
        fileSize: 0,
        duration: 0,
        tags: switch (json['tags']) {
          final List values => values.whereType<String>().toSet(),
          _ => const {},
        },
        rating:
            Rating.values.where((r) => r.name == json['rating']).firstOrNull ??
            Rating.general,
        hasComment: false,
        isTranslated: false,
        hasParentOrChildren: false,
        source: PostSource.none(),
        score: 0,
      ),
      booruData: const LegacyPostData(typeKey: 'legacy_feed', custom: {}),
    );
    return CachedFeedPost.fromPost(post);
  }

  final StoredPostSnapshot snapshot;
  final UnifiedPost post;

  int get id => post.id;
  DateTime? get createdAt => post.createdAt;
  String get thumbnailImageUrl => post.thumbnailImageUrl;
  String get sampleImageUrl => post.sampleImageUrl;
  String get originalImageUrl => post.originalImageUrl;
  Map<String, String> get mediaVariants => post.mediaVariants;

  CachedFeedPost decodeWith(BooruPostDataCodec? dataCodec) =>
      CachedFeedPost.fromSnapshot(snapshot, dataCodec: dataCodec);

  Map<String, Object?> toJson() => {
    'snapshotSchemaVersion': 1,
    'postSnapshot': snapshot.toJson(),
  };

  @override
  List<Object?> get props => [snapshot];
}
