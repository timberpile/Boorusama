// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../core/posts/post/types.dart';

final class EshuushuuPostData extends Equatable implements BooruPostData {
  const EshuushuuPostData({
    required this.characters,
    required this.artists,
    required this.sourceTags,
    required this.generalTags,
    required this.largeImageUrl,
    required this.isFavorited,
    required this.favorites,
    required this.bayesianRating,
  });

  final Set<String>? characters;
  final Set<String>? artists;
  final Set<String>? sourceTags;
  final Set<String>? generalTags;
  final String? largeImageUrl;
  final bool? isFavorited;
  final int? favorites;
  final double? bayesianRating;

  @override
  String get typeKey => 'eshuushuu';

  @override
  int get schemaVersion => 1;

  @override
  List<Object?> get props => [
    characters,
    artists,
    sourceTags,
    generalTags,
    largeImageUrl,
    isFavorited,
    favorites,
    bayesianRating,
  ];
}
