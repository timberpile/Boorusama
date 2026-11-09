import 'package:equatable/equatable.dart';

import '../../../posts/listing/src/types/grid_thumbnail_static_media.dart';
import '../../../posts/post/types.dart';
import '../../../content/types.dart';

/// Only the selected static cover's media variants, never collection members.
final class PoolBookmarkCover extends Equatable
    implements GridThumbnailStaticMedia {
  PoolBookmarkCover({
    required this.thumbnail,
    required this.sample,
    required this.original,
    required Map<String, String> variants,
    this.visibility,
  }) : variants = Map.unmodifiable(variants);
  @override
  final String thumbnail;
  @override
  final String sample;
  @override
  final String original;
  @override
  final Map<String, String> variants;
  final GroupCoverVisibility? visibility;

  static bool isStatic(String url) => RegExp(
    r'\.(jpe?g|png|webp|avif)$',
    caseSensitive: false,
  ).hasMatch(Uri.tryParse(url)?.path ?? '');

  factory PoolBookmarkCover.fromPost(Post post) => PoolBookmarkCover(
    visibility: GroupCoverVisibility(
      tags: post.tags,
      rating: post.rating.name,
      deleted: post.status?.matches('deleted') ?? false,
      banned: post.status?.matches('banned') ?? false,
    ),
    thumbnail: post.thumbnailImageUrl,
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

  Map<String, Object?> toJson() => {
    'thumbnail': thumbnail,
    'sample': sample,
    'original': original,
    'variants': variants,
    'visibility': ?visibility?.toJson(),
  };
  factory PoolBookmarkCover.fromJson(Map<String, dynamic> json) =>
      PoolBookmarkCover(
        thumbnail: json['thumbnail'] as String,
        sample: json['sample'] as String,
        original: json['original'] as String,
        variants: Map<String, String>.from(json['variants'] as Map),
        visibility: json['visibility'] == null
            ? null
            : GroupCoverVisibility.fromJson(
                Map<String, dynamic>.from(json['visibility'] as Map),
              ),
      );
  @override
  List<Object?> get props => [
    thumbnail,
    sample,
    original,
    variants,
    visibility,
  ];
}
