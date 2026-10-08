// Project imports:
import '../../../../../core/posts/post/types.dart';
import 'danbooru_post.dart';
import 'danbooru_post_data.dart';

final class DanbooruPostCodec implements BooruPostDataCodec<DanbooruPostData> {
  const DanbooruPostCodec();

  @override
  String get typeKey => 'danbooru';

  @override
  int get currentVersion => 1;

  @override
  bool supports(BooruPostData data) => data is DanbooruPostData;

  @override
  Map<String, Object?> encode(DanbooruPostData data) => {
    if (data.lastCommentAt case final value?)
      'lastCommentAt': value.toUtc().toIso8601String(),
    'upScore': data.upScore,
    'downScore': data.downScore,
    'favCount': data.favCount,
    'approverId': ?data.approverId,
    'generalTags': data.generalTags.toList(),
    'metaTags': data.metaTags.toList(),
    'hasChildren': data.hasChildren,
    'hasLarge': data.hasLarge,
    'pixelHash': data.pixelHash,
  };

  @override
  DanbooruPostData decode(
    Map<String, Object?> json, {
    required int version,
  }) {
    if (version != 1) {
      throw const FormatException('Unsupported Danbooru post data');
    }
    return DanbooruPostData(
      lastCommentAt: switch (json['lastCommentAt']) {
        final String value => DateTime.parse(value),
        null => null,
        _ => throw const FormatException('Invalid last comment timestamp'),
      },
      upScore: _required<int>(json['upScore'], 'upScore'),
      downScore: _required<int>(json['downScore'], 'downScore'),
      favCount: _required<int>(json['favCount'], 'favCount'),
      approverId: json['approverId'] as int?,
      generalTags: _stringSet(json['generalTags']),
      metaTags: _stringSet(json['metaTags']),
      hasChildren: _required<bool>(json['hasChildren'], 'hasChildren'),
      hasLarge: _required<bool>(json['hasLarge'], 'hasLarge'),
      pixelHash: _required<String>(json['pixelHash'], 'pixelHash'),
    );
  }
}

Post danbooruPostFromRecord(DanbooruPostRecord post, PostOrigin origin) => Post(
  origin: origin,
  core: PostCoreData.fromPost(post, status: post.status?.value),
  booruData: DanbooruPostData.fromPost(post),
);

Set<String> _stringSet(Object? value) => switch (value) {
  final List<Object?> values when values.every((item) => item is String) =>
    values.cast<String>().toSet(),
  _ => throw const FormatException('Invalid string set'),
};

T _required<T>(Object? value, String field) => switch (value) {
  final T value => value,
  _ => throw FormatException('Invalid Danbooru $field'),
};
