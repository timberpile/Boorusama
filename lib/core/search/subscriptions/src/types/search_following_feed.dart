import 'package:equatable/equatable.dart';
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
  factory SearchFollowingFeed.fromJson(Map json) => SearchFollowingFeed(
    id: switch (json['id']) {
      final String value when value.isNotEmpty => value,
      _ => throw const FormatException('Invalid feed id'),
    },
    profileId: switch (json['profileId']) {
      final int value => value,
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
    sourceIds: switch (json['sourceIds']) {
      final List values => values.whereType<String>().toList(),
      _ => const [],
    },
    posts: switch (json['posts']) {
      final List values => [
        for (final Map value in values.whereType<Map>())
          CachedFeedPost.fromJson(value),
      ],
      _ => const [],
    },
  );
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

class CachedFeedPost extends SimplePost implements PostMediaVariants {
  CachedFeedPost({
    required super.id,
    required DateTime createdAt,
    required String thumbnail,
    required String sample,
    required String original,
    required Set<String> tags,
    required super.rating,
    required super.width,
    required super.height,
    required super.format,
    required Map<String, String> mediaVariants,
  }) : mediaVariants = Map.unmodifiable(mediaVariants),
       super(
         createdAt: createdAt,
         thumbnailImageUrl: thumbnail,
         sampleImageUrl: sample,
         originalImageUrl: original,
         tags: Set.unmodifiable(tags),
         hasComment: false,
         isTranslated: false,
         hasParentOrChildren: false,
         source: PostSource.none(),
         score: 0,
         duration: 0,
         fileSize: 0,
         hasSound: null,
         md5: '',
         videoThumbnailUrl: '',
         videoUrl: '',
         uploaderId: null,
         metadata: null,
       );
  factory CachedFeedPost.fromPost(Post post) => CachedFeedPost(
    id: post.id,
    createdAt: post.createdAt!,
    thumbnail: post.thumbnailImageUrl,
    sample: post.sampleImageUrl,
    original: post.originalImageUrl,
    tags: post.tags,
    rating: post.rating,
    width: post.width,
    height: post.height,
    format: post.format,
    mediaVariants: switch (post) {
      PostMediaVariants(:final mediaVariants) => mediaVariants,
      _ => const {},
    },
  );
  factory CachedFeedPost.fromJson(Map json) => CachedFeedPost(
    id: switch (json['id']) {
      final int value => value,
      _ => throw const FormatException('Invalid cached post id'),
    },
    createdAt: switch (json['createdAt']) {
      final String value => DateTime.parse(value).toUtc(),
      _ => throw const FormatException('Invalid cached post timestamp'),
    },
    thumbnail: switch (json['thumbnail']) {
      final String value => value,
      _ => '',
    },
    sample: switch (json['sample']) {
      final String value => value,
      _ => '',
    },
    original: switch (json['original']) {
      final String value => value,
      _ => '',
    },
    tags: switch (json['tags']) {
      final List values => values.whereType<String>().toSet(),
      _ => const {},
    },
    rating:
        Rating.values.where((r) => r.name == json['rating']).firstOrNull ??
        Rating.general,
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
    mediaVariants: switch (json['mediaVariants']) {
      final Map values => {
        for (final entry in values.entries)
          if (entry case MapEntry(
            key: final String key,
            value: final String value,
          ))
            key: value,
      },
      _ => const {},
    },
  );
  @override
  final Map<String, String> mediaVariants;

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt!.toIso8601String(),
    'thumbnail': thumbnailImageUrl,
    'sample': sampleImageUrl,
    'original': originalImageUrl,
    'tags': tags.toList(),
    'rating': rating.name,
    'width': width,
    'height': height,
    'format': format,
    if (mediaVariants.isNotEmpty) 'mediaVariants': mediaVariants,
  };
  @override
  List<Object?> get props => [
    id,
    createdAt,
    thumbnailImageUrl,
    sampleImageUrl,
    originalImageUrl,
    tags,
    rating,
    width,
    height,
    format,
    mediaVariants,
  ];
}
