// Project imports:
import '../../../core/posts/post/types.dart';
import 'post_data.dart';
import 'types.dart';

final class AnimePicturesPostCodec
    implements BooruPostDataCodec<AnimePicturesPostData> {
  const AnimePicturesPostCodec();

  @override
  String get typeKey => 'anime_pictures';

  @override
  int get currentVersion => 1;

  @override
  bool supports(BooruPostData data) => data is AnimePicturesPostData;

  @override
  Map<String, Object?> encode(AnimePicturesPostData data) => {
    'tagsCount': data.tagsCount,
    'statusValue': ?data.statusValue,
    'statusType': ?data.statusType,
  };

  @override
  AnimePicturesPostData decode(
    Map<String, Object?> json, {
    required int version,
  }) {
    if (version != 1) {
      throw const FormatException('Unsupported AnimePictures post data');
    }
    return AnimePicturesPostData(
      tagsCount: _required<int>(json['tagsCount'], 'tagsCount'),
      statusValue: json['statusValue'] as int?,
      statusType: json['statusType'] as int?,
    );
  }
}

Post animePicturesPostFromRecord(
  AnimePicturesPostRecord post,
  PostOrigin origin,
) {
  final (statusValue, statusType) = switch (post.status) {
    AnimePicturesPostStatus(:final value, :final type) => (value, type),
    _ => (null, null),
  };
  return Post(
    origin: origin,
    core: PostCoreData.fromPost(post),
    booruData: AnimePicturesPostData(
      tagsCount: post.tagsCount,
      statusValue: statusValue,
      statusType: statusType,
    ),
  );
}

T _required<T>(Object? value, String field) => switch (value) {
  final T value => value,
  _ => throw FormatException('Invalid AnimePictures $field'),
};
