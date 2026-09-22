// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../core/posts/post/types.dart';
import 'types.dart';

final class E621PostData extends Equatable implements BooruPostData {
  const E621PostData({
    required this.generalTags,
    required this.metaTags,
    required this.speciesTags,
    required this.invalidTags,
    required this.loreTags,
    required this.upScore,
    required this.downScore,
    required this.favCount,
    required this.isFavorited,
    required this.sources,
    required this.description,
    required this.videoVariants,
  });

  final Set<String> generalTags;
  final Set<String> metaTags;
  final Set<String> speciesTags;
  final Set<String> invalidTags;
  final Set<String> loreTags;
  final int upScore;
  final int downScore;
  final int favCount;
  final bool isFavorited;
  final List<E621PostSourceData> sources;
  final String description;
  final List<E621VideoVariantData> videoVariants;

  @override
  String get typeKey => 'e621';

  @override
  int get schemaVersion => 1;

  @override
  List<Object?> get props => [
    generalTags,
    metaTags,
    speciesTags,
    invalidTags,
    loreTags,
    upScore,
    downScore,
    favCount,
    isFavorited,
    sources,
    description,
    videoVariants,
  ];
}

final class E621PostSourceData extends Equatable {
  const E621PostSourceData({required this.kind, required this.value});

  final String kind;
  final String value;

  @override
  List<Object?> get props => [kind, value];
}

final class E621VideoVariantData extends Equatable {
  const E621VideoVariantData({
    required this.type,
    required this.url,
    required this.size,
    required this.width,
    required this.height,
    required this.codec,
    required this.fps,
  });

  factory E621VideoVariantData.fromVariant(E621VideoVariant variant) =>
      E621VideoVariantData(
        type: variant.type,
        url: variant.url,
        size: variant.size,
        width: variant.width,
        height: variant.height,
        codec: variant.codec,
        fps: variant.fps,
      );

  final E621VideoVariantType type;
  final String url;
  final int size;
  final int width;
  final int height;
  final String codec;
  final double fps;

  E621VideoVariant toVariant() => E621VideoVariant(
    type: type,
    url: url,
    size: size,
    width: width,
    height: height,
    codec: codec,
    fps: fps,
  );

  @override
  List<Object?> get props => [type, url, size, width, height, codec, fps];
}
