// Project imports:
import '../../../core/posts/post/types.dart';
import 'post_data.dart';
import 'types.dart';

final class MoebooruPostCodec implements BooruPostDataCodec<MoebooruPostData> {
  const MoebooruPostCodec();

  @override
  String get typeKey => 'moebooru';

  @override
  int get currentVersion => 1;

  @override
  bool supports(BooruPostData data) => data is MoebooruPostData;

  @override
  Map<String, Object?> encode(MoebooruPostData data) => {
    'largeImageUrl': data.largeImageUrl,
  };

  @override
  MoebooruPostData decode(
    Map<String, Object?> json, {
    required int version,
  }) => switch (json) {
    {'largeImageUrl': final String largeImageUrl} when version == 1 =>
      MoebooruPostData(largeImageUrl: largeImageUrl),
    _ => throw const FormatException('Invalid Moebooru post data'),
  };
}

UnifiedPost moebooruPostToUnified(MoebooruPost post, PostOrigin origin) =>
    UnifiedPost(
      origin: origin,
      core: PostCoreData.fromPost(post),
      booruData: MoebooruPostData(largeImageUrl: post.largeImageUrl),
    );
