// Project imports:
import '../../../core/posts/post/types.dart';
import 'post_data.dart';
import 'types.dart';

final class EshuushuuPostCodec
    implements BooruPostDataCodec<EshuushuuPostData> {
  const EshuushuuPostCodec();

  @override
  String get typeKey => 'eshuushuu';

  @override
  int get currentVersion => 1;

  @override
  bool supports(BooruPostData data) => data is EshuushuuPostData;

  @override
  Map<String, Object?> encode(EshuushuuPostData data) => {
    if (data.characters case final value?) 'characters': value.toList(),
    if (data.artists case final value?) 'artists': value.toList(),
    if (data.sourceTags case final value?) 'sourceTags': value.toList(),
    if (data.generalTags case final value?) 'generalTags': value.toList(),
    if (data.largeImageUrl case final value?) 'largeImageUrl': value,
    if (data.isFavorited case final value?) 'isFavorited': value,
    if (data.favorites case final value?) 'favorites': value,
    if (data.bayesianRating case final value?) 'bayesianRating': value,
  };

  @override
  EshuushuuPostData decode(
    Map<String, Object?> json, {
    required int version,
  }) {
    if (version != 1) {
      throw const FormatException('Unsupported Eshuushuu post data');
    }
    return EshuushuuPostData(
      characters: _optionalStringSet(json['characters']),
      artists: _optionalStringSet(json['artists']),
      sourceTags: _optionalStringSet(json['sourceTags']),
      generalTags: _optionalStringSet(json['generalTags']),
      largeImageUrl: json['largeImageUrl'] as String?,
      isFavorited: json['isFavorited'] as bool?,
      favorites: json['favorites'] as int?,
      bayesianRating: (json['bayesianRating'] as num?)?.toDouble(),
    );
  }
}

UnifiedPost eshuushuuPostToUnified(EshuushuuPost post, PostOrigin origin) =>
    UnifiedPost(
      origin: origin,
      core: PostCoreData.fromPost(post),
      booruData: EshuushuuPostData(
        characters: post.characters,
        artists: post.artist,
        sourceTags: post.sourceTags,
        generalTags: post.generalTags,
        largeImageUrl: post.largeImageUrl,
        isFavorited: post.isFavorited,
        favorites: post.favorites,
        bayesianRating: post.bayesianRating,
      ),
    );

Set<String>? _optionalStringSet(Object? value) => switch (value) {
  null => null,
  final List<Object?> values => values.map((e) => e as String).toSet(),
  _ => throw const FormatException('Invalid string set'),
};
