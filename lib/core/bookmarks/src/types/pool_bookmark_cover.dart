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
  }) : variants = Map.unmodifiable(variants);
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
  };
  factory PoolBookmarkCover.fromJson(Map<String, dynamic> json) =>
      PoolBookmarkCover(
        thumbnail: json['thumbnail'] as String,
        sample: json['sample'] as String,
        original: json['original'] as String,
        variants: Map<String, String>.from(json['variants'] as Map),
      );
  @override
  List<Object?> get props => [thumbnail, sample, original, variants];
}
