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
    List<StoredPostSnapshot> posts = const [],
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
            feedPostSnapshotFromJson(value, profileId: profileId),
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
  final List<StoredPostSnapshot> posts;
  SearchFollowingFeed copyWith({
    String? name,
    int? position,
    List<String>? sourceIds,
    List<StoredPostSnapshot>? posts,
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
    if (includeCache) 'posts': posts.map(feedPostSnapshotToJson).toList(),
  };
  SearchFollowingFeed merge(List<StoredPostSnapshot> incoming) {
    final byId = {for (final post in posts) feedPostId(post): post};
    for (final post in incoming.take(50)) {
      byId[feedPostId(post)] = post;
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final date = (feedPostCreatedAt(b) ?? _epoch).compareTo(
          feedPostCreatedAt(a) ?? _epoch,
        );
        return date == 0 ? feedPostId(b).compareTo(feedPostId(a)) : date;
      });
    return copyWith(posts: merged.take(followingFeedRetention).toList());
  }

  @override
  List<Object?> get props => [id, profileId, name, position, sourceIds, posts];
}

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

StoredPostSnapshot feedPostSnapshotFromPost(
  Post post, {
  PostOrigin? origin,
  BooruPostDataCodec? dataCodec,
}) => const StoredPostCodec().encode(
  origin == null ? post : post.copyWith(origin: origin),
  dataCodec: dataCodec,
);

StoredPostSnapshot feedPostSnapshotFromJson(
  Map json, {
  int? profileId,
}) {
  if (json case {
    'snapshotSchemaVersion': 1,
    'postSnapshot': final Map rawSnapshot,
  }) {
    final snapshot = StoredPostSnapshot.fromJson(
      Map<String, dynamic>.from(rawSnapshot),
    );
    decodeFeedPost(snapshot);
    return snapshot;
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
  return feedPostSnapshotFromPost(
    Post(
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
    ),
  );
}

Post decodeFeedPost(
  StoredPostSnapshot snapshot, {
  BooruPostDataCodec? dataCodec,
}) => switch (const StoredPostCodec().decode(snapshot, dataCodec: dataCodec)) {
  StoredPostDecodeSuccess(:final post)
      when dataCodec == null &&
          post.origin.booruType == BooruType.unknown &&
          post.origin.sourceHost.isEmpty =>
    post.copyWith(
      booruData: LegacyPostData(
        typeKey: 'legacy_feed',
        schemaVersion: snapshot.codecVersion,
        custom: snapshot.custom,
      ),
    ),
  StoredPostDecodeSuccess(:final post) => post,
  StoredPostDecodeFailure(:final reason, :final error) => throw FormatException(
    'Invalid cached post snapshot: $reason',
    error,
  ),
};

int feedPostId(StoredPostSnapshot snapshot) => switch (snapshot.common['id']) {
  final int id => id,
  _ => throw const FormatException('Invalid cached post id'),
};

DateTime? feedPostCreatedAt(StoredPostSnapshot snapshot) =>
    switch (snapshot.common['createdAt']) {
      final String value => DateTime.parse(value),
      null => null,
      _ => throw const FormatException('Invalid cached post timestamp'),
    };

Map<String, Object?> feedPostSnapshotToJson(StoredPostSnapshot snapshot) => {
  'snapshotSchemaVersion': 1,
  'postSnapshot': snapshot.toJson(),
};
