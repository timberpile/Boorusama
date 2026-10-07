// Project imports:
import '../../../core/posts/post/types.dart';
import 'types.dart';

final class PhilomenaPostCodec
    implements BooruPostDataCodec<PhilomenaPostData> {
  const PhilomenaPostCodec();

  @override
  String get typeKey => 'philomena';

  @override
  int get currentVersion => 1;

  @override
  bool supports(BooruPostData data) => data is PhilomenaPostData;

  @override
  Map<String, Object?> encode(PhilomenaPostData data) => {
    'description': data.description,
    'commentCount': data.commentCount,
    'favCount': data.favCount,
    'upvotes': data.upvotes,
    'representation': {
      'full': data.representation.full,
      'large': data.representation.large,
      'medium': data.representation.medium,
      'small': data.representation.small,
      'tall': data.representation.tall,
      'thumb': data.representation.thumb,
      'thumbSmall': data.representation.thumbSmall,
      'thumbTiny': data.representation.thumbTiny,
    },
  };

  @override
  PhilomenaPostData decode(
    Map<String, Object?> json, {
    required int version,
  }) {
    if (version != 1) {
      throw const FormatException('Unsupported Philomena post data');
    }
    final representation = _map(json['representation']);
    return PhilomenaPostData(
      description: _required<String>(json['description'], 'description'),
      commentCount: _required<int>(json['commentCount'], 'commentCount'),
      favCount: _required<int>(json['favCount'], 'favCount'),
      upvotes: _required<int>(json['upvotes'], 'upvotes'),
      representation: PhilomenaRepresentation(
        full: _required<String>(representation['full'], 'full representation'),
        large: _required<String>(
          representation['large'],
          'large representation',
        ),
        medium: _required<String>(
          representation['medium'],
          'medium representation',
        ),
        small: _required<String>(
          representation['small'],
          'small representation',
        ),
        tall: _required<String>(representation['tall'], 'tall representation'),
        thumb: _required<String>(
          representation['thumb'],
          'thumb representation',
        ),
        thumbSmall: _required<String>(
          representation['thumbSmall'],
          'small thumbnail representation',
        ),
        thumbTiny: _required<String>(
          representation['thumbTiny'],
          'tiny thumbnail representation',
        ),
      ),
    );
  }
}

Post philomenaPostFromRecord(PhilomenaPostRecord post, PostOrigin origin) =>
    Post(
      origin: origin,
      core: PostCoreData.fromPost(post),
      booruData: PhilomenaPostData(
        description: post.description,
        commentCount: post.commentCount,
        favCount: post.favCount,
        upvotes: post.upvotes,
        representation: post.representation,
      ),
    );

T _required<T>(Object? value, String field) => switch (value) {
  final T value => value,
  _ => throw FormatException('Invalid Philomena $field'),
};

Map<String, Object?> _map(Object? value) => switch (value) {
  final Map<Object?, Object?> map when map.keys.every((key) => key is String) =>
    Map<String, Object?>.from(map),
  _ => throw const FormatException('Invalid Philomena representation'),
};
