// Project imports:
import '../../../core/posts/post/types.dart';
import 'types.dart';

final class GelbooruV2PostCodec
    implements BooruPostDataCodec<GelbooruV2PostData> {
  const GelbooruV2PostCodec();

  @override
  String get typeKey => 'gelbooru_v2';

  @override
  int get currentVersion => 2;

  @override
  bool supports(BooruPostData data) => data is GelbooruV2PostData;

  @override
  Map<String, Object?> encode(GelbooruV2PostData data) => {
    'hasNotes': data.hasNotes,
    'isVideoPreview': data.isVideoPreview,
  };

  @override
  GelbooruV2PostData decode(
    Map<String, Object?> json, {
    required int version,
  }) => switch ((json, version)) {
    (
      {'hasNotes': final bool hasNotes, 'isVideoPreview': final bool marker},
      2,
    ) =>
      GelbooruV2PostData(hasNotes: hasNotes, isVideoPreview: marker),
    ({'hasNotes': final bool hasNotes}, 1) => GelbooruV2PostData(
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
  booruData: GelbooruV2PostData(
    hasNotes: post.hasNotes,
    isVideoPreview: post.isVideoPreview,
  ),
);
