import '../../../content/types.dart';
import '../../../posts/filter/types.dart';

import 'package:equatable/equatable.dart';

import '../../../posts/listing/src/types/grid_thumbnail_static_media.dart';
import '../../../posts/post/types.dart';

/// Only the selected static cover's media variants, never collection members.
final class PoolBookmarkCover extends Equatable
    implements GridThumbnailStaticMedia {
  PoolBookmarkCover({
    required this.thumbnail,
    required this.sample,
    required this.original,
    required Map<String, String> variants,
    this.visibility,
    this.postId,
    this.memberOrderDigest,
  }) : variants = Map.unmodifiable(variants);
  final GroupCoverVisibility? visibility;
  final int? postId;
  final String? memberOrderDigest;
  @override
  final String thumbnail;
  @override
  final String sample;
  @override
  final String original;
  @override
  final Map<String, String> variants;

  static bool isStatic(String url) => RegExp(
    r'\.(jpe?g|png|webp|avif)$',
    caseSensitive: false,
  ).hasMatch(Uri.tryParse(url)?.path ?? '');

  factory PoolBookmarkCover.fromPost(Post post) => PoolBookmarkCover(
    thumbnail: post.thumbnailImageUrl,
    postId: post.id,
    visibility: GroupCoverVisibility(
      tags: post.tags,
      postFacts: {
        'score': post.score,
        'downvotes': post.downvotes,
        'uploaderId': post.uploaderId,
        'uploaderName': post.uploaderName,
        'source': post.extractTagFilterData().source,
      },
      rating: post.rating.name,
      deleted: post.status?.matches('deleted') ?? false,
      banned: post.status?.matches('banned') ?? false,
    ),
    sample: isStatic(post.sampleImageUrl)
        ? post.sampleImageUrl
        : post.thumbnailImageUrl,
    original: isStatic(post.originalImageUrl)
        ? post.originalImageUrl
        : post.thumbnailImageUrl,
    variants: {
      for (final entry in post.mediaVariants.entries)
        if (isStatic(entry.value)) entry.key: entry.value,
    },
  );

  PoolBookmarkCover withMemberOrder(String? digest) => PoolBookmarkCover(
    thumbnail: thumbnail,
    sample: sample,
    original: original,
    variants: variants,
    visibility: visibility,
    postId: postId,
    memberOrderDigest: digest,
  );

  Map<String, Object?> toJson() => {
    'thumbnail': thumbnail,
    'sample': sample,
    'original': original,
    'variants': variants,
    'visibility': ?visibility?.toJson(),
    'postId': ?postId,
    'memberOrderDigest': ?memberOrderDigest,
  };
  factory PoolBookmarkCover.fromJson(Map<String, dynamic> json) =>
      PoolBookmarkCover(
        thumbnail: json['thumbnail'] as String,
        visibility: json['visibility'] == null
            ? null
            : GroupCoverVisibility.fromJson(
                Map<String, dynamic>.from(json['visibility'] as Map),
              ),
        postId: json['postId'] as int?,
        memberOrderDigest: json['memberOrderDigest'] as String?,
        sample: json['sample'] as String,
        original: json['original'] as String,
        variants: Map<String, String>.from(json['variants'] as Map),
      );
  @override
  List<Object?> get props => [
    thumbnail,
    sample,
    original,
    variants,
    visibility,
    postId,
    memberOrderDigest,
  ];
}
