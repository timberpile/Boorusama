// Project imports:
import '../../../core/posts/post/types.dart';
import '../../../core/posts/sources/types.dart';
import 'types.dart';

final class E621PostCodec implements BooruPostDataCodec<E621PostData> {
  const E621PostCodec();

  @override
  String get typeKey => 'e621';

  @override
  int get currentVersion => 1;

  @override
  bool supports(BooruPostData data) => data is E621PostData;

  @override
  Map<String, Object?> encode(E621PostData data) => {
    'generalTags': data.generalTags.toList(),
    'metaTags': data.metaTags.toList(),
    'speciesTags': data.speciesTags.toList(),
    'invalidTags': data.invalidTags.toList(),
    'loreTags': data.loreTags.toList(),
    'upScore': data.upScore,
    'downScore': data.downScore,
    'favCount': data.favCount,
    'isFavorited': data.isFavorited,
    'sources': [
      for (final source in data.sources)
        {'kind': source.kind, 'value': source.value},
    ],
    'description': data.description,
    'videoVariants': [
      for (final variant in data.videoVariants)
        {
          'type': variant.type.value,
          'url': variant.url,
          'size': variant.size,
          'width': variant.width,
          'height': variant.height,
          'codec': variant.codec,
          'fps': variant.fps,
        },
    ],
  };

  @override
  E621PostData decode(
    Map<String, Object?> json, {
    required int version,
  }) {
    if (version != 1) {
      throw const FormatException('Unsupported e621 post data');
    }
    return E621PostData(
      generalTags: _stringSet(json['generalTags']),
      metaTags: _stringSet(json['metaTags']),
      speciesTags: _stringSet(json['speciesTags']),
      invalidTags: _stringSet(json['invalidTags']),
      loreTags: _stringSet(json['loreTags']),
      upScore: _required<int>(json['upScore'], 'upScore'),
      downScore: _required<int>(json['downScore'], 'downScore'),
      favCount: _required<int>(json['favCount'], 'favCount'),
      isFavorited: _required<bool>(json['isFavorited'], 'isFavorited'),
      sources: _list(json['sources']).map((value) {
        final map = _map(value);
        return E621PostSourceData(
          kind: _required<String>(map['kind'], 'source kind'),
          value: _required<String>(map['value'], 'source value'),
        );
      }).toList(),
      description: _required<String>(json['description'], 'description'),
      videoVariants: _list(json['videoVariants']).map((value) {
        final map = _map(value);
        final type = E621VideoVariantType.tryParse(map['type'] as String?);
        if (type == null) {
          throw const FormatException('Invalid e621 video variant type');
        }
        return E621VideoVariantData(
          type: type,
          url: _required<String>(map['url'], 'video variant url'),
          size: _required<int>(map['size'], 'video variant size'),
          width: _required<int>(map['width'], 'video variant width'),
          height: _required<int>(map['height'], 'video variant height'),
          codec: _required<String>(map['codec'], 'video variant codec'),
          fps: _required<num>(map['fps'], 'video variant fps').toDouble(),
        );
      }).toList(),
    );
  }
}

Post e621PostFromRecord(E621PostRecord post, PostOrigin origin) => Post(
  origin: origin,
  core: PostCoreData.fromPost(post, status: post.status?.value),
  booruData: E621PostData(
    generalTags: post.generalTags,
    metaTags: post.metaTags,
    speciesTags: post.speciesTags,
    invalidTags: post.invalidTags,
    loreTags: post.loreTags,
    upScore: post.upScore,
    downScore: post.downScore,
    favCount: post.favCount,
    isFavorited: post.isFavorited,
    sources: post.sources.map(_sourceData).toList(),
    description: post.description,
    videoVariants: post.videoVariants.values
        .map(E621VideoVariantData.fromVariant)
        .toList(),
  ),
);

E621PostSourceData _sourceData(PostSource source) => switch (source) {
  NoSource() => const E621PostSourceData(kind: 'none', value: ''),
  NonWebSource(:final value) => E621PostSourceData(
    kind: 'nonWeb',
    value: value,
  ),
  PixivSource(:final url) => E621PostSourceData(kind: 'pixiv', value: url),
  RawWebSource(:final url) => E621PostSourceData(kind: 'web', value: url),
};

Set<String> _stringSet(Object? value) =>
    _list(value).map((e) => _required<String>(e, 'string set item')).toSet();

List<Object?> _list(Object? value) => switch (value) {
  final List<Object?> values => values,
  _ => throw const FormatException('Invalid list'),
};

Map<String, Object?> _map(Object? value) => switch (value) {
  final Map<Object?, Object?> map when map.keys.every((key) => key is String) =>
    Map<String, Object?>.from(map),
  _ => throw const FormatException('Invalid map'),
};

T _required<T>(Object? value, String field) => switch (value) {
  final T value => value,
  _ => throw FormatException('Invalid e621 $field'),
};
