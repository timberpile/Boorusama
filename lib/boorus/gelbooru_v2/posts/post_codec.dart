// Project imports:
import '../../../core/posts/post/types.dart';
import 'post_data.dart';
import 'types.dart';

final class GelbooruV2PostCodec
    implements BooruPostDataCodec<GelbooruV2PostData> {
  const GelbooruV2PostCodec();

  @override
  String get typeKey => 'gelbooru_v2';

  @override
  int get currentVersion => 1;

  @override
  bool supports(BooruPostData data) => data is GelbooruV2PostData;

  @override
  Map<String, Object?> encode(GelbooruV2PostData data) => {
    'hasNotes': data.hasNotes,
  };

  @override
  GelbooruV2PostData decode(
    Map<String, Object?> json, {
    required int version,
  }) => switch (json) {
    {'hasNotes': final bool hasNotes} when version == 1 => GelbooruV2PostData(
      hasNotes: hasNotes,
    ),
    _ => throw const FormatException('Invalid Gelbooru V2 post data'),
  };
}

Post gelbooruV2PostFromRecord(
  GelbooruV2PostRecord post,
  PostOrigin origin,
) => Post(
  origin: origin,
  core: PostCoreData.fromPost(post),
  booruData: GelbooruV2PostData(hasNotes: post.hasNotes),
);
