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
    if (data.statusValue case final value?) 'statusValue': value,
    if (data.statusType case final value?) 'statusType': value,
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
      tagsCount: json['tagsCount'] as int,
      statusValue: json['statusValue'] as int?,
      statusType: json['statusType'] as int?,
    );
  }
}

UnifiedPost animePicturesPostToUnified(
  AnimePicturesPost post,
  PostOrigin origin,
) {
  final (statusValue, statusType) = switch (post.status) {
    AnimePicturesPostStatus(:final value, :final type) => (value, type),
    _ => (null, null),
  };
  return UnifiedPost(
    origin: origin,
    core: PostCoreData.fromPost(post),
    booruData: AnimePicturesPostData(
      tagsCount: post.tagsCount,
      statusValue: statusValue,
      statusType: statusType,
    ),
  );
}
