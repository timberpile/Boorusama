import 'package:equatable/equatable.dart';

import '../../../../boorus/booru/types.dart';
import '../../../../configs/config/types.dart';
import '../../../../posts/post/types.dart';
import '../../../../posts/rating/types.dart';
import '../../../../posts/sources/types.dart';

const topicFeedRetention = 1000;
const topicFeedSourceLimit = 1000;

class TopicFeedMetadata extends Equatable {
  const TopicFeedMetadata({
    required this.id,
    required this.profileId,
    required this.name,
    required this.position,
    required this.maxPosts,
    required this.sourceIds,
  });

  factory TopicFeedMetadata.fromJson(Map json) => TopicFeedMetadata(
    id: switch (json['id']) {
      final String value when value.isNotEmpty => value,
      _ => throw const FormatException('Invalid feed id'),
    },
    profileId: switch (json['profileId']) {
      final String value when isCanonicalProfileId(value) => value,
      _ => throw const FormatException('Invalid feed profile'),
    },
    name: switch (json['name']) {
      final String value when value.trim().isNotEmpty => value.trim(),
      _ => throw const FormatException('Invalid feed name'),
    },
    position: switch (json['position']) {
      final int value => value,
      _ => 0,
    },
    maxPosts: switch (json['maxPosts']) {
      final int value when value > 0 => value,
      _ => topicFeedRetention,
    },
    sourceIds: List.unmodifiable(
      switch (json['sourceIds']) {
        final List values => values.whereType<String>().toList(),
        _ => const <String>[],
      },
    ),
  );

  final String id;
  final String profileId;
  final String name;
  final int position;
  final int maxPosts;
  final List<String> sourceIds;

  @override
  List<Object?> get props => [
    id,
    profileId,
    name,
    position,
    maxPosts,
    sourceIds,
  ];
}

