import 'package:equatable/equatable.dart';

import '../../../posts/post/types.dart';
import '../../../posts/rating/types.dart';
import '../../../posts/sources/types.dart';

/// Only the selected static cover's media variants, never collection members.
final class PoolBookmarkCover extends Equatable {
  PoolBookmarkCover({
    required this.thumbnail,
    required this.sample,
    required this.original,
    required Map<String, String> variants,
  }) : variants = Map.unmodifiable(variants);
  final String thumbnail;
  final String sample;
  final String original;
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

  Post asPost(PostOrigin origin) => Post(
    origin: origin,
    core: PostCoreData(
      id: 0,
      thumbnailImageUrl: thumbnail,
      sampleImageUrl: sample,
      originalImageUrl: original,
      videoUrl: '',
      videoThumbnailUrl: '',
      width: 0,
      height: 0,
      format: 'jpg',
      md5: '',
      fileSize: 0,
      duration: 0,
      tags: const {},
      rating: Rating.unknown,
      hasComment: false,
      isTranslated: false,
      hasParentOrChildren: false,
      source: PostSource.none(),
      score: 0,
      mediaVariants: variants,
    ),
    booruData: const LegacyPostData(typeKey: 'pool-cover', custom: {}),
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