class TopicFeed extends Equatable {
  TopicFeed({
    required this.id,
    required this.profileId,
    required this.name,
    this.position = 0,
    this.maxPosts = topicFeedRetention,
    List<String> sourceIds = const [],
    List<StoredPostSnapshot> posts = const [],
    List<String> initializedSourceIds = const [],
    Map<String, List<String>> postSources = const {},
  }) : assert(maxPosts > 0, 'maxPosts must be positive'),
       sourceIds = List.unmodifiable(sourceIds),
       posts = List.unmodifiable(posts.take(maxPosts)),
       initializedSourceIds = List.unmodifiable(initializedSourceIds),
       postSources = Map.unmodifiable({
         for (final entry in postSources.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       });
  factory TopicFeed.fromJson(Map json) {
    final profileId = switch (json['profileId']) {
      final String value when isCanonicalProfileId(value) => value,
      _ => throw const FormatException('Invalid feed profile'),
    };
    return TopicFeed(
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
      maxPosts: switch (json['maxPosts']) {
        final int value when value > 0 => value,
        _ => topicFeedRetention,
      },
      sourceIds: switch (json['sourceIds']) {
        final List values => values.whereType<String>().toList(),
        _ => const [],
      },
      initializedSourceIds: switch (json['initializedSourceIds']) {
        final List values => values.whereType<String>().toList(),
        _ =>
          json['posts'] is List && (json['posts'] as List).isNotEmpty
              ? (json['sourceIds'] as List?)?.whereType<String>().toList() ??
                    const <String>[]
              : const <String>[],
      },
      postSources: switch (json['postSources']) {
        final Map values => {
          for (final entry in values.entries)
            if (entry.key is String && entry.value is List)
              entry.key as String: (entry.value as List)
                  .whereType<String>()
                  .toList(),
        },
        _ => const <String, List<String>>{},
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
  final String profileId;
  final String name;
  final int position;
  final int maxPosts;
  final List<String> sourceIds;
  final List<StoredPostSnapshot> posts;

  /// Sources whose initial post snapshot has already been collected.
  final List<String> initializedSourceIds;

  /// Provenance of individual cached results; older cache rows may lack it.
  final Map<String, List<String>> postSources;

  TopicFeed copyWith({
    String? profileId,
    String? name,
    int? position,
    int? maxPosts,
    List<String>? sourceIds,
    List<StoredPostSnapshot>? posts,
    List<String>? initializedSourceIds,
    Map<String, List<String>>? postSources,
  }) => TopicFeed(
    id: id,
    profileId: profileId ?? this.profileId,
    name: name ?? this.name,
    position: position ?? this.position,
    maxPosts: maxPosts ?? this.maxPosts,
    sourceIds: sourceIds ?? this.sourceIds,
    posts: posts ?? this.posts,
    initializedSourceIds: initializedSourceIds ?? this.initializedSourceIds,
    postSources: postSources ?? this.postSources,
  );
  Map<String, Object?> toJson({bool includeCache = true}) => {
    'id': id,
    'profileId': profileId,
    'name': name,
    'position': position,
    'maxPosts': maxPosts,
    'sourceIds': sourceIds,
    if (includeCache) 'posts': posts.map(feedPostSnapshotToJson).toList(),
    if (includeCache) 'initializedSourceIds': initializedSourceIds,
    if (includeCache) 'postSources': postSources,
  };
  TopicFeed merge(
    List<StoredPostSnapshot> incoming, {
    String? sourceId,
  }) {
    final byId = {for (final post in posts) feedPostIdentity(post): post};
    final sources = <String, Set<String>>{
      for (final entry in postSources.entries) entry.key: entry.value.toSet(),
    };
    for (final post in incoming) {
      final key = feedPostIdentity(post);
      byId[key] = post;
      if (sourceId != null) {
        sources.putIfAbsent(key, () => <String>{}).add(sourceId);
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final date = (feedPostCreatedAt(b) ?? _epoch).compareTo(
          feedPostCreatedAt(a) ?? _epoch,
        );
        if (date != 0) return date;
        final id = feedPostId(b).compareTo(feedPostId(a));
        return id != 0
            ? id
            : feedPostIdentity(b).compareTo(feedPostIdentity(a));
      });
    final retained = merged.take(maxPosts).toList();
    final keys = retained.map(feedPostIdentity).toSet();
    return copyWith(
      posts: retained,
      initializedSourceIds:
          sourceId == null || initializedSourceIds.contains(sourceId)
          ? initializedSourceIds
          : [...initializedSourceIds, sourceId],
      postSources: {
        for (final entry in sources.entries)
          if (keys.contains(entry.key)) entry.key: entry.value.toList(),
      },
    );
  }

  /// Adjust membership without discarding valid cached posts. Historical rows
  /// without provenance are retained until replaced or naturally evicted.
  TopicFeed reconcileSources(List<String> nextSourceIds) {
    final active = nextSourceIds.toSet();
    final retained = [
      for (final post in posts)
        if (active.isNotEmpty &&
            (postSources[feedPostIdentity(post)] == null ||
                postSources[feedPostIdentity(post)]!.any(active.contains)))
          post,
    ];
    return copyWith(
      sourceIds: nextSourceIds,
      posts: retained,
      initializedSourceIds: initializedSourceIds
          .where(active.contains)
          .toList(),
      postSources: {
        for (final post in retained)
          if (postSources[feedPostIdentity(post)] case final matches?)
            feedPostIdentity(post): matches.where(active.contains).toList(),
      },
    );
  }

  @override
  List<Object?> get props => [
    id,
    profileId,
    name,
    position,
    maxPosts,
    sourceIds,
    posts,
    initializedSourceIds,
    postSources,
  ];
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
  String? profileId,
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
        booruId: 0,
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

/// Post IDs are scoped to a site, not globally unique across booru profiles.
String feedPostIdentity(StoredPostSnapshot snapshot) {
  final origin = snapshot.origin;
  final site = origin.sourceHost.isEmpty
      ? 'profile:${origin.profileIdHint ?? origin.booruId}'
      : '${origin.booruTypeId}:${origin.sourceHost}';
  return '$site:${feedPostId(snapshot)}';
}

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
